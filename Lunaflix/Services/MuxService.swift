import Foundation

// MARK: - Mux API Service

actor MuxService {
    static let shared = MuxService()

    private let baseURL = URL(string: "https://api.mux.com")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest  = 30
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
    }

    // MARK: - Auth header

    private func authHeader(tokenID: String, tokenSecret: String) -> String {
        let creds = "\(tokenID):\(tokenSecret)"
        let encoded = Data(creds.utf8).base64EncodedString()
        return "Basic \(encoded)"
    }

    private func authorizedRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        tokenID: String? = nil,
        tokenSecret: String? = nil
    ) throws -> URLRequest {
        let tid = tokenID    ?? KeychainService.muxTokenID
        let tsc = tokenSecret ?? KeychainService.muxTokenSecret
        guard !tid.isEmpty, !tsc.isEmpty else {
            throw MuxError.missingCredentials
        }
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(authHeader(tokenID: tid, tokenSecret: tsc), forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        return req
    }

    // MARK: - Test Connection

    func testConnection(tokenID: String, tokenSecret: String) async throws {
        let req = try authorizedRequest(path: "/video/v1/assets?limit=1", tokenID: tokenID, tokenSecret: tokenSecret)
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw MuxError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300: return
        case 401: throw MuxError.unauthorized
        default:  throw MuxError.serverError(http.statusCode)
        }
    }

    // MARK: - List Assets

    func listAssets(limit: Int = 100) async throws -> [MuxAsset] {
        let req = try authorizedRequest(path: "/video/v1/assets?limit=\(limit)&order_direction=desc")
        let (data, response) = try await session.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(MuxAssetListResponse.self, from: data).data
    }

    // MARK: - Get Asset

    func getAsset(id: String) async throws -> MuxAsset {
        let req = try authorizedRequest(path: "/video/v1/assets/\(id)")
        let (data, response) = try await session.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(MuxAssetResponse.self, from: data).data
    }

    // MARK: - Create Direct Upload

    func createDirectUpload(title: String?, recordingDate: Date? = nil) async throws -> MuxDirectUpload {
        let passthrough = MuxPassthroughMeta.encode(title: title, recordingDate: recordingDate)
        let body = MuxCreateUploadRequest(
            newAssetSettings: .init(
                playbackPolicy: ["public"],
                passthrough: passthrough
            )
        )
        let bodyData = try JSONEncoder().encode(body)
        let req = try authorizedRequest(path: "/video/v1/uploads", method: "POST", body: bodyData)
        let (data, response) = try await session.data(for: req)
        try validate(response)
        return try JSONDecoder().decode(MuxUploadResponse.self, from: data).data
    }

    // MARK: - Upload Video

    func uploadVideo(fileURL: URL, to uploadURL: URL, progressHandler: @escaping (Double, Double) -> Void) async throws {
        var req = URLRequest(url: uploadURL)
        req.httpMethod = "PUT"
        req.setValue("video/*", forHTTPHeaderField: "Content-Type")

        let delegate = UploadProgressDelegate(progressHandler: progressHandler)
        let uploadSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { uploadSession.invalidateAndCancel() }

        // Stream directly from file — avoids loading the entire video into RAM
        let (_, response) = try await uploadSession.upload(for: req, fromFile: fileURL)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw MuxError.uploadFailed
        }
    }

    // MARK: - Poll Asset Until Ready

    func pollAsset(id: String, maxAttempts: Int = 30, intervalSeconds: Double = 3) async throws -> MuxAsset {
        for attempt in 0..<maxAttempts {
            let asset = try await getAsset(id: id)
            switch asset.status {
            case .ready:    return asset
            case .errored:  throw MuxError.assetProcessingFailed
            default:
                if attempt < maxAttempts - 1 {
                    try await Task.sleep(for: .seconds(intervalSeconds))
                }
            }
        }
        throw MuxError.assetPollingTimeout
    }

    // MARK: - Delete Asset

    func deleteAsset(id: String) async throws {
        let req = try authorizedRequest(path: "/video/v1/assets/\(id)", method: "DELETE")
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw MuxError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    // MARK: - Helpers

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw MuxError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300: return
        case 401: throw MuxError.unauthorized
        case 404: throw MuxError.notFound
        default:  throw MuxError.serverError(http.statusCode)
        }
    }
}

// MARK: - Upload Progress Delegate

private final class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    let progressHandler: (Double, Double) -> Void   // (progress 0–1, speedBytesPerSec)
    private var lastSample: (bytes: Int64, time: TimeInterval) = (0, 0)
    private var lastKnownSpeed: Double = 0

    init(progressHandler: @escaping (Double, Double) -> Void) {
        self.progressHandler = progressHandler
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didSendBodyData bytesSent: Int64, totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        let now = Date().timeIntervalSinceReferenceDate
        if lastSample.time > 0 {
            let dt = now - lastSample.time
            if dt >= 0.3 {
                lastKnownSpeed = Double(totalBytesSent - lastSample.bytes) / dt
                lastSample = (totalBytesSent, now)
            }
        } else {
            lastSample = (totalBytesSent, now)
        }
        let speed = lastKnownSpeed
        DispatchQueue.main.async { self.progressHandler(progress, speed) }
    }
}

// MARK: - Errors

enum MuxError: LocalizedError {
    case missingCredentials
    case unauthorized
    case invalidResponse
    case notFound
    case serverError(Int)
    case uploadFailed
    case assetProcessingFailed
    case assetPollingTimeout

    var errorDescription: String? {
        switch self {
        case .missingCredentials:     return "Ange Mux Token ID och Token Secret i inställningarna."
        case .unauthorized:           return "Ogiltiga Mux API-nycklar. Kontrollera dina uppgifter."
        case .invalidResponse:        return "Oväntat svar från Mux API."
        case .notFound:               return "Resursen hittades inte."
        case .serverError(let code):  return "Mux API-fel (\(code))."
        case .uploadFailed:           return "Uppladdningen misslyckades."
        case .assetProcessingFailed:  return "Videon kunde inte bearbetas av Mux."
        case .assetPollingTimeout:    return "Timeout — videon bearbetas fortfarande. Försök igen om en stund."
        }
    }
}
