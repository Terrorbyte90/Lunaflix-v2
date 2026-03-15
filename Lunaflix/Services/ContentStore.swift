import Foundation

/// Lightweight in-memory store shared between ViewModels and Views.
/// HomeViewModel writes to it after a successful load;
/// ContentDetailView/PlayerView reads from it to build the full playlist.
@MainActor
final class ContentStore {
    static let shared = ContentStore()
    private(set) var allContent: [LunaContent] = []

    private init() {}

    func update(_ content: [LunaContent]) {
        allContent = content
    }
}
