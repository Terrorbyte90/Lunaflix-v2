import XCTest
@testable import Lunaflix

// MARK: - MuxAsset Model Tests

final class MuxAssetTests: XCTestCase {

    // MARK: - Helpers

    private func makeAsset(
        id: String = "abc123",
        status: MuxAssetStatus = .ready,
        playbackIDs: [MuxPlaybackID]? = [MuxPlaybackID(id: "pid001", policy: "public")],
        duration: Double? = 125.0,
        aspectRatio: String? = "16:9",
        createdAt: Int? = 1_700_000_000,
        passthrough: String? = nil
    ) -> MuxAsset {
        // Decode via JSON since MuxAsset initializer is private (Decodable)
        let pid = playbackIDs.map { pids in
            pids.map { "{\"id\":\"\($0.id)\",\"policy\":\"\($0.policy)\"}" }.joined(separator: ",")
        }
        let playbackJSON = pid.map { "\"playback_ids\":[\($0)]," } ?? ""
        let durationJSON = duration.map { "\"duration\":\($0)," } ?? ""
        let arJSON = aspectRatio.map { "\"aspect_ratio\":\"\($0)\"," } ?? ""
        let createdJSON = createdAt.map { "\"created_at\":\($0)," } ?? ""
        let passJSON = passthrough.map { "\"passthrough\":\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"," } ?? ""

        let json = """
        {
          "id":"\(id)",
          "status":"\(status.rawValue)",
          \(playbackJSON)
          \(durationJSON)
          \(arJSON)
          \(createdJSON)
          \(passJSON)
          "_dummy": null
        }
        """
        return try! JSONDecoder().decode(MuxAsset.self, from: json.data(using: .utf8)!)
    }

    // MARK: - isReady

    func testIsReadyWhenStatusReady() {
        let asset = makeAsset(status: .ready)
        XCTAssertTrue(asset.isReady)
    }

    func testIsReadyFalseWhenPreparing() {
        let asset = makeAsset(status: .preparing)
        XCTAssertFalse(asset.isReady)
    }

    func testIsReadyFalseWhenErrored() {
        let asset = makeAsset(status: .errored)
        XCTAssertFalse(asset.isReady)
    }

    func testIsReadyFalseWhenUnknown() {
        let asset = makeAsset(status: .unknown)
        XCTAssertFalse(asset.isReady)
    }

    // MARK: - primaryPlaybackID

    func testPrimaryPlaybackIDReturnsPublicPolicy() {
        let asset = makeAsset(playbackIDs: [
            MuxPlaybackID(id: "signed_id", policy: "signed"),
            MuxPlaybackID(id: "public_id", policy: "public")
        ])
        XCTAssertEqual(asset.primaryPlaybackID, "public_id")
    }

    func testPrimaryPlaybackIDFallsBackToFirst() {
        let asset = makeAsset(playbackIDs: [
            MuxPlaybackID(id: "signed_id", policy: "signed")
        ])
        XCTAssertEqual(asset.primaryPlaybackID, "signed_id")
    }

    func testPrimaryPlaybackIDNilWhenEmpty() {
        let asset = makeAsset(playbackIDs: [])
        XCTAssertNil(asset.primaryPlaybackID)
    }

    func testPrimaryPlaybackIDNilWhenNilPlaybackIDs() {
        let asset = makeAsset(playbackIDs: nil)
        XCTAssertNil(asset.primaryPlaybackID)
    }

    // MARK: - hlsURL

    func testHlsURLFormattedCorrectly() {
        let asset = makeAsset(playbackIDs: [MuxPlaybackID(id: "pid001", policy: "public")])
        XCTAssertEqual(asset.hlsURL, URL(string: "https://stream.mux.com/pid001.m3u8"))
    }

    func testHlsURLNilWithoutPlaybackID() {
        let asset = makeAsset(playbackIDs: nil)
        XCTAssertNil(asset.hlsURL)
    }

    // MARK: - thumbnailURL

    func testThumbnailURLFormattedCorrectly() {
        let asset = makeAsset(playbackIDs: [MuxPlaybackID(id: "pid001", policy: "public")])
        let url = asset.thumbnailURL
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("image.mux.com"))
        XCTAssertTrue(url!.absoluteString.contains("pid001"))
        XCTAssertTrue(url!.absoluteString.contains("thumbnail.jpg"))
    }

    func testThumbnailURLNilWithoutPlaybackID() {
        let asset = makeAsset(playbackIDs: nil)
        XCTAssertNil(asset.thumbnailURL)
    }

    // MARK: - formattedDuration

    func testFormattedDurationSeconds() {
        let asset = makeAsset(duration: 45.0)
        XCTAssertEqual(asset.formattedDuration, "45 sek")
    }

    func testFormattedDurationMinutes() {
        let asset = makeAsset(duration: 185.0) // 3 min 5 sek
        XCTAssertEqual(asset.formattedDuration, "3 min")
    }

    func testFormattedDurationHours() {
        let asset = makeAsset(duration: 3725.0) // 1h 2m 5s
        XCTAssertEqual(asset.formattedDuration, "1 t 2 min")
    }

    func testFormattedDurationNilDuration() {
        let asset = makeAsset(duration: nil)
        XCTAssertEqual(asset.formattedDuration, "Okänd längd")
    }

    func testFormattedDurationExactlyOneMinute() {
        let asset = makeAsset(duration: 60.0)
        XCTAssertEqual(asset.formattedDuration, "1 min")
    }

    func testFormattedDurationExactlyOneHour() {
        let asset = makeAsset(duration: 3600.0)
        XCTAssertEqual(asset.formattedDuration, "1 t 0 min")
    }

    // MARK: - displayTitle

    func testDisplayTitleFromPassthrough() {
        let passthrough = #"{"title":"Lunas första steg","recordingDate":"2024-03-15T12:00:00Z"}"#
        let asset = makeAsset(id: "testid", passthrough: passthrough)
        XCTAssertEqual(asset.displayTitle, "Lunas första steg")
    }

    func testDisplayTitleFallsBackToIDPrefix() {
        let asset = makeAsset(id: "abcdef1234567890", passthrough: nil)
        XCTAssertEqual(asset.displayTitle, "Video abcdef12")
    }

    func testDisplayTitleFallsBackWhenTitleEmpty() {
        let passthrough = #"{"title":""}"#
        let asset = makeAsset(id: "xyz12345", passthrough: passthrough)
        XCTAssertEqual(asset.displayTitle, "Video xyz12345")
    }

    // MARK: - recordingDate

    func testRecordingDateParsedCorrectly() {
        let passthrough = #"{"recordingDate":"2024-03-15T10:30:00Z"}"#
        let asset = makeAsset(passthrough: passthrough)
        XCTAssertNotNil(asset.recordingDate)

        let cal = Calendar.current
        let comps = cal.dateComponents(
            [.year, .month, .day],
            from: asset.recordingDate!
        )
        XCTAssertEqual(comps.year, 2024)
        XCTAssertEqual(comps.month, 3)
        XCTAssertEqual(comps.day, 15)
    }

    func testRecordingDateNilWithoutPassthrough() {
        let asset = makeAsset(passthrough: nil)
        XCTAssertNil(asset.recordingDate)
    }

    func testRecordingDateNilWithoutRecordingDateField() {
        let passthrough = #"{"title":"Test"}"#
        let asset = makeAsset(passthrough: passthrough)
        XCTAssertNil(asset.recordingDate)
    }

    // MARK: - lunaAgeAtRecording

    func testLunaAgeAtRecordingPresent() {
        // A date after Luna's birthday (2023-07-02)
        let passthrough = #"{"recordingDate":"2024-07-02T12:00:00Z"}"#
        let asset = makeAsset(passthrough: passthrough)
        XCTAssertNotNil(asset.lunaAgeAtRecording)
        XCTAssertTrue(asset.lunaAgeAtRecording!.contains("Luna var"))
    }

    func testLunaAgeAtRecordingNilWhenNoDate() {
        let asset = makeAsset(passthrough: nil)
        XCTAssertNil(asset.lunaAgeAtRecording)
    }

    // MARK: - MuxPassthroughMeta.encode

    func testPassthroughEncodeWithTitleAndDate() {
        let date = ISO8601DateFormatter().date(from: "2024-06-01T00:00:00Z")!
        let encoded = MuxPassthroughMeta.encode(title: "Sommarminnen", recordingDate: date)
        XCTAssertNotNil(encoded)
        XCTAssertTrue(encoded!.contains("Sommarminnen"), "Should contain title")
        XCTAssertTrue(encoded!.contains("2024"), "Should contain year")
    }

    func testPassthroughEncodeNilWhenBothEmpty() {
        let encoded = MuxPassthroughMeta.encode(title: nil, recordingDate: nil)
        XCTAssertNil(encoded, "Should be nil when no data to encode")
    }

    func testPassthroughEncodeNilWhenEmptyTitle() {
        let encoded = MuxPassthroughMeta.encode(title: "", recordingDate: nil)
        XCTAssertNil(encoded, "Empty title with nil date should return nil")
    }

    func testPassthroughEncodeTitleOnly() {
        let encoded = MuxPassthroughMeta.encode(title: "Test video", recordingDate: nil)
        XCTAssertNotNil(encoded)
        XCTAssertTrue(encoded!.contains("Test video"))
    }

    // MARK: - MuxAssetStatus unknown fallback

    func testUnknownStatusFromDecoder() {
        let json = #"{"id":"x","status":"gibberish"}"#
        let asset = try? JSONDecoder().decode(MuxAsset.self, from: json.data(using: .utf8)!)
        XCTAssertNotNil(asset)
        XCTAssertEqual(asset?.status, .unknown)
    }

    // MARK: - fromMuxAsset mapping

    func testFromMuxAssetMapsTitle() {
        let passthrough = #"{"title":"Badbollen","recordingDate":"2024-07-10T10:00:00Z"}"#
        let asset = makeAsset(id: "maptest1", passthrough: passthrough)
        let content = LunaContent.fromMuxAsset(asset)
        XCTAssertEqual(content.title, "Badbollen")
    }

    func testFromMuxAssetSetsIsNewForRecentAsset() {
        // Recording date within last 30 days
        let recent = Date().addingTimeInterval(-5 * 24 * 3600) // 5 days ago
        let iso = ISO8601DateFormatter().string(from: recent)
        let passthrough = "{\"recordingDate\":\"\(iso)\"}"
        let asset = makeAsset(passthrough: passthrough)
        let content = LunaContent.fromMuxAsset(asset)
        XCTAssertTrue(content.isNew, "Content recorded within 30 days should be isNew")
    }

    func testFromMuxAssetNotNewForOldAsset() {
        let old = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-60 * 24 * 3600))
        let passthrough = "{\"recordingDate\":\"\(old)\"}"
        let asset = makeAsset(passthrough: passthrough)
        let content = LunaContent.fromMuxAsset(asset)
        XCTAssertFalse(content.isNew, "Content recorded 60 days ago should not be isNew")
    }

    func testFromMuxAssetFallbackTitleUsesIDPrefix() {
        let asset = makeAsset(id: "abcdef1234", passthrough: nil)
        let content = LunaContent.fromMuxAsset(asset)
        XCTAssertEqual(content.title, "Video abcdef12")
    }

    func testFromMuxAssetTypeIsAlwaysMovie() {
        let asset = makeAsset()
        let content = LunaContent.fromMuxAsset(asset)
        XCTAssertEqual(content.type, .movie)
    }
}
