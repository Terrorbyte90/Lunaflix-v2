import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [LunaContent] = []
    @Published var selectedGenre: Genre? = nil
    @Published var selectedType: ContentType? = nil
    @Published var isSearching: Bool = false

    private var cancellables = Set<AnyCancellable>()

    let allGenres = Genre.allCases
    let allTypes = ContentType.allCases

    init() {
        $query
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.performSearch()
            }
            .store(in: &cancellables)

        $selectedGenre
            .sink { [weak self] _ in self?.performSearch() }
            .store(in: &cancellables)

        $selectedType
            .sink { [weak self] _ in self?.performSearch() }
            .store(in: &cancellables)
    }

    var trendingContent: [LunaContent] { MockData.allContent.filter(\.isTrending) }
    var featuredGenres: [Genre] { [.action, .comedy, .drama, .scifi, .horror, .thriller, .animation, .crime] }

    var hasActiveFilter: Bool { selectedGenre != nil || selectedType != nil }
    var isEmptySearch: Bool { query.isEmpty && !hasActiveFilter }

    func performSearch() {
        var pool = MockData.allContent

        if let genre = selectedGenre {
            pool = pool.filter { $0.genre.contains(genre) }
        }
        if let type = selectedType {
            pool = pool.filter { $0.type == type }
        }
        if !query.isEmpty {
            let q = query.lowercased()
            pool = pool.filter {
                $0.title.lowercased().contains(q) ||
                $0.description.lowercased().contains(q) ||
                $0.genre.map(\.displayName).joined().lowercased().contains(q)
            }
        }

        withAnimation(.lunaSnappy) {
            results = pool
        }
    }

    func clearFilters() {
        withAnimation(.lunaSnappy) {
            query = ""
            selectedGenre = nil
            selectedType = nil
            results = []
        }
    }

    func contentByGenre(_ genre: Genre) -> [LunaContent] {
        MockData.allContent.filter { $0.genre.contains(genre) }
    }
}
