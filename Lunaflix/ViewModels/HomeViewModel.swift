import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var heroContents: [LunaContent] = []
    @Published var categories: [ContentCategory] = []
    @Published var currentHeroIndex: Int = 0
    @Published var isLoading: Bool = false

    private var heroTimer: AnyCancellable?

    init() {
        load()
        startHeroTimer()
    }

    private func load() {
        isLoading = true
        // Simulate async load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.heroContents = MockData.heroContent
            self.categories = MockData.categories
            self.isLoading = false
        }
    }

    private func startHeroTimer() {
        heroTimer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                withAnimation(.lunaSmooth) {
                    self.currentHeroIndex = (self.currentHeroIndex + 1) % max(1, self.heroContents.count)
                }
            }
    }

    func selectHero(_ index: Int) {
        withAnimation(.lunaSnappy) {
            currentHeroIndex = index
        }
        // Reset timer on manual selection
        heroTimer?.cancel()
        startHeroTimer()
    }

    var currentHero: LunaContent? {
        guard !heroContents.isEmpty else { return nil }
        return heroContents[currentHeroIndex]
    }

    func refresh() {
        load()
    }
}
