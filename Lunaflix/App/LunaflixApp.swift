import SwiftUI

@main
struct LunaflixApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .tint(Color.lunaAccent)   // System accent for alerts, menus, etc.
        }
    }
}

// MARK: - App State

final class AppState: ObservableObject {
    @Published var selectedTab: Tab = .home
    @Published var currentUser: User = User.mock
    @Published var isLoggedIn: Bool = true

    // Global content navigation (for deep linking)
    @Published var presentedContent: LunaContent? = nil
}

// MARK: - Tab Definition

enum Tab: Int, CaseIterable {
    case home, search, downloads, profile

    var title: String {
        switch self {
        case .home:      return "Hem"
        case .search:    return "Sök"
        case .downloads: return "Laddat"
        case .profile:   return "Profil"
        }
    }

    var icon: String {
        switch self {
        case .home:      return "house.fill"
        case .search:    return "magnifyingglass"
        case .downloads: return "arrow.down.circle.fill"
        case .profile:   return "person.fill"
        }
    }
}
