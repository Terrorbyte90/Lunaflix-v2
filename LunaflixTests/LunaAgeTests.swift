import XCTest
@testable import Lunaflix

// MARK: - LunaAge Unit Tests

final class LunaAgeTests: XCTestCase {

    // Luna's birthday: 2023-07-02
    private let birthday = LunaAge.birthday

    // MARK: - Helpers

    private func date(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        return Calendar.current.date(from: c)!
    }

    // MARK: - birthday constant

    func testBirthdayIsCorrect() {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: birthday)
        XCTAssertEqual(comps.year, 2023)
        XCTAssertEqual(comps.month, 7)
        XCTAssertEqual(comps.day, 2)
    }

    // MARK: - age(at:) — full string

    func testAgeBeforeBirthday() {
        let before = date(year: 2023, month: 7, day: 1)
        XCTAssertEqual(LunaAge.age(at: before), "inte född än")
    }

    func testAgeOnBirthday() {
        // guard date > birthday — on exactly the birthday date is NOT > birthday,
        // so the function returns "inte född än".
        // This matches the source code: strict greater-than comparison.
        XCTAssertEqual(LunaAge.age(at: birthday), "inte född än")
    }

    func testAgeOneDayOld() {
        // 2023-07-03: birthday is 2023-07-02, so this is 1 day after
        // Since date > birthday guard passes (2023-07-03 > 2023-07-02)
        let oneDay = date(year: 2023, month: 7, day: 3)
        let result = LunaAge.age(at: oneDay)
        // y == 0, so days are included: "1 dag"
        XCTAssertTrue(result.contains("1 dag"), "Expected '1 dag', got '\(result)'")
    }

    func testAgeTwoDaysOld() {
        let twoDays = date(year: 2023, month: 7, day: 4)
        let result = LunaAge.age(at: twoDays)
        XCTAssertTrue(result.contains("2 dagar"), "Expected '2 dagar', got '\(result)'")
    }

    func testAgeOneMonthOld() {
        // 2023-08-02 = exactly 1 month
        let oneMonth = date(year: 2023, month: 8, day: 2)
        let result = LunaAge.age(at: oneMonth)
        XCTAssertTrue(result.contains("1 månad"), "Expected '1 månad', got '\(result)'")
        // No years, so days are added when > 0. On exact month boundary days == 0, so no days.
        XCTAssertFalse(result.contains("år"), "Should not contain 'år', got '\(result)'")
    }

    func testAgeOneMonthAndFiveDays() {
        // 2023-09-07 = 2 months 5 days (July: 31d, Aug 2 + 5 = Sep 7)
        // Actually: from 2023-07-02 to 2023-09-07 = 2 months 5 days
        let d = date(year: 2023, month: 9, day: 7)
        let result = LunaAge.age(at: d)
        // y == 0, so days are included
        XCTAssertTrue(result.contains("månader"), "Expected 'månader', got '\(result)'")
        XCTAssertTrue(result.contains("dagar") || result.contains("dag"), "Expected days, got '\(result)'")
    }

    func testAgeOneYear() {
        // 2024-07-02 = exactly 1 år
        let oneYear = date(year: 2024, month: 7, day: 2)
        let result = LunaAge.age(at: oneYear)
        XCTAssertTrue(result.contains("1 år"), "Expected '1 år', got '\(result)'")
        // y > 0 so days should NOT be shown
        XCTAssertFalse(result.contains("dag"), "Days should not be shown when y > 0, got '\(result)'")
    }

    func testAgeOneYearThreeMonths() {
        // 2025-10-02 = 2 år 3 månader from birthday 2023-07-02
        let d = date(year: 2025, month: 10, day: 2)
        let result = LunaAge.age(at: d)
        XCTAssertTrue(result.contains("2 år"), "Expected '2 år', got '\(result)'")
        XCTAssertTrue(result.contains("3 månader"), "Expected '3 månader', got '\(result)'")
    }

    func testAgeLabel() {
        let oneYear = date(year: 2024, month: 7, day: 2)
        let label = LunaAge.ageLabel(at: oneYear)
        XCTAssertTrue(label.hasPrefix("Luna var "), "Label should start with 'Luna var', got '\(label)'")
        XCTAssertTrue(label.hasSuffix(" gammal"), "Label should end with ' gammal', got '\(label)'")
    }

    // MARK: - ageShort(at:) — card format

    func testAgeShortBeforeBirthday() {
        let before = date(year: 2023, month: 1, day: 1)
        XCTAssertEqual(LunaAge.ageShort(at: before), "−")
    }

    func testAgeShortDaysOnly() {
        let d = date(year: 2023, month: 7, day: 5) // 3 days
        let result = LunaAge.ageShort(at: d)
        XCTAssertTrue(result.contains("d"), "Expected 'd' (days), got '\(result)'")
    }

    func testAgeShortMonthsOnly() {
        // 2023-10-02 = exactly 3 mån, 0 days
        let d = date(year: 2023, month: 10, day: 2)
        let result = LunaAge.ageShort(at: d)
        XCTAssertTrue(result.contains("mån"), "Expected 'mån', got '\(result)'")
        XCTAssertFalse(result.contains(" d"), "Should not have days, got '\(result)'")
    }

    func testAgeShortYearAndMonths() {
        // 2024-10-02 = 1 år 3 mån
        let d = date(year: 2024, month: 10, day: 2)
        let result = LunaAge.ageShort(at: d)
        XCTAssertTrue(result.contains("år"), "Expected 'år', got '\(result)'")
        XCTAssertTrue(result.contains("mån"), "Expected 'mån', got '\(result)'")
    }

    func testAgeShortYearOnlyNoMonths() {
        // 2024-07-02 = 1 år 0 månader — should just be "1 år"
        let d = date(year: 2024, month: 7, day: 2)
        let result = LunaAge.ageShort(at: d)
        XCTAssertEqual(result, "1 år", "Expected '1 år', got '\(result)'")
    }

    // MARK: - formatted(_:) — Swedish date format

    func testFormattedDateIsSwedish() {
        let d = date(year: 2024, month: 3, day: 15)
        let result = LunaAge.formatted(d)
        // Swedish months: "mars" for March
        XCTAssertTrue(result.lowercased().contains("mars"), "Expected Swedish month 'mars', got '\(result)'")
    }

    func testFormattedDateContainsYear() {
        let d = date(year: 2025, month: 12, day: 1)
        let result = LunaAge.formatted(d)
        XCTAssertTrue(result.contains("2025"), "Expected year 2025 in formatted date, got '\(result)'")
    }

    // MARK: - ageLabel via LunaContent

    func testLunaContentAgeLabel() {
        let recordingDate = date(year: 2024, month: 7, day: 2)
        let content = LunaContent(
            title: "Test",
            description: "Desc",
            type: .movie,
            genre: [],
            rating: 0,
            year: 2024,
            duration: "1 min",
            thumbnailGradient: .purple,
            recordingDate: recordingDate
        )
        XCTAssertNotNil(content.lunaAgeAtRecording)
        XCTAssertTrue(content.lunaAgeAtRecording!.contains("Luna var"))
    }

    func testLunaContentNoRecordingDateGivesNilAgeLabel() {
        let content = LunaContent(
            title: "Test",
            description: "Desc",
            type: .movie,
            genre: [],
            rating: 0,
            year: 2024,
            duration: "1 min",
            thumbnailGradient: .blue,
            recordingDate: nil
        )
        XCTAssertNil(content.lunaAgeAtRecording)
    }
}
