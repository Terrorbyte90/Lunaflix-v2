import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [LunaContent] = []
    @Published var selectedGenre: Genre? = nil
    @Published var selectedType: ContentType? = nil
    @Published var isSearching: Bool = false

    private var allContent: [LunaContent] = []
    private var cancellables = Set<AnyCancellable>()

    let allTypes = ContentType.allCases
    // No genres in personal library
    let featuredGenres: [Genre] = []

    var trendingContent: [LunaContent] { Array(allContent.prefix(8)) }
    var hasActiveFilter: Bool { selectedGenre != nil || selectedType != nil }
    var isEmptySearch: Bool { query.isEmpty && !hasActiveFilter }

    init() {
        $query
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in self?.performSearch() }
            .store(in: &cancellables)

        $selectedGenre
            .sink { [weak self] _ in self?.performSearch() }
            .store(in: &cancellables)

        $selectedType
            .sink { [weak self] _ in self?.performSearch() }
            .store(in: &cancellables)

        Task { await loadContent() }
    }

    private func loadContent() async {
        guard KeychainService.hasMuxCredentials else { return }
        do {
            let assets = try await MuxService.shared.listAssets()
            allContent = assets
                .filter { $0.isReady }
                .sorted { ($0.createdAt ?? 0) > ($1.createdAt ?? 0) }
                .map { LunaContent.fromMuxAsset($0) }
            // Re-run any active search with the loaded content
            if !query.isEmpty || hasActiveFilter { performSearch() }
        } catch {}
    }

    func performSearch() {
        var pool = allContent

        if let type = selectedType {
            pool = pool.filter { $0.type == type }
        }
        if !query.isEmpty {
            let q = query.lowercased()
            pool = pool.filter {
                $0.title.lowercased().contains(q) ||
                $0.description.lowercased().contains(q)
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

    func refresh() async {
        await loadContent()
    }
}
