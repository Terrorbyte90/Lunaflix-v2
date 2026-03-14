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
            // Simulate brief async load
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            heroContents = MockData.heroContent
            categories = MockData.categories
            isLoading = false
        }
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
        // Restart timer so it doesn't immediately jump after manual selection
        startHeroTimer()
    }

    var currentHero: LunaContent? {
        heroContents[safe: currentHeroIndex]
    }

    func refresh() {
        load()
    }
}
