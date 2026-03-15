import Foundation
import AVFoundation
import SwiftUI

// MARK: - Download Item

struct DownloadItem: Identifiable, Codable {
    let id: UUID
    let contentID: UUID
    let title: String
    let muxPlaybackID: String
    let thumbnailGradient: ThumbnailStyle
    let duration: String
    var progress: Double = 0
    var isReady: Bool = false
    var errorMessage: String? = nil
    var localRelativePath: String? = nil

    var localURL: URL? {
        guard let rel = localRelativePath else { return nil }
        let lib = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return lib.appendingPathComponent(rel)
    }

    var fileSizeString: String {
        guard let url = localURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let bytes = attrs[.size] as? Int64 else { return "–" }
        let mb = Double(bytes) / 1_000_000
        let gb = Double(bytes) / 1_000_000_000
        return gb >= 1 ? String(format: "%.1f GB", gb) : String(format: "%.0f MB", mb)
    }

    func toLunaContent() -> LunaContent {
        LunaContent(
            id: contentID,
            title: title,
            description: "",
            type: .movie,
            genre: [],
            rating: 0,
            year: Calendar.current.component(.year, from: Date()),
            duration: duration,
            thumbnailGradient: thumbnailGradient,
            muxPlaybackID: muxPlaybackID
        )
    }
}

// MARK: - Download Manager

@MainActor
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var downloads: [DownloadItem] = []

    private var downloadSession: AVAssetDownloadURLSession?
    private var tasksByItemID: [UUID: AVAssetDownloadTask] = [:]

    private let persistKey = "lunaflix.downloads.v2"

    private override init() {
        super.init()
        loadPersisted()
        configureSession()
    }

    // MARK: - Session Setup

    private func configureSession() {
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.lunaflix.hls.download"
        )
        config.isDiscretionary = false
        downloadSession = AVAssetDownloadURLSession(
            configuration: config,
            assetDownloadDelegate: self,
            delegateQueue: OperationQueue.main
        )
    }

    // MARK: - Public API

    func download(_ content: LunaContent) {
        guard let playbackID = content.muxPlaybackID else { return }
        guard !isTracked(content) else { return }

        let item = DownloadItem(
            id: UUID(),
            contentID: content.id,
            title: content.title,
            muxPlaybackID: playbackID,
            thumbnailGradient: content.thumbnailGradient,
            duration: content.duration
        )

        downloads.append(item)
        persist()
        startTask(for: item)
    }

    func delete(_ item: DownloadItem) {
        tasksByItemID[item.id]?.cancel()
        tasksByItemID.removeValue(forKey: item.id)
        if let url = item.localURL {
            try? FileManager.default.removeItem(at: url)
        }
        withAnimation {
            downloads.removeAll { $0.id == item.id }
        }
        persist()
    }

    func retry(_ item: DownloadItem) {
        guard let idx = downloads.firstIndex(where: { $0.id == item.id }) else { return }
        downloads[idx].progress = 0
        downloads[idx].errorMessage = nil
        persist()
        startTask(for: downloads[idx])
    }

    func isDownloaded(_ content: LunaContent) -> Bool {
        downloads.contains { $0.contentID == content.id && $0.isReady }
    }

    func isDownloading(_ content: LunaContent) -> Bool {
        downloads.contains { $0.contentID == content.id && !$0.isReady && $0.errorMessage == nil }
    }

    func item(for content: LunaContent) -> DownloadItem? {
        downloads.first { $0.contentID == content.id }
    }

    var totalStorageBytes: Int64 {
        downloads
            .compactMap { $0.localURL?.path }
            .compactMap { try? FileManager.default.attributesOfItem(atPath: $0)[.size] as? Int64 }
            .reduce(0, +)
    }

    // MARK: - Private

    private func isTracked(_ content: LunaContent) -> Bool {
        downloads.contains { $0.contentID == content.id }
    }

    private func startTask(for item: DownloadItem) {
        guard let session = downloadSession else { return }
        let hlsURL = URL(string: "https://stream.mux.com/\(item.muxPlaybackID).m3u8")!
        let asset = AVURLAsset(url: hlsURL)
        guard let task = session.makeAssetDownloadTask(
            asset: asset,
            assetTitle: item.title,
            assetArtworkData: nil,
            options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 2_000_000]
        ) else { return }
        task.taskDescription = item.id.uuidString
        tasksByItemID[item.id] = task
        task.resume()
    }

    // MARK: - Persistence

    private func persist() {
        let encoder = JSONEncoder()
        let saveable = downloads.filter { $0.isReady || $0.errorMessage == nil }
        if let data = try? encoder.encode(saveable) {
            UserDefaults.standard.set(data, forKey: persistKey)
        }
    }

    private func loadPersisted() {
        guard let data = UserDefaults.standard.data(forKey: persistKey),
              let items = try? JSONDecoder().decode([DownloadItem].self, from: data) else { return }
        downloads = items.map { item in
            var i = item
            if !i.isReady { i.progress = 0 }
            return i
        }
    }
}

// MARK: - AVAssetDownloadDelegate

extension DownloadManager: AVAssetDownloadDelegate {

    nonisolated func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didLoad timeRange: CMTimeRange,
        totalTimeRangesLoaded: [NSValue],
        timeRangeExpectedToLoad: CMTimeRange
    ) {
        guard let idStr = assetDownloadTask.taskDescription,
              let itemID = UUID(uuidString: idStr) else { return }

        let expectedSecs = timeRangeExpectedToLoad.duration.seconds
        guard expectedSecs > 0 else { return }

        let loadedSecs = totalTimeRangesLoaded.reduce(0.0) { acc, val in
            acc + val.timeRangeValue.duration.seconds
        }
        let progress = min(loadedSecs / expectedSecs, 1.0)

        Task { @MainActor [weak self] in
            guard let self else { return }
            if let idx = self.downloads.firstIndex(where: { $0.id == itemID }) {
                self.downloads[idx].progress = progress
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let idStr = assetDownloadTask.taskDescription,
              let itemID = UUID(uuidString: idStr) else { return }

        let libPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].path
        let fullPath = location.path
        let relPath = fullPath.hasPrefix(libPath + "/")
            ? String(fullPath.dropFirst(libPath.count + 1))
            : fullPath

        Task { @MainActor [weak self] in
            guard let self else { return }
            if let idx = self.downloads.firstIndex(where: { $0.id == itemID }) {
                self.downloads[idx].localRelativePath = relPath
                self.downloads[idx].isReady = true
                self.downloads[idx].progress = 1.0
                self.tasksByItemID.removeValue(forKey: itemID)
                self.persist()
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        guard let idStr = task.taskDescription,
              let itemID = UUID(uuidString: idStr) else { return }
        let nsError = error as NSError
        guard nsError.code != NSURLErrorCancelled else { return }

        let message = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let idx = self.downloads.firstIndex(where: { $0.id == itemID }) {
                self.downloads[idx].errorMessage = message
                self.tasksByItemID.removeValue(forKey: itemID)
                self.persist()
            }
        }
    }
}
