import SwiftUI

@main
struct LunaflixApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

final class AppState: ObservableObject {
    @Published var selectedTab: Tab = .home
    @Published var currentUser: User = User.mock
    @Published var isLoggedIn: Bool = true
}

enum Tab: Int, CaseIterable {
    case home, search, downloads, profile

    var title: String {
        switch self {
        case .home: return "Hem"
        case .search: return "Sök"
        case .downloads: return "Nedladdningar"
        case .profile: return "Profil"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .downloads: return "arrow.down.circle.fill"
        case .profile: return "person.fill"
        }
    }
}
