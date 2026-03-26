import Foundation
import PhotosUI
import SwiftUI

extension Notification.Name {
    static let lunaflixUploadDidComplete = Notification.Name("lunaflixUploadDidComplete")
}

// MARK: - Upload Job Phase

enum UploadJobPhase: Equatable {
    case loading
    case uploading
    case processing
    case done(MuxAsset)
    case failed(String)

    var label: String {
        switch self {
        case .loading:          return "Hämtar video..."
        case .uploading:        return "Laddar upp"
        case .processing:       return "Bearbetar på Mux..."
        case .done:             return "Klar"
        case .failed(let msg):  return msg
        }
    }

    var isActive: Bool {
        switch self {
        case .loading, .uploading, .processing: return true
        default: return false
        }
    }
}

// MARK: - Upload Job

@MainActor
final class UploadJob: Identifiable, ObservableObject {
    let id = UUID()
    let displayIndex: Int

    @Published var phase: UploadJobPhase = .loading
    @Published var progress: Double = 0
    @Published var speedBytesPerSec: Double = 0
    @Published var recordingDate: Date? = nil
    @Published var fileName: String? = nil

    init(index: Int) {
        self.displayIndex = index
    }

    var displayName: String {
        if let name = fileName, !name.isEmpty {
            // Strip extension and clean up temp UUID prefix if present
            let base = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent
            // If it's a UUID-looking string, fall back to index label
            if base.count == 36 && base.filter({ $0 == "-" }).count == 4 {
                return "Video \(displayIndex)"
            }
            return base
        }
        return "Video \(displayIndex)"
    }

    var speedString: String {
        guard speedBytesPerSec > 50_000 else { return "" }
        let mb = speedBytesPerSec / 1_000_000
        if mb >= 1 { return String(format: "%.1f MB/s", mb) }
        return String(format: "%.0f KB/s", speedBytesPerSec / 1_000)
    }
}

// MARK: - Upload Manager

@MainActor
final class UploadManager: ObservableObject {
    static let shared = UploadManager()

    @Published private(set) var jobs: [UploadJob] = []

    private init() {}

    var hasJobs: Bool { !jobs.isEmpty }
    var activeCount: Int { jobs.filter { $0.phase.isActive }.count }
    var completedCount: Int {
        jobs.filter {
            if case .done = $0.phase { return true }
            return false
        }.count
    }
    var failedCount: Int {
        jobs.filter {
            if case .failed = $0.phase { return true }
            return false
        }.count
    }

    func enqueue(items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        let startIndex = jobs.count + 1
        let hasCredentials = KeychainService.hasMuxCredentials
        for (i, item) in items.enumerated() {
            let job = UploadJob(index: startIndex + i)
            if !hasCredentials {
                job.phase = .failed(MuxError.missingCredentials.localizedDescription)
            }
            jobs.append(job)
            guard hasCredentials else { continue }
            Task { await run(job: job, pickerItem: item) }
        }
    }

    func remove(_ job: UploadJob) {
        withAnimation { jobs.removeAll { $0.id == job.id } }
    }

    func clearFinished() {
        withAnimation {
            jobs.removeAll {
                switch $0.phase {
                case .done, .failed: return true
                default: return false
                }
            }
        }
    }

    // MARK: - Private

    private func run(job: UploadJob, pickerItem: PhotosPickerItem) async {
        do {
            // 1. Load file from photo library
            guard let movie = try await pickerItem.loadTransferable(type: VideoTransferItem.self) else {
                throw NSError(domain: "UploadManager", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Kunde inte läsa videofilen."])
            }

            // Set filename from URL for better display
            job.fileName = movie.url.lastPathComponent

            // 2. Extract recording date from video metadata
            job.recordingDate = await VideoMetadata.extractCreationDate(from: movie.url)

            // 3. Create Mux direct upload with recording date in passthrough
            let inferredTitle = movie.url.deletingPathExtension().lastPathComponent
            let title = inferredTitle.isEmpty ? nil : inferredTitle
            let upload = try await MuxService.shared.createDirectUpload(
                title: title,
                recordingDate: job.recordingDate
            )

            guard let putURL = URL(string: upload.url) else {
                throw MuxError.invalidResponse
            }

            // 4. Upload binary data with progress + speed reporting
            job.phase = .uploading
            try await MuxService.shared.uploadVideo(fileURL: movie.url, to: putURL) { [weak job] progress, speed in
                Task { @MainActor [weak job] in
                    job?.progress = progress
                    job?.speedBytesPerSec = speed
                }
            }

            // 5. Poll for Mux asset to become ready
            job.phase = .processing
            job.progress = 1.0
            job.speedBytesPerSec = 0

            var assetID = upload.assetID
            if assetID == nil {
                assetID = try await pollUploadForAssetID(uploadID: upload.id)
            }

            guard let aid = assetID else {
                throw MuxError.assetPollingTimeout
            }

            let asset = try await MuxService.shared.pollAsset(id: aid)
            job.phase = .done(asset)
            NotificationCenter.default.post(name: .lunaflixUploadDidComplete, object: aid)

        } catch {
            job.phase = .failed(error.localizedDescription)
        }
    }

    private func pollUploadForAssetID(uploadID: String, maxAttempts: Int = 20) async throws -> String? {
        for _ in 0..<maxAttempts {
            try await Task.sleep(for: .seconds(2))
            if let id = try await MuxService.shared.fetchUploadAssetID(uploadID: uploadID) { return id }
        }
        return nil
    }
}
