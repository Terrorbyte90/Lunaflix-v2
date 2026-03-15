import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var heroContents: [LunaContent] = []
    @Published var categories: [ContentCategory] = []
    @Published var currentHeroIndex: Int = 0
    @Published var isLoading: Bool = true
    @Published var isConfigured: Bool = false

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
            guard !Task.isCancelled else { return }
            isConfigured = KeychainService.hasMuxCredentials

            guard isConfigured else {
                heroContents = []
                categories = []
                isLoading = false
                return
            }

            do {
                let assets = try await MuxService.shared.listAssets()
                guard !Task.isCancelled else { return }

                let ready = assets
                    .filter { $0.isReady }
                    .sorted { ($0.createdAt ?? 0) > ($1.createdAt ?? 0) }

                let contents = ready.map { LunaContent.fromMuxAsset($0) }

                heroContents = Array(contents.prefix(5))
                categories = buildCategories(from: contents)
                ContentStore.shared.update(contents)
            } catch {
                heroContents = []
                categories = []
            }

            isLoading = false
        }
    }

    private func buildCategories(from contents: [LunaContent]) -> [ContentCategory] {
        guard !contents.isEmpty else { return [] }

        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        let recent = contents.filter { $0.recordingDate.map { $0 > cutoff } ?? false }
        let older  = contents.filter { $0.recordingDate.map { $0 <= cutoff } ?? true }

        var cats: [ContentCategory] = []

        if !recent.isEmpty {
            cats.append(ContentCategory(
                title: "Senaste klippen",
                subtitle: "\(recent.count) videor",
                contents: recent,
                style: .wideCard
            ))
        }
        if !older.isEmpty {
            cats.append(ContentCategory(
                title: older.isEmpty ? "Mitt bibliotek" : "Äldre klipp",
                subtitle: "\(older.count) videor",
                contents: older,
                style: .wideCard
            ))
        }
        if cats.isEmpty {
            cats.append(ContentCategory(
                title: "Mitt bibliotek",
                subtitle: "\(contents.count) videor",
                contents: contents,
                style: .wideCard
            ))
        }

        return cats
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
