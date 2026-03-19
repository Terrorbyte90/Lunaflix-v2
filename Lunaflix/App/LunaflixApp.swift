import SwiftUI
import Kingfisher

@main
struct LunaflixApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()

    init() {
        // Kingfisher disk cache: 200 MB, memory cache: 50 MB
        KingfisherManager.shared.cache.diskStorage.config.sizeLimit = 200 * 1024 * 1024
        KingfisherManager.shared.cache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .tint(Color.lunaAccent)
        }
    }
}

// MARK: - App Delegate (for orientation lock)

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        return OrientationManager.shared.allowLandscape
            ? .allButUpsideDown
            : .portrait
    }
}

// MARK: - Orientation Manager

final class OrientationManager: ObservableObject {
    static let shared = OrientationManager()

    @Published var allowLandscape = false {
        didSet {
            // Notify UIKit that supported orientations changed
            guard let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: allowLandscape ? .allButUpsideDown : .portrait)) { _ in }
            windowScene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    private init() {}
}

// MARK: - App State

final class AppState: ObservableObject {
    @Published var selectedTab: Tab = .home
    @Published var currentUser: User = User.mock
    @Published var isLoggedIn: Bool = true
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
