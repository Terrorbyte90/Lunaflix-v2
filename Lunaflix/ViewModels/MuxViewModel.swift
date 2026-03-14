import SwiftUI
import PhotosUI
import AVFoundation
import Combine

// MARK: - Mux ViewModel

@MainActor
final class MuxViewModel: ObservableObject {

    // MARK: Library
    @Published var assets: [MuxAsset] = []
    @Published var isLoadingAssets = false
    @Published var assetsError: String? = nil

    // MARK: Upload state
    @Published var uploadProgress: Double = 0
    @Published var uploadPhase: UploadPhase = .idle
    @Published var uploadError: String? = nil

    // MARK: Upload form
    @Published var videoTitle = ""
    @Published var selectedVideoItem: PhotosPickerItem? = nil
    @Published var selectedVideoURL: URL? = nil
    @Published var extractedRecordingDate: Date? = nil   // from video metadata

    // MARK: Upload phase enum
    enum UploadPhase: Equatable {
        case idle
        case pickingVideo
        case preparing
        case uploading
        case processing
        case done(MuxAsset)
        case failed(String)

        var isActive: Bool {
            switch self {
            case .idle, .done, .failed: return false
            default: return true
            }
        }

        var label: String {
            switch self {
            case .idle:           return "Välj video"
            case .pickingVideo:   return "Väljer video..."
            case .preparing:      return "Förbereder uppladdning..."
            case .uploading:      return "Laddar upp..."
            case .processing:     return "Bearbetar video..."
            case .done:           return "Klar!"
            case .failed(let e):  return "Fel: \(e)"
            }
        }
    }

    // MARK: - Load Assets

    func loadAssets() async {
        guard KeychainService.hasMuxCredentials else { return }
        isLoadingAssets = true
        assetsError = nil
        do {
            assets = try await MuxService.shared.listAssets()
        } catch {
            assetsError = error.localizedDescription
        }
        isLoadingAssets = false
    }

    // MARK: - Handle picked photo item

    func handlePickedItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        uploadPhase = .preparing
        uploadError = nil
        extractedRecordingDate = nil

        do {
            if let movie = try await item.loadTransferable(type: VideoTransferItem.self) {
                selectedVideoURL = movie.url
                // Extract creation date from video file metadata
                extractedRecordingDate = await VideoMetadata.extractCreationDate(from: movie.url)
                uploadPhase = .idle
            } else {
                throw NSError(domain: "MuxVM", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Kunde inte läsa videofilen."])
            }
        } catch {
            uploadPhase = .failed(error.localizedDescription)
            uploadError = error.localizedDescription
        }
    }

    // MARK: - Start Upload

    func startUpload() async {
        guard let fileURL = selectedVideoURL else { return }
        uploadPhase = .preparing
        uploadError = nil
        uploadProgress = 0

        do {
            // 1. Create direct upload (include title + recording date in passthrough)
            let title = videoTitle.isEmpty ? nil : videoTitle
            let upload = try await MuxService.shared.createDirectUpload(
                title: title,
                recordingDate: extractedRecordingDate
            )

            guard let putURL = URL(string: upload.url) else {
                throw MuxError.invalidResponse
            }

            // 2. Upload binary data
            uploadPhase = .uploading
            try await MuxService.shared.uploadVideo(fileURL: fileURL, to: putURL) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.uploadProgress = progress
                }
            }

            // 3. Poll for asset to become ready
            uploadPhase = .processing
            uploadProgress = 1.0

            var assetID = upload.assetID
            if assetID == nil {
                assetID = try await pollUploadForAssetID(uploadID: upload.id)
            }

            guard let aid = assetID else {
                throw MuxError.assetPollingTimeout
            }

            let asset = try await MuxService.shared.pollAsset(id: aid)

            uploadPhase = .done(asset)
            await loadAssets()

        } catch {
            uploadPhase = .failed(error.localizedDescription)
            uploadError = error.localizedDescription
        }
    }

    // MARK: - Delete Asset

    func deleteAsset(_ asset: MuxAsset) async {
        do {
            try await MuxService.shared.deleteAsset(id: asset.id)
            assets.removeAll { $0.id == asset.id }
        } catch {
            assetsError = error.localizedDescription
        }
    }

    // MARK: - Reset upload form

    func resetUpload() {
        videoTitle = ""
        selectedVideoItem = nil
        selectedVideoURL = nil
        uploadProgress = 0
        uploadPhase = .idle
        uploadError = nil
        extractedRecordingDate = nil
    }

    // MARK: - Private helpers

    private func pollUploadForAssetID(uploadID: String, maxAttempts: Int = 20) async throws -> String? {
        for _ in 0..<maxAttempts {
            try await Task.sleep(for: .seconds(2))
            if let assetID = try await fetchUploadAssetID(uploadID: uploadID) { return assetID }
        }
        return nil
    }

    private func fetchUploadAssetID(_ uploadID: String) async throws -> String? {
        let tid = KeychainService.muxTokenID
        let tsc = KeychainService.muxTokenSecret
        let url = URL(string: "https://api.mux.com/video/v1/uploads/\(uploadID)")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Basic \(Data("\(tid):\(tsc)".utf8).base64EncodedString())",
                     forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(MuxUploadResponse.self, from: data).data.assetID
    }
}

// MARK: - Video Metadata Extractor

enum VideoMetadata {
    /// Reads the creation date embedded in the video file's AVFoundation metadata.
    /// Covers iPhone MOV, MP4, and most common formats.
    static func extractCreationDate(from url: URL) async -> Date? {
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.commonMetadata) else { return nil }

        for item in items {
            guard item.commonKey == .commonKeyCreationDate else { continue }

            // Try native Date value first
            if let date = try? await item.load(.dateValue) {
                return date
            }

            // Fallback: parse ISO8601 string
            if let str = try? await item.load(.stringValue) {
                let f = ISO8601DateFormatter()
                for opts: ISO8601DateFormatter.Options in [
                    [.withInternetDateTime, .withFractionalSeconds],
                    .withInternetDateTime,
                    [.withFullDate]
                ] {
                    f.formatOptions = opts
                    if let date = f.date(from: str) { return date }
                }
            }
        }
        return nil
    }
}

// MARK: - Video Transferable Item

struct VideoTransferItem: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { exported in
            SentTransferredFile(exported.url)
        } importing: { received in
            let tempURL = FileManager.default
                .temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mov")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return VideoTransferItem(url: tempURL)
        }
    }
}
