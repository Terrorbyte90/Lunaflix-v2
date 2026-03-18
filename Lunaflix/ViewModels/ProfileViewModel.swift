import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var user: User

    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "lunaflix.notificationsEnabled") }
    }
    @Published var autoplayEnabled: Bool {
        didSet { UserDefaults.standard.set(autoplayEnabled, forKey: "lunaflix.autoplayEnabled") }
    }
    @Published var downloadQuality: DownloadQuality {
        didSet { UserDefaults.standard.set(downloadQuality.rawValue, forKey: "lunaflix.downloadQuality") }
    }
    @Published var streamingQuality: StreamingQuality {
        didSet { UserDefaults.standard.set(streamingQuality.rawValue, forKey: "lunaflix.streamingQuality") }
    }

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
        let ud = UserDefaults.standard
        self.notificationsEnabled = ud.object(forKey: "lunaflix.notificationsEnabled") as? Bool ?? true
        self.autoplayEnabled      = ud.object(forKey: "lunaflix.autoplayEnabled") as? Bool ?? true
        self.downloadQuality      = DownloadQuality(rawValue: ud.string(forKey: "lunaflix.downloadQuality") ?? "") ?? .high
        self.streamingQuality     = StreamingQuality(rawValue: ud.string(forKey: "lunaflix.streamingQuality") ?? "") ?? .auto
    }

    var recentActivity: [LunaContent] { Array(user.watchHistory.prefix(4)) }
}
