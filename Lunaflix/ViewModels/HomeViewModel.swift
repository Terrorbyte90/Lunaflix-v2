import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var heroContents: [LunaContent] = []
    @Published var categories: [ContentCategory] = []
    @Published var currentHeroIndex: Int = 0
    @Published var isLoading: Bool = true

    private var heroTimer: AnyCancellable?
    private var loadTask: Task<Void, Never>? = nil

    init() {
        load()
        startHeroTimer()
    }

    private func load() {
        isLoading = true
        loadTask?.cancel()
        loadTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            heroContents = MockData.heroContent
            var cats = MockData.categories

            // Load Mux assets if credentials are set
            if KeychainService.hasMuxCredentials {
                if let muxCategory = await loadMuxCategory() {
                    cats.insert(muxCategory, at: 0)
                }
            }

            categories = cats
            isLoading = false
        }
    }

    private func loadMuxCategory() async -> ContentCategory? {
        do {
            let assets = try await MuxService.shared.listAssets()
            let readyAssets = assets.filter { $0.isReady }
            guard !readyAssets.isEmpty else { return nil }

            let contents: [LunaContent] = readyAssets.map { asset in
                let recordingDate = asset.recordingDate
                let year = recordingDate.map { Calendar.current.component(.year, from: $0) }
                    ?? Calendar.current.component(.year, from: Date())
                return LunaContent(
                    title: asset.displayTitle,
                    description: asset.lunaAgeAtRecording ?? "Video från Lunas bibliotek.",
                    type: .movie,
                    genre: [.documentary],
                    rating: 0,
                    year: year,
                    duration: asset.formattedDuration,
                    ageRating: .all,
                    thumbnailGradient: thumbnailStyle(for: asset.id),
                    heroGradient: thumbnailStyle(for: asset.id),
                    muxPlaybackID: asset.primaryPlaybackID,
                    recordingDate: recordingDate
                )
            }

            return ContentCategory(
                title: "Mitt bibliotek",
                subtitle: "\(contents.count) videor",
                contents: contents,
                style: .wideCard
            )
        } catch {
            return nil
        }
    }

    private func thumbnailStyle(for id: String) -> ThumbnailStyle {
        let styles: [ThumbnailStyle] = [.purple, .blue, .teal, .rose, .amber, .indigo, .emerald, .crimson, .violet, .ocean]
        let hash = abs(id.hashValue)
        return styles[hash % styles.count]
    }

    private func startHeroTimer() {
        heroTimer?.cancel()
        heroTimer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let next = (self.currentHeroIndex + 1) % max(1, self.heroContents.count)
                withAnimation(.lunaSmooth) {
                    self.currentHeroIndex = next
                }
            }
    }

    func selectHero(_ index: Int) {
        guard index != currentHeroIndex else { return }
        withAnimation(.lunaSnappy) {
            currentHeroIndex = index
        }
        startHeroTimer()
    }

    var currentHero: LunaContent? {
        heroContents[safe: currentHeroIndex]
    }

    func refresh() {
        load()
    }
}
