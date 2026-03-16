import SwiftUI
import PhotosUI
import AVFoundation

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
