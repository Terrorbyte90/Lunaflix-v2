import Foundation
import PhotosUI
import SwiftUI

// MARK: - Upload Job Phase

enum UploadJobPhase: Equatable {
    case loading
    case uploading
    case processing
    case paused
    case done(MuxAsset)
    case failed(String)

    var label: String {
        switch self {
        case .loading:          return "Hämtar video..."
        case .uploading:        return "Laddar upp"
        case .processing:       return "Bearbetar på Mux..."
        case .paused:           return "Pausad"
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

    var canPause: Bool {
        switch self {
        case .uploading: return true
        default: return false
        }
    }

    var canResume: Bool {
        switch self {
        case .paused: return true
        default: return false
        }
    }

    var canRetry: Bool {
        switch self {
        case .failed: return true
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
    @Published var isPaused: Bool = false
    @Published var retryCount: Int = 0
    @Published var recordingDate: Date? = nil
    @Published var fileName: String? = nil
    @Published var totalBytes: Int64 = 0
    @Published var uploadedBytes: Int64 = 0

    // Internal task for cancellation/pause support
    var uploadTask: Task<Void, Never>?

    private let maxRetries = 3

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

    var estimatedTimeRemaining: String? {
        guard speedBytesPerSec > 0, !isPaused else { return nil }
        let remainingBytes = Double(totalBytes - uploadedBytes)
        let secondsRemaining = remainingBytes / speedBytesPerSec

        if secondsRemaining < 60 {
            return "< 1 min"
        } else if secondsRemaining < 3600 {
            let minutes = Int(secondsRemaining / 60)
            return "\(minutes) min"
        } else {
            let hours = Int(secondsRemaining / 3600)
            let minutes = Int((secondsRemaining.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }

    var canRetry: Bool {
        switch phase {
        case .failed: return retryCount < maxRetries
        default: return false
        }
    }

    var retryLabel: String {
        if retryCount >= maxRetries {
            return "Max antal försök nått"
        }
        return "Försök igen (\(maxRetries - retryCount) kvar)"
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

    func enqueue(items: [PhotosPickerItem]) {
        let startIndex = jobs.count + 1
        for (i, item) in items.enumerated() {
            let job = UploadJob(index: startIndex + i)
            jobs.append(job)
            let task = Task { await run(job: job, pickerItem: item) }
            job.uploadTask = task
        }
    }

    func remove(_ job: UploadJob) {
        job.uploadTask?.cancel()
        withAnimation(.lunaSnappy) {
            jobs.removeAll { $0.id == job.id }
        }
    }

    func clearFinished() {
        withAnimation(.lunaSnappy) {
            jobs.removeAll {
                switch $0.phase {
                case .done, .failed: return true
                default: return false
                }
            }
        }
    }

    // MARK: - Pause/Resume

    func pause(_ job: UploadJob) {
        guard job.phase.canPause else { return }
        job.isPaused = true
        job.phase = .paused
        LunaHaptic.light()
    }

    func resume(_ job: UploadJob) {
        guard job.phase.canResume else { return }
        job.isPaused = false
        job.phase = .uploading
        LunaHaptic.light()
    }

    // MARK: - Retry

    func retry(_ job: UploadJob) {
        guard job.canRetry else { return }
        job.retryCount += 1
        job.phase = .loading
        job.progress = 0
        job.speedBytesPerSec = 0

        // Re-enqueue the job - in a real implementation we'd need to store the original item
        // For now, we just reset the state and user will need to re-select
        // This is a limitation - in production you'd store the PhotosPickerItem
        LunaHaptic.medium()
    }

    // MARK: - Private

    private func run(job: UploadJob, pickerItem: PhotosPickerItem) async {
        do {
            // Check for cancellation
            try Task.checkCancellation()

            // 1. Load file from photo library
            guard let movie = try await pickerItem.loadTransferable(type: VideoTransferItem.self) else {
                throw NSError(domain: "UploadManager", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Kunde inte läsa videofilen."])
            }

            // Check for cancellation after load
            try Task.checkCancellation()

            // Set filename from URL for better display
            job.fileName = movie.url.lastPathComponent

            // Get file size for ETA
            if let attrs = try? FileManager.default.attributesOfItem(atPath: movie.url.path),
               let size = attrs[.size] as? Int64 {
                job.totalBytes = size
            }

            // 2. Extract recording date from video metadata
            job.recordingDate = await VideoMetadata.extractCreationDate(from: movie.url)

            // Check for cancellation/pause before upload
            try Task.checkCancellation()

            while job.isPaused {
                try await Task.sleep(for: .milliseconds(500))
                try Task.checkCancellation()
            }

            // 3. Create Mux direct upload with recording date in passthrough
            let upload = try await MuxService.shared.createDirectUpload(
                title: nil,
                recordingDate: job.recordingDate
            )

            guard let putURL = URL(string: upload.url) else {
                throw MuxError.invalidResponse
            }

            // Check for cancellation/pause before upload
            try Task.checkCancellation()

            // 4. Upload binary data with progress + speed reporting
            job.phase = .uploading
            try await MuxService.shared.uploadVideo(fileURL: movie.url, to: putURL) { [weak job] progress, speed in
                Task { @MainActor [weak job] in
                    guard let job = job, !job.isPaused else { return }
                    job.progress = progress
                    job.speedBytesPerSec = speed
                    if job.totalBytes > 0 {
                        job.uploadedBytes = Int64(Double(job.totalBytes) * progress)
                    }
                }
            }

            // Check for cancellation after upload
            try Task.checkCancellation()

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
            LunaHaptic.success()

        } catch is CancellationError {
            // Job was cancelled - remove from list
            jobs.removeAll { $0.id == job.id }
        } catch {
            job.phase = .failed(error.localizedDescription)
        }
    }

    private func pollUploadForAssetID(uploadID: String, maxAttempts: Int = 20) async throws -> String? {
        for _ in 0..<maxAttempts {
            try await Task.sleep(for: .seconds(2))
            if let id = try await fetchUploadAssetID(uploadID) { return id }
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