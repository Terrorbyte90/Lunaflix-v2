import XCTest
@testable import Lunaflix

// MARK: - ProfileViewModel Unit Tests

@MainActor
final class ProfileViewModelTests: XCTestCase {

    var sut: ProfileViewModel!

    // Unique key prefix so tests don't pollute each other or the real app
    private let testSuiteKey = "lunaflixTest_\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        // Clear any pre-existing values for the keys used by ProfileViewModel
        UserDefaults.standard.removeObject(forKey: "lunaflix.notificationsEnabled")
        UserDefaults.standard.removeObject(forKey: "lunaflix.autoplayEnabled")
        UserDefaults.standard.removeObject(forKey: "lunaflix.downloadQuality")
        UserDefaults.standard.removeObject(forKey: "lunaflix.streamingQuality")
        sut = ProfileViewModel()
    }

    override func tearDown() {
        // Clean up after each test
        UserDefaults.standard.removeObject(forKey: "lunaflix.notificationsEnabled")
        UserDefaults.standard.removeObject(forKey: "lunaflix.autoplayEnabled")
        UserDefaults.standard.removeObject(forKey: "lunaflix.downloadQuality")
        UserDefaults.standard.removeObject(forKey: "lunaflix.streamingQuality")
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial state (defaults when no UserDefaults stored)

    func testDefaultUser() {
        XCTAssertEqual(sut.user.name, "Luna")
    }

    func testDefaultNotificationsEnabled() {
        XCTAssertTrue(sut.notificationsEnabled, "Notifications should default to true")
    }

    func testDefaultAutoplayEnabled() {
        XCTAssertTrue(sut.autoplayEnabled, "Autoplay should default to true")
    }

    func testDefaultDownloadQuality() {
        XCTAssertEqual(sut.downloadQuality, .high, "Download quality should default to .high")
    }

    func testDefaultStreamingQuality() {
        XCTAssertEqual(sut.streamingQuality, .auto, "Streaming quality should default to .auto")
    }

    // MARK: - Persistence — settings are saved to UserDefaults

    func testNotificationsPersistedWhenDisabled() {
        sut.notificationsEnabled = false
        let stored = UserDefaults.standard.object(forKey: "lunaflix.notificationsEnabled") as? Bool
        XCTAssertEqual(stored, false, "Disabled notifications should be stored in UserDefaults")
    }

    func testNotificationsPersistedWhenEnabled() {
        sut.notificationsEnabled = false
        sut.notificationsEnabled = true
        let stored = UserDefaults.standard.object(forKey: "lunaflix.notificationsEnabled") as? Bool
        XCTAssertEqual(stored, true)
    }

    func testAutoplayPersistedWhenDisabled() {
        sut.autoplayEnabled = false
        let stored = UserDefaults.standard.object(forKey: "lunaflix.autoplayEnabled") as? Bool
        XCTAssertEqual(stored, false)
    }

    func testDownloadQualityPersisted() {
        sut.downloadQuality = .standard
        let stored = UserDefaults.standard.string(forKey: "lunaflix.downloadQuality")
        XCTAssertEqual(stored, ProfileViewModel.DownloadQuality.standard.rawValue)
    }

    func testStreamingQualityPersisted() {
        sut.streamingQuality = .hd
        let stored = UserDefaults.standard.string(forKey: "lunaflix.streamingQuality")
        XCTAssertEqual(stored, ProfileViewModel.StreamingQuality.hd.rawValue)
    }

    // MARK: - Persistence — restored on next init

    func testSettingsRestoredOnNextInit() {
        sut.notificationsEnabled = false
        sut.autoplayEnabled = false
        sut.downloadQuality = .ultra
        sut.streamingQuality = .uhd

        // Create a fresh ViewModel — it should restore from UserDefaults
        let restored = ProfileViewModel()
        XCTAssertFalse(restored.notificationsEnabled)
        XCTAssertFalse(restored.autoplayEnabled)
        XCTAssertEqual(restored.downloadQuality, .ultra)
        XCTAssertEqual(restored.streamingQuality, .uhd)
    }

    // MARK: - Download quality cases

    func testDownloadQualityAllCasesExist() {
        let cases = ProfileViewModel.DownloadQuality.allCases
        XCTAssertTrue(cases.contains(.standard))
        XCTAssertTrue(cases.contains(.high))
        XCTAssertTrue(cases.contains(.ultra))
        XCTAssertEqual(cases.count, 3)
    }

    func testDownloadQualityRawValues() {
        XCTAssertEqual(ProfileViewModel.DownloadQuality.standard.rawValue, "Standard")
        XCTAssertEqual(ProfileViewModel.DownloadQuality.high.rawValue, "Hög")
        XCTAssertEqual(ProfileViewModel.DownloadQuality.ultra.rawValue, "Ultra HD")
    }

    // MARK: - Streaming quality cases

    func testStreamingQualityAllCasesExist() {
        let cases = ProfileViewModel.StreamingQuality.allCases
        XCTAssertTrue(cases.contains(.auto))
        XCTAssertTrue(cases.contains(.sd))
        XCTAssertTrue(cases.contains(.hd))
        XCTAssertTrue(cases.contains(.uhd))
        XCTAssertEqual(cases.count, 4)
    }

    func testStreamingQualityRawValues() {
        XCTAssertEqual(ProfileViewModel.StreamingQuality.auto.rawValue, "Automatisk")
        XCTAssertEqual(ProfileViewModel.StreamingQuality.sd.rawValue, "SD")
        XCTAssertEqual(ProfileViewModel.StreamingQuality.hd.rawValue, "HD")
        XCTAssertEqual(ProfileViewModel.StreamingQuality.uhd.rawValue, "4K")
    }

    // MARK: - recentActivity

    func testRecentActivityIsEmptyWithNoWatchHistory() {
        XCTAssertTrue(sut.recentActivity.isEmpty)
    }

    func testRecentActivityCappedAtFour() {
        let items = (0..<10).map { i in
            LunaContent(
                title: "Video \(i)",
                description: "",
                type: .movie,
                genre: [],
                rating: 0,
                year: 2024,
                duration: "5 min",
                thumbnailGradient: .purple
            )
        }
        sut.user.watchHistory = items
        XCTAssertLessThanOrEqual(sut.recentActivity.count, 4)
    }

    // MARK: - User mock

    func testUserMockHasCorrectName() {
        XCTAssertEqual(User.mock.name, "Luna")
    }

    func testUserMockIsNotPremium() {
        XCTAssertFalse(User.mock.isPremium)
    }

    func testUserMockHasEmptyWatchlist() {
        XCTAssertTrue(User.mock.watchlist.isEmpty)
    }
}
