import Foundation

struct ResumeStore {
    static let shared = ResumeStore()
    private let defaults = UserDefaults.standard
    private let keyPrefix = "lunaflix.resume."

    private init() {}

    func save(playbackID: String, position: Double) {
        defaults.set(position, forKey: keyPrefix + playbackID)
    }

    /// Returns nil if saved position is ≤ 5s (not worth resuming from)
    func position(for playbackID: String) -> Double? {
        let v = defaults.double(forKey: keyPrefix + playbackID)
        return v > 5 ? v : nil
    }

    func clear(playbackID: String) {
        defaults.removeObject(forKey: keyPrefix + playbackID)
    }
}
