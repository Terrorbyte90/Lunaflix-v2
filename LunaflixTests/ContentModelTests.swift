import XCTest
@testable import Lunaflix

// MARK: - Content Model Tests

final class ContentModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeContent(
        title: String = "Test",
        genre: [Genre] = [.action, .drama],
        rating: Double = 7.5,
        year: Int = 2024,
        ageRating: AgeRating = .teen,
        recordingDate: Date? = nil
    ) -> LunaContent {
        LunaContent(
            title: title,
            description: "Test description",
            type: .movie,
            genre: genre,
            rating: rating,
            year: year,
            duration: "1 t 30 min",
            ageRating: ageRating,
            thumbnailGradient: .purple,
            recordingDate: recordingDate
        )
    }

    // MARK: - formattedRating

    func testFormattedRatingOneDecimal() {
        let c = makeContent(rating: 8.5)
        XCTAssertEqual(c.formattedRating, "8.5")
    }

    func testFormattedRatingZero() {
        let c = makeContent(rating: 0)
        XCTAssertEqual(c.formattedRating, "0.0")
    }

    func testFormattedRatingRoundsCorrectly() {
        // %.1f rounds 9.99 to "10.0" by standard IEEE 754 half-round-up rules
        let c = makeContent(rating: 9.99)
        XCTAssertEqual(c.formattedRating, "10.0")
    }

    // MARK: - genreString

    func testGenreStringTwoGenres() {
        let c = makeContent(genre: [.action, .drama])
        XCTAssertEqual(c.genreString, "Action • Drama")
    }

    func testGenreStringOnlyFirstTwo() {
        let c = makeContent(genre: [.action, .drama, .comedy])
        // Should only show first 2
        XCTAssertEqual(c.genreString, "Action • Drama")
    }

    func testGenreStringEmpty() {
        let c = makeContent(genre: [])
        XCTAssertEqual(c.genreString, "")
    }

    func testGenreStringSingleGenre() {
        let c = makeContent(genre: [.scifi])
        XCTAssertEqual(c.genreString, "Sci-Fi")
    }

    // MARK: - metaString

    func testMetaStringFormat() {
        let c = makeContent(year: 2023, ageRating: .all)
        let meta = c.metaString
        XCTAssertTrue(meta.contains("2023"), "Should contain year")
        XCTAssertTrue(meta.contains("Alla åldrar"), "Should contain age rating label")
    }

    func testMetaStringContainsDuration() {
        let c = makeContent()
        XCTAssertTrue(c.metaString.contains("1 t 30 min"))
    }

    // MARK: - AgeRating

    func testAgeRatingLabels() {
        XCTAssertEqual(AgeRating.all.label, "Alla åldrar")
        XCTAssertEqual(AgeRating.child.label, "7+")
        XCTAssertEqual(AgeRating.teen.label, "13+")
        XCTAssertEqual(AgeRating.mature.label, "16+")
        XCTAssertEqual(AgeRating.adult.label, "18+")
    }

    // MARK: - ContentType

    func testContentTypeAllCasesExist() {
        let cases = ContentType.allCases
        XCTAssertTrue(cases.contains(.movie))
        XCTAssertTrue(cases.contains(.series))
        XCTAssertTrue(cases.contains(.documentary))
        XCTAssertTrue(cases.contains(.short))
    }

    func testContentTypeDisplayNames() {
        XCTAssertEqual(ContentType.movie.rawValue, "Film")
        XCTAssertEqual(ContentType.series.rawValue, "Serie")
        XCTAssertEqual(ContentType.documentary.rawValue, "Dokumentär")
        XCTAssertEqual(ContentType.short.rawValue, "Kortfilm")
    }

    func testContentTypeIcons() {
        // Icons should be non-empty strings
        for type in ContentType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "Icon for \(type) should not be empty")
        }
    }

    // MARK: - Genre

    func testGenreDisplayNames() {
        XCTAssertEqual(Genre.action.displayName, "Action")
        XCTAssertEqual(Genre.adventure.displayName, "Äventyr")
        XCTAssertEqual(Genre.animation.displayName, "Animation")
        XCTAssertEqual(Genre.comedy.displayName, "Komedi")
        XCTAssertEqual(Genre.scifi.displayName, "Sci-Fi")
    }

    func testGenreAllCasesHaveDisplayNames() {
        for genre in Genre.allCases {
            XCTAssertFalse(genre.displayName.isEmpty, "Genre \(genre) should have non-empty display name")
        }
    }

    // MARK: - ThumbnailStyle

    func testThumbnailStyleAllCasesDecodable() {
        let styles: [ThumbnailStyle] = [.purple, .blue, .teal, .rose, .amber, .indigo, .emerald, .crimson, .violet, .ocean]
        for style in styles {
            let encoded = try? JSONEncoder().encode(style)
            XCTAssertNotNil(encoded, "\(style) should be encodable")
            let decoded = try? JSONDecoder().decode(ThumbnailStyle.self, from: encoded!)
            XCTAssertEqual(decoded, style, "\(style) should round-trip through Codable")
        }
    }

    // MARK: - LunaContent equality and hashing

    func testEqualityBasedOnID() {
        let id = UUID()
        let c1 = LunaContent(id: id, title: "A", description: "", type: .movie, genre: [], rating: 0, year: 2024, duration: "", thumbnailGradient: .blue)
        let c2 = LunaContent(id: id, title: "B", description: "", type: .series, genre: [], rating: 9, year: 2023, duration: "", thumbnailGradient: .rose)
        XCTAssertEqual(c1, c2, "Two LunaContent with same ID should be equal regardless of other fields")
    }

    func testInequalityWithDifferentIDs() {
        let c1 = LunaContent(title: "A", description: "", type: .movie, genre: [], rating: 0, year: 2024, duration: "", thumbnailGradient: .blue)
        let c2 = LunaContent(title: "A", description: "", type: .movie, genre: [], rating: 0, year: 2024, duration: "", thumbnailGradient: .blue)
        XCTAssertNotEqual(c1, c2, "Two LunaContent with different UUIDs should not be equal")
    }

    // MARK: - ContentCategory

    func testContentCategoryDefaultStyle() {
        let cat = ContentCategory(title: "Test", contents: [])
        XCTAssertEqual(cat.style, .standard)
    }

    func testContentCategoryID() {
        let id = UUID()
        let cat = ContentCategory(id: id, title: "Test", contents: [])
        XCTAssertEqual(cat.id, id)
    }

    func testContentCategoryWithSubtitle() {
        let cat = ContentCategory(title: "2024", subtitle: "12 videor", contents: [])
        XCTAssertEqual(cat.subtitle, "12 videor")
    }

    // MARK: - Tab

    func testTabTitles() {
        XCTAssertEqual(Tab.home.title, "Hem")
        XCTAssertEqual(Tab.search.title, "Sök")
        XCTAssertEqual(Tab.downloads.title, "Laddat")
        XCTAssertEqual(Tab.profile.title, "Profil")
    }

    func testTabIcons() {
        for tab in Tab.allCases {
            XCTAssertFalse(tab.icon.isEmpty, "Tab \(tab) should have non-empty icon")
        }
    }

    func testTabAllCasesCount() {
        XCTAssertEqual(Tab.allCases.count, 4)
    }

    // MARK: - Episode

    func testEpisodeDefaultValues() {
        let ep = Episode(title: "Piloten", episodeNumber: 1, thumbnailStyle: .teal)
        XCTAssertEqual(ep.seasonNumber, 1)
        XCTAssertEqual(ep.duration, "45 min")
        XCTAssertEqual(ep.progress, 0)
        XCTAssertEqual(ep.description, "")
    }

    // MARK: - MuxError

    func testMuxErrorDescriptions() {
        XCTAssertNotNil(MuxError.missingCredentials.errorDescription)
        XCTAssertNotNil(MuxError.unauthorized.errorDescription)
        XCTAssertNotNil(MuxError.invalidResponse.errorDescription)
        XCTAssertNotNil(MuxError.notFound.errorDescription)
        XCTAssertNotNil(MuxError.serverError(500).errorDescription)
        XCTAssertNotNil(MuxError.uploadFailed.errorDescription)
        XCTAssertNotNil(MuxError.assetProcessingFailed.errorDescription)
        XCTAssertNotNil(MuxError.assetPollingTimeout.errorDescription)
    }

    func testMuxErrorServerCodeIncluded() {
        let desc = MuxError.serverError(422).errorDescription
        XCTAssertTrue(desc?.contains("422") ?? false)
    }
}
