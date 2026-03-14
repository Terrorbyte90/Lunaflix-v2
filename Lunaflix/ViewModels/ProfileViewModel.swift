import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var user: User
    @Published var showingSettings = false
    @Published var notificationsEnabled = true
    @Published var autoplayEnabled = true
    @Published var downloadQuality: DownloadQuality = .high
    @Published var streamingQuality: StreamingQuality = .auto

    enum DownloadQuality: String, CaseIterable {
        case standard = "Standard"
        case high = "Hög"
        case ultra = "Ultra HD"
    }

    enum StreamingQuality: String, CaseIterable {
        case auto = "Automatisk"
        case sd = "SD"
        case hd = "HD"
        case uhd = "4K"
    }

    init(user: User = User.mock) {
        self.user = user
    }

    var stats: [(label: String, value: String)] {
        [
            ("Tittar på", "\(user.watchHistory.count) titlar"),
            ("Bevakningslista", "\(user.watchlist.count) titlar"),
            ("Nedladdningar", "3 titlar"),
            ("Prenumeration", user.isPremium ? "Premium" : "Bas")
        ]
    }

    var recentActivity: [LunaContent] { Array(user.watchHistory.prefix(4)) }
}
