import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [LunaContent] = []
    @Published var isSearching: Bool = false

    private var allContent: [LunaContent] = []
    private var cancellables = Set<AnyCancellable>()

    // No genres or content-type filtering — this is a personal video library
    let featuredGenres: [Genre] = []
    var selectedGenre: Genre? = nil

    var trendingContent: [LunaContent] { Array(allContent.prefix(8)) }
    var hasActiveFilter: Bool { false }
    var isEmptySearch: Bool { query.isEmpty }

    init() {
        $query
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .removeDuplicates()
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
            if !query.isEmpty { performSearch() }
        } catch {}
    }

    func performSearch() {
        guard !query.isEmpty else {
            withAnimation(.lunaSnappy) { results = [] }
            return
        }
        let q = query.lowercased()
        let pool = allContent.filter {
            $0.title.lowercased().contains(q) ||
            $0.description.lowercased().contains(q)
        }
        withAnimation(.lunaSnappy) { results = pool }
    }

    func clearFilters() {
        withAnimation(.lunaSnappy) {
            query = ""
            results = []
        }
    }

    func refresh() async {
        await loadContent()
    }
}
