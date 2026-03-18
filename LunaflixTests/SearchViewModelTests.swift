import XCTest
@testable import Lunaflix

// MARK: - SearchViewModel Unit Tests
//
// Strategi: SearchViewModel.loadContent() hämtar först från ContentStore (om icke-tom)
// via ett asynkront Task i init. Testerna seedar ContentStore, skapar ViewModel
// och väntar på att Task ska köra klart via Task.yield() + kort paus,
// sedan anropas performSearch() direkt.
//
// Tester för det rena filtreringslogiken undviker asynkrona problem genom att
// anropa performSearch() manuellt efter att allContent fyllts via ett expose.

@MainActor
final class SearchViewModelTests: XCTestCase {

    var sut: SearchViewModel!

    override func setUp() {
        super.setUp()
        ContentStore.shared.update([])
    }

    override func tearDown() {
        sut = nil
        ContentStore.shared.update([])
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeContent(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        type: ContentType = .movie,
        recordingDate: Date? = nil
    ) -> LunaContent {
        LunaContent(
            id: id,
            title: title,
            description: description,
            type: type,
            genre: [],
            rating: 0,
            year: 2024,
            duration: "5 min",
            thumbnailGradient: .purple,
            recordingDate: recordingDate
        )
    }

    /// Seeds ContentStore and creates a new SearchViewModel, then waits for
    /// the async init Task to pick up the seeded content.
    private func makeViewModelWithContent(_ items: [LunaContent]) async -> SearchViewModel {
        ContentStore.shared.update(items)
        let vm = SearchViewModel()
        // Yield control so the init Task runs its loadContent()
        await Task.yield()
        // Give a tiny extra moment for the publish to propagate
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        return vm
    }

    // MARK: - Initial state

    func testInitialStateQuery() {
        sut = SearchViewModel()
        XCTAssertEqual(sut.query, "")
    }

    func testInitialStateNoGenre() {
        sut = SearchViewModel()
        XCTAssertNil(sut.selectedGenre)
    }

    func testInitialStateNoType() {
        sut = SearchViewModel()
        XCTAssertNil(sut.selectedType)
    }

    func testInitialStateResultsEmpty() {
        sut = SearchViewModel()
        XCTAssertTrue(sut.results.isEmpty)
    }

    func testIsEmptySearchTrueWhenNoQueryAndNoFilter() {
        sut = SearchViewModel()
        sut.query = ""
        sut.selectedGenre = nil
        sut.selectedType = nil
        XCTAssertTrue(sut.isEmptySearch)
    }

    func testIsEmptySearchFalseWhenQueryPresent() {
        sut = SearchViewModel()
        sut.query = "luna"
        XCTAssertFalse(sut.isEmptySearch)
    }

    func testIsEmptySearchFalseWhenTypeFilterSet() {
        sut = SearchViewModel()
        sut.selectedType = .movie
        XCTAssertFalse(sut.isEmptySearch)
    }

    func testHasActiveFilterFalseInitially() {
        sut = SearchViewModel()
        XCTAssertFalse(sut.hasActiveFilter)
    }

    func testHasActiveFilterTrueWithType() {
        sut = SearchViewModel()
        sut.selectedType = .movie
        XCTAssertTrue(sut.hasActiveFilter)
    }

    func testHasActiveFilterTrueWithGenre() {
        sut = SearchViewModel()
        sut.selectedGenre = .action
        XCTAssertTrue(sut.hasActiveFilter)
    }

    // MARK: - allTypes

    func testAllTypesContainsAllCases() {
        sut = SearchViewModel()
        XCTAssertEqual(sut.allTypes.count, ContentType.allCases.count)
        for type in ContentType.allCases {
            XCTAssertTrue(sut.allTypes.contains(type))
        }
    }

    // MARK: - featuredGenres

    func testFeaturedGenresIsEmptyForPersonalLibrary() {
        sut = SearchViewModel()
        XCTAssertTrue(sut.featuredGenres.isEmpty, "Personal library har ingen genretaxonomi")
    }

    // MARK: - performSearch with async content loading

    func testSearchByTitleCaseInsensitive() async {
        let content = [
            makeContent(title: "Lunas Sommar"),
            makeContent(title: "Vinterminnena")
        ]
        sut = await makeViewModelWithContent(content)

        sut.query = "luna"
        sut.performSearch()

        XCTAssertEqual(sut.results.count, 1, "Ska hitta 1 match för 'luna'")
        XCTAssertEqual(sut.results.first?.title, "Lunas Sommar")
    }

    func testSearchByDescription() async {
        let content = [makeContent(title: "Video", description: "badturen 2024")]
        sut = await makeViewModelWithContent(content)

        sut.query = "badturen"
        sut.performSearch()

        XCTAssertEqual(sut.results.count, 1, "Ska hitta match i beskrivning")
    }

    func testSearchNoResultsForMismatch() async {
        let content = [makeContent(title: "Lunas Sommar")]
        sut = await makeViewModelWithContent(content)

        sut.query = "xyzabc"
        sut.performSearch()

        XCTAssertTrue(sut.results.isEmpty, "Inget ska matcha 'xyzabc'")
    }

    func testSearchEmptyQueryReturnsAll() async {
        let content = [
            makeContent(title: "A"),
            makeContent(title: "B"),
            makeContent(title: "C")
        ]
        sut = await makeViewModelWithContent(content)

        sut.query = ""
        sut.selectedType = nil
        sut.selectedGenre = nil
        sut.performSearch()

        XCTAssertEqual(sut.results.count, content.count, "Tom sökning ska returnera allt")
    }

    // MARK: - Type filter

    func testTypeFilterReducesResults() async {
        let content = [
            makeContent(title: "Film", type: .movie),
            makeContent(title: "Serie", type: .series),
            makeContent(title: "Kortfilm", type: .short)
        ]
        sut = await makeViewModelWithContent(content)

        sut.selectedType = .movie
        sut.performSearch()

        XCTAssertEqual(sut.results.count, 1, "Ska bara visa filmer")
        XCTAssertEqual(sut.results.first?.type, .movie)
    }

    func testTypeFilterCombinedWithQuery() async {
        let content = [
            makeContent(title: "Luna film", type: .movie),
            makeContent(title: "Luna serie", type: .series)
        ]
        sut = await makeViewModelWithContent(content)

        sut.selectedType = .movie
        sut.query = "luna"
        sut.performSearch()

        XCTAssertEqual(sut.results.count, 1, "Typ+titel-filter ska ge 1 träff")
        XCTAssertEqual(sut.results.first?.title, "Luna film")
    }

    // MARK: - Luna age search

    func testSearchByLunaAgeLabel() async {
        // Recording date: 2024-07-02 = Luna's 1-year birthday — gives "1 år" in age label
        var comps = DateComponents()
        comps.year = 2024; comps.month = 7; comps.day = 3 // 1 day after 1-year birthday -> "1 år 1 dag"
        let recordingDate = Calendar.current.date(from: comps)!

        let content = [makeContent(title: "SommarVideo", recordingDate: recordingDate)]
        sut = await makeViewModelWithContent(content)

        sut.query = "1 år"
        sut.performSearch()

        XCTAssertEqual(sut.results.count, 1, "Ska hitta video via Lunas ålderetikett '1 år'")
    }

    // MARK: - clearFilters

    func testClearFiltersResetsAll() {
        sut = SearchViewModel()
        sut.query = "test"
        sut.selectedType = .movie
        sut.selectedGenre = .drama

        sut.clearFilters()

        XCTAssertEqual(sut.query, "")
        XCTAssertNil(sut.selectedType)
        XCTAssertNil(sut.selectedGenre)
        XCTAssertTrue(sut.results.isEmpty)
    }

    // MARK: - trendingContent

    func testTrendingContentIsCappedAt8() async {
        let content = (0..<20).map { i in makeContent(title: "Video \(i)") }
        sut = await makeViewModelWithContent(content)
        XCTAssertLessThanOrEqual(sut.trendingContent.count, 8)
    }

    func testTrendingContentIsEmptyWhenNoContent() {
        ContentStore.shared.update([])
        sut = SearchViewModel()
        XCTAssertTrue(sut.trendingContent.isEmpty)
    }
}
