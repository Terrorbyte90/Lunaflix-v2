import Foundation

// MARK: - Mux Asset

struct MuxAsset: Identifiable, Decodable {
    let id: String
    let status: MuxAssetStatus
    let playbackIDs: [MuxPlaybackID]?
    let duration: Double?
    let aspectRatio: String?
    let createdAt: Int?
    let passthrough: String?

    var primaryPlaybackID: String? {
        playbackIDs?.first(where: { $0.policy == "public" })?.id
            ?? playbackIDs?.first?.id
    }

    var hlsURL: URL? {
        guard let pid = primaryPlaybackID else { return nil }
        return URL(string: "https://stream.mux.com/\(pid).m3u8")
    }

    var thumbnailURL: URL? {
        guard let pid = primaryPlaybackID else { return nil }
        return URL(string: "https://image.mux.com/\(pid)/thumbnail.jpg?width=640&height=360&fit_mode=smartcrop")
    }

    var isReady: Bool { status == .ready }

    var formattedDuration: String {
        guard let d = duration else { return "Okänd" }
        let total = Int(d)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h) t \(m) min" }
        if m > 0 { return "\(m) min" }
        return "\(s) sek"
    }

    // Display title — uses passthrough JSON if set, otherwise falls back to id
    var displayTitle: String {
        if let p = passthrough,
           let data = p.data(using: .utf8),
           let dict = try? JSONDecoder().decode([String: String].self, from: data),
           let title = dict["title"], !title.isEmpty {
            return title
        }
        return "Video \(id.prefix(8))"
    }

    enum CodingKeys: String, CodingKey {
        case id, status, duration, passthrough
        case playbackIDs  = "playback_ids"
        case aspectRatio  = "aspect_ratio"
        case createdAt    = "created_at"
    }
}

enum MuxAssetStatus: String, Decodable {
    case preparing
    case ready
    case errored
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MuxAssetStatus(rawValue: raw) ?? .unknown
    }
}

struct MuxPlaybackID: Decodable {
    let id: String
    let policy: String
}

// MARK: - List Response

struct MuxAssetListResponse: Decodable {
    let data: [MuxAsset]
}

struct MuxAssetResponse: Decodable {
    let data: MuxAsset
}

// MARK: - Direct Upload

struct MuxDirectUpload: Decodable {
    let id: String
    let url: String
    let status: String
    let assetID: String?

    enum CodingKeys: String, CodingKey {
        case id, url, status
        case assetID = "asset_id"
    }
}

struct MuxUploadResponse: Decodable {
    let data: MuxDirectUpload
}

// MARK: - Upload Request

struct MuxCreateUploadRequest: Encodable {
    let corsOrigin: String = "*"
    let newAssetSettings: NewAssetSettings

    struct NewAssetSettings: Encodable {
        let playbackPolicy: [String]
        let passthrough: String?

        enum CodingKeys: String, CodingKey {
            case playbackPolicy = "playback_policy"
            case passthrough
        }
    }

    enum CodingKeys: String, CodingKey {
        case corsOrigin = "cors_origin"
        case newAssetSettings = "new_asset_settings"
    }
}
