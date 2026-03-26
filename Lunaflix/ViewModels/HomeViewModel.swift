import SwiftUI
import Combine
import Kingfisher

@Observable
@MainActor
final class HomeViewModel {
    var heroContents: [LunaContent] = []
    var categories: [ContentCategory] = []
    var currentHeroIndex: Int = 0
    var isLoading: Bool = true
    var isConfigured: Bool = false

    private var heroTimer: AnyCancellable?
    private var uploadRefreshObserver: AnyCancellable?
    private var loadTask: Task<Void, Never>? = nil
    private var refreshTask: Task<Void, Never>? = nil
    private var imagePrefetcher: ImagePrefetcher?

    init() {
        load()
        startHeroTimer()
        observeUploadCompletions()
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

                // Prefetch first 50 thumbnails (hero + first visible rows)
                let visibleURLs = contents.prefix(50).compactMap { content -> URL? in
                    guard let pid = content.muxPlaybackID else { return nil }
                    return URL(string: "https://image.mux.com/\(pid)/thumbnail.jpg?width=400&height=225&fit_mode=smartcrop&time=2")
                }
                imagePrefetcher = ImagePrefetcher(urls: Array(visibleURLs))
                imagePrefetcher?.start()
            } catch {
                heroContents = []
                categories = []
            }

            isLoading = false
        }
    }

    // Called after an upload completes so the new asset appears immediately
    func refreshAfterUpload() {
        // Short delay lets Mux finish the final processing step
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            load()
        }
    }

    private func observeUploadCompletions() {
        uploadRefreshObserver = NotificationCenter.default
            .publisher(for: .lunaflixUploadDidComplete)
            .sink { [weak self] _ in
                self?.refreshAfterUpload()
            }
    }

    private func buildCategories(from contents: [LunaContent]) -> [ContentCategory] {
        guard !contents.isEmpty else { return [] }

        let calendar = Calendar.current
        let cutoff30 = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        // "Senaste 30 dagarna" row first
        let recent = contents.filter { $0.recordingDate.map { $0 > cutoff30 } ?? false }

        // Group all content by year for yearly browsing
        var byYear: [Int: [LunaContent]] = [:]
        for item in contents {
            let year = item.recordingDate.map { calendar.component(.year, from: $0) } ?? item.year
            byYear[year, default: []].append(item)
        }

        var cats: [ContentCategory] = []

        // Recent first
        if !recent.isEmpty {
            cats.append(ContentCategory(
                title: "Senaste 30 dagarna",
                subtitle: "\(recent.count) videor",
                contents: recent,
                style: .wideCard
            ))
        }

        // Then yearly rows newest first
        let sortedYears = byYear.keys.sorted(by: >)
        for year in sortedYears {
            guard let rawContents = byYear[year] else { continue }
            let yearContents = rawContents.sorted { ($0.recordingDate ?? Date.distantPast) > ($1.recordingDate ?? Date.distantPast) }
            let lunaAge = lunaAgeForYear(year)
            let subtitle = lunaAge.map { "\($0) • \(yearContents.count) videor" } ?? "\(yearContents.count) videor"
            cats.append(ContentCategory(
                title: "\(year)",
                subtitle: subtitle,
                contents: yearContents,
                style: .wideCard
            ))
        }

        return cats
    }

    private func lunaAgeForYear(_ year: Int) -> String? {
        // Show what age Luna was approximately mid-year
        var comps = DateComponents()
        comps.year = year; comps.month = 7; comps.day = 1
        guard let midYear = Calendar.current.date(from: comps) else { return nil }
        guard midYear > LunaAge.birthday else { return nil }
        return LunaAge.ageShort(at: midYear)
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
