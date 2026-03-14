import Foundation
import Security

enum KeychainService {
    private static let service = "se.lunaflix.app"

    enum Key: String {
        case muxTokenID     = "mux_token_id"
        case muxTokenSecret = "mux_token_secret"
    }

    // MARK: - Save

    @discardableResult
    static func save(_ value: String, for key: Key) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue,
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - Load

    static func load(_ key: Key) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key.rawValue,
            kSecReturnData:       kCFBooleanTrue as Any,
            kSecMatchLimit:       kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    // MARK: - Delete

    @discardableResult
    static func delete(_ key: Key) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key.rawValue
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    // MARK: - Mux helpers

    static var muxTokenID: String {
        get { load(.muxTokenID) ?? "" }
        set { save(newValue, for: .muxTokenID) }
    }

    static var muxTokenSecret: String {
        get { load(.muxTokenSecret) ?? "" }
        set { save(newValue, for: .muxTokenSecret) }
    }

    static var hasMuxCredentials: Bool {
        !muxTokenID.isEmpty && !muxTokenSecret.isEmpty
    }

    static func clearMuxCredentials() {
        delete(.muxTokenID)
        delete(.muxTokenSecret)
    }
}
