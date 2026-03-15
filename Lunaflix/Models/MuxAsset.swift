import Foundation

// MARK: - Mux Asset

struct MuxAsset: Identifiable, Decodable, Equatable {
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
        guard let d = duration else { return "Okänd längd" }
        let total = Int(d)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h) t \(m) min" }
        if m > 0 { return "\(m) min" }
        return "\(s) sek"
    }

    // MARK: - Passthrough metadata

    private var passthroughMeta: MuxPassthroughMeta? {
        guard let p = passthrough, let data = p.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(MuxPassthroughMeta.self, from: data)
    }

    /// Display title — from passthrough JSON or fallback to ID prefix
    var displayTitle: String {
        let t = passthroughMeta?.title ?? ""
        return t.isEmpty ? "Video \(id.prefix(8))" : t
    }

    /// Original recording date embedded at upload time
    var recordingDate: Date? {
        guard let str = passthroughMeta?.recordingDate else { return nil }
        return ISO8601DateFormatter().date(from: str)
    }

    /// "Luna var X månader gammal" — nil if no recording date stored
    var lunaAgeAtRecording: String? {
        guard let date = recordingDate else { return nil }
        return LunaAge.ageLabel(at: date)
    }

    enum CodingKeys: String, CodingKey {
        case id, status, duration, passthrough
        case playbackIDs  = "playback_ids"
        case aspectRatio  = "aspect_ratio"
        case createdAt    = "created_at"
    }
}

// MARK: - Passthrough JSON schema

struct MuxPassthroughMeta: Codable {
    var title: String?
    var recordingDate: String?   // ISO8601 UTC

    enum CodingKeys: String, CodingKey {
        case title
        case recordingDate = "recordingDate"
    }

    static func encode(title: String?, recordingDate: Date?) -> String? {
        var meta = MuxPassthroughMeta()
        meta.title = title?.isEmpty == false ? title : nil
        if let date = recordingDate {
            meta.recordingDate = ISO8601DateFormatter().string(from: date)
        }
        guard meta.title != nil || meta.recordingDate != nil else { return nil }
        return try? String(data: JSONEncoder().encode(meta), encoding: .utf8)
    }
}

// MARK: - Asset status

enum MuxAssetStatus: String, Decodable, Equatable {
    case preparing
    case ready
    case errored
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MuxAssetStatus(rawValue: raw) ?? .unknown
    }
}

struct MuxPlaybackID: Decodable, Equatable {
    let id: String
    let policy: String
}

// MARK: - List / single responses

struct MuxAssetListResponse: Decodable { let data: [MuxAsset] }
struct MuxAssetResponse:     Decodable { let data: MuxAsset }

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

struct MuxUploadResponse: Decodable { let data: MuxDirectUpload }

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
        case corsOrigin       = "cors_origin"
        case newAssetSettings = "new_asset_settings"
    }
}
