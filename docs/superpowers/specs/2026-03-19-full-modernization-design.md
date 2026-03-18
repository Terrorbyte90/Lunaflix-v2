# Lunaflix Full Modernization Design
**Date:** 2026-03-19
**Status:** Approved

## Context
Private family iOS video app for Ted and his daughter Luna. 500–1000 short videos (mostly <5 min) served via Mux CDN. Key problems: startup buffering lag, no lock screen/headphone controls, thumbnails re-download on every render, Mux API only fetches 100 of 1000+ assets.

---

## Prerequisite Step (before parallel agents begin)

Add two Swift packages in Xcode:
1. **Kingfisher**: `https://github.com/onevcat/Kingfisher` — up to next major from 8.x
2. **Mux Data SDK**: `https://github.com/muxinc/mux-stats-sdk-avplayer.git` — up to next major from 4.0.0

Both are needed by Spår 2, 3, and 4. No code changes yet — just add to Package.resolved.

---

## Spår 1 — Network & Mux-layer

**Files:** `MuxService.swift`, `Content.swift`, `ContentDetailView.swift`

### Step 1 (prerequisite within Spår 1): Add assetId to LunaContent

In `Content.swift`, add `let assetId: String?` to the `LunaContent` struct and its `init`. In `LunaContent.fromMuxAsset(_:)`, set `assetId: asset.id`. `DownloadItem.toLunaContent()` passes `assetId: nil`.

This must land before step 4 below — both are in the same Spår 1 agent so ordering is guaranteed.

### Step 2: Pagination in MuxService.listAssets()

Existing public signature `func listAssets() async throws -> [MuxAsset]` stays unchanged.

Extract single-page fetch into a private helper:
```swift
private func fetchAssetsPage(page: Int, limit: Int) async throws -> [MuxAsset] {
    let url = URL(string: "\(baseURL)/video/v1/assets?limit=\(limit)&page=\(page)&order_direction=desc")!
    let data = try await performRequest(url: url, method: "GET", body: nil)
    let response = try JSONDecoder().decode(MuxListResponse.self, from: data)
    return response.data
}
```

Replace `listAssets()` body with:
```swift
var all: [MuxAsset] = []
var page = 1
let limit = 100
let maxPages = 20
var batch: [MuxAsset]
repeat {
    batch = try await fetchAssetsPage(page: page, limit: limit)
    all.append(contentsOf: batch)
    page += 1
} while batch.count == limit && page <= maxPages
return all
```

`testConnection()` builds its own URL with `?limit=1` and is not affected.

### Step 3: Retry helper

Add a private free function at the top of `MuxService.swift`:
```swift
private func withRetry<T>(maxAttempts: Int = 3, baseDelay: Double = 0.5, _ operation: () async throws -> T) async throws -> T {
    var attempt = 0
    while true {
        do {
            return try await operation()
        } catch let error as URLError {
            attempt += 1
            if attempt >= maxAttempts { throw error }
            let delay = baseDelay * pow(2.0, Double(attempt - 1))
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        } catch let error as MuxError {
            if case .httpError(let code, _) = error, code >= 500 {
                attempt += 1
                if attempt >= maxAttempts { throw error }
                let delay = baseDelay * pow(2.0, Double(attempt - 1))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } else {
                throw error  // 4xx: re-throw immediately
            }
        }
    }
}
```

Apply retry **per page call** (not around the outer loop):
- Wrap `fetchAssetsPage` call with `try await withRetry { try await self.fetchAssetsPage(page: page, limit: limit) }`
- Wrap `createDirectUpload` body with `try await withRetry { ... }`

Do NOT wrap the outer pagination loop.

### Step 4: Use existing MuxService methods for direct asset access

`MuxService` already has `updateAssetPassthrough(id:title:recordingDate:)` (line ~135) and `deleteAsset(id:)` (line ~149). Do NOT add duplicate methods.

In `ContentDetailView.saveTitle()`: replace the `listAssets()` lookup pattern with a direct call to the existing `muxService.updateAssetPassthrough(id: content.assetId!, title: newTitle, recordingDate: existingDate)`. Add guard: `guard let assetId = content.assetId else { showError("Missing asset ID"); return }`.

In `ContentDetailView.deleteVideo()`: replace the `listAssets()` lookup with `try await muxService.deleteAsset(id: content.assetId!)`. Same guard.

---

## Spår 2 — Player & Playback

**Files:** `ContentDetailView.swift` (preload section only), `PlayerView.swift` (PlayerViewModel)

### Step 1: Pre-load AVURLAsset on detail sheet open

`ContentDetailView.swift` — add:
```swift
@State private var preloadedAsset: AVURLAsset? = nil
```
In the view body, add a `.task` modifier (or `.onAppear`):
```swift
.task {
    // .task runs in @MainActor context of the view — safe for @State assignment
    let options = [AVURLAssetPreferPreciseDurationAndTimingKey: true] as [String: Any]
    guard let url = content.hlsURL else { return }
    let asset = AVURLAsset(url: url, options: options)
    _ = try? await asset.load(.isPlayable)   // warms up HLS manifest fetch
    preloadedAsset = asset
}
```
Pass to PlayerView: `.fullScreenCover { PlayerView(content: allContent, startIndex: idx, preloadedAsset: preloadedAsset) }`

`PlayerView.swift` — add `var preloadedAsset: AVURLAsset? = nil` to `PlayerView`.
Change `@StateObject private var viewModel` to use explicit init accepting the asset:
```swift
@StateObject private var viewModel: PlayerViewModel
init(content: [LunaContent], startIndex: Int, preloadedAsset: AVURLAsset? = nil) {
    _viewModel = StateObject(wrappedValue: PlayerViewModel(content: content, startIndex: startIndex, preloadedAsset: preloadedAsset))
}
```

`PlayerViewModel` — add matching init param `preloadedAsset: AVURLAsset? = nil`, store as `private var preloadedAsset: AVURLAsset?`.

In `makePlayerItem(for content: LunaContent, atIndex i: Int)` (or equivalent), when `i == startIndex` and `preloadedAsset != nil`, use `AVPlayerItem(asset: preloadedAsset!)` instead of `AVPlayerItem(url: hlsURL)`. All other items use `AVPlayerItem(url:)` as before.

### Step 2: preferredMaximumResolution

In `makePlayerItem`, after creating the AVPlayerItem:
```swift
// UIScreen.main is acceptable on this iOS 17 deployment target (deprecated warning, not error)
let screenSize = UIScreen.main.bounds.size
let scale = UIScreen.main.scale
item.preferredMaximumResolution = CGSize(
    width: screenSize.width * scale,
    height: screenSize.height * scale
)
```

### Step 3: externalMetadata

In `makePlayerItem`, synchronously set title:
```swift
import MediaPlayer  // add to top of file

let titleItem = AVMutableMetadataItem()
titleItem.identifier = .commonIdentifierTitle
titleItem.value = content.title as NSString
item.externalMetadata = [titleItem]
```

After creating the item, kick off artwork asynchronously (non-blocking):
```swift
let capturedItem = item
Task.detached {
    guard let url = content.thumbnailURL else { return }
    if let result = try? await KingfisherManager.shared.retrieveImage(with: ImageResource(downloadURL: url)) {
        let artItem = AVMutableMetadataItem()
        artItem.identifier = .commonIdentifierArtwork
        artItem.value = result.image.pngData() as NSData?
        await MainActor.run {
            capturedItem.externalMetadata += [artItem]
        }
    }
}
```

### Step 4: MPNowPlayingInfoCenter

Add to `PlayerViewModel`:
```swift
import MediaPlayer

private func updateNowPlaying() {
    var info: [String: Any] = [:]
    info[MPMediaItemPropertyTitle] = currentContent?.title ?? ""
    info[MPMediaItemPropertyPlaybackDuration] = duration
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
    info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    if let url = currentContent?.thumbnailURL,
       let cached = KingfisherManager.shared.cache.retrieveImageInMemoryCache(
           forKey: url.absoluteString) {
        info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: cached.size) { _ in cached }
    }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
}
```

Call `updateNowPlaying()` from:
- End of `attachObservers()` (initial population)
- Periodic time observer (gate: `if Int(time.seconds) % 5 == 0`)
- `togglePlayback()` after play/pause state change
- `handleItemEnded()` after advancing content reference

In `tearDown()`: `MPNowPlayingInfoCenter.default().nowPlayingInfo = nil`

### Step 5: MPRemoteCommandCenter

Add `private var remoteCommandsRegistered = false` to `PlayerViewModel`.

Add `private func setupRemoteCommands()` and call it in the `PlayerViewModel` **init** (not in `buildQueue`), guarded:
```swift
private func setupRemoteCommands() {
    guard !remoteCommandsRegistered else { return }
    remoteCommandsRegistered = true
    let center = MPRemoteCommandCenter.shared()
    center.playCommand.addTarget { [weak self] _ in self?.player.play(); return .success }
    center.pauseCommand.addTarget { [weak self] _ in self?.player.pause(); return .success }
    center.skipForwardCommand.preferredIntervals = [10]
    center.skipForwardCommand.addTarget { [weak self] _ in self?.seek(by: 10); return .success }
    center.skipBackwardCommand.preferredIntervals = [10]
    center.skipBackwardCommand.addTarget { [weak self] _ in self?.seek(by: -10); return .success }
    center.changePlaybackPositionCommand.addTarget { [weak self] event in
        guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
        self?.seekToAbsoluteTime(e.positionTime)
        return .success
    }
}

private func seekToAbsoluteTime(_ seconds: Double) {
    let time = CMTime(seconds: seconds, preferredTimescale: 600)
    player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
}
```

In `tearDown()`, remove all targets:
```swift
let center = MPRemoteCommandCenter.shared()
[center.playCommand, center.pauseCommand, center.skipForwardCommand,
 center.skipBackwardCommand, center.changePlaybackPositionCommand].forEach { $0.removeTarget(nil) }
remoteCommandsRegistered = false
```

---

## Spår 3 — Caching & State
**Merges after Spår 2** (reason: PlayerViewModel in PlayerView.swift is restructured by Spår 2; Spår 3's ResumeStore additions are additive and must not conflict)

**Files:** `AppTheme.swift`, `HeroCarouselView.swift`, `LunaflixApp.swift`, `HomeViewModel.swift`, `HomeView.swift`, `ProfileViewModel.swift`, `ContentView.swift`, new `Lunaflix/Services/ResumeStore.swift`, `PlayerView.swift` (PlayerViewModel — additive ResumeStore calls only)

### Step 1: Kingfisher image rendering

`AppTheme.swift` — in `MuxThumbnailImage`, replace `AsyncImage(url:) { ... }` with:
```swift
KFImage(thumbnailURL)
    .placeholder { /* existing fallback gradient */ }
    .fade(duration: 0.2)
    .resizable()
    .aspectRatio(contentMode: .fill)
```

`HeroCarouselView.swift` — in `HeroCard`, same replacement for any `AsyncImage` blocks.

`LunaflixApp.swift` — in the `App` body or `init`:
```swift
KingfisherManager.shared.cache.diskStorage.config.sizeLimit = 200 * 1024 * 1024
KingfisherManager.shared.cache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024
```

### Step 2: ImagePrefetcher

`HomeViewModel.swift` — at the end of `loadContent()`, after `ContentStore.shared.update(allContent)`:
```swift
let allURLs = allContent.compactMap { $0.thumbnailURL }
ImagePrefetcher(urls: allURLs).start()
```

### Step 3: @Observable migration

**HomeViewModel.swift:**
- Replace `class HomeViewModel: ObservableObject` with `@Observable class HomeViewModel`
- Remove `@Published` from all 5 published properties: `heroContents`, `categories`, `currentHeroIndex`, `isLoading`, `isConfigured`
- Keep `import Combine` and `heroTimer: AnyCancellable?` — `AnyCancellable` is valid inside `@Observable`

**HomeView.swift:**
- Replace `@StateObject private var viewModel = HomeViewModel()` with `@State private var viewModel = HomeViewModel()`

**ProfileViewModel.swift:**
- Replace `class ProfileViewModel: ObservableObject` with `@Observable class ProfileViewModel`
- Remove all `@Published` wrappers; plain stored properties retain `didSet` observers unchanged

**SearchViewModel.swift** — **no change**. It uses `$query.debounce(...).sink(...)` Combine pipelines that require `@Published`.

**ContentView.swift** — update any `@ObservedObject` or `@StateObject` references to `HomeViewModel` or `ProfileViewModel` to use `@State` / plain `var` as appropriate.

### Step 4: ResumeStore

New file `Lunaflix/Services/ResumeStore.swift`:
```swift
struct ResumeStore {
    static let shared = ResumeStore()
    private let defaults = UserDefaults.standard
    private let keyPrefix = "lunaflix.resume."

    func save(playbackID: String, position: Double) {
        defaults.set(position, forKey: keyPrefix + playbackID)
    }

    /// Returns nil if position <= 5s (not worth resuming)
    func position(for playbackID: String) -> Double? {
        let v = defaults.double(forKey: keyPrefix + playbackID)
        return v > 5 ? v : nil
    }

    func clear(playbackID: String) {
        defaults.removeObject(forKey: keyPrefix + playbackID)
    }
}
```

**PlayerViewModel additions (additive — no conflict with Spår 2):**

*Restore on setup* — in the `timeControlStatus` KVO handler, when status becomes `.readyToPlay` and this is the first readyToPlay for the session:
```swift
if !hasRestoredPosition, let playbackID = currentContent?.muxPlaybackID,
   let savedPos = ResumeStore.shared.position(for: playbackID) {
    let dur = player.currentItem?.duration.seconds ?? 0
    if dur.isNaN || savedPos < dur * 0.95 {
        let time = CMTime(seconds: savedPos, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    hasRestoredPosition = true
}
```
Add `private var hasRestoredPosition = false` to PlayerViewModel.

*Periodic save* — in `attachObservers()`, inside the existing periodic time observer closure:
```swift
// resumeSaveCounter is a captured local var in the closure
resumeSaveCounter += 1
if resumeSaveCounter % 40 == 0,  // every ~10s at 0.25s interval
   let playbackID = self.currentContent?.muxPlaybackID {
    ResumeStore.shared.save(playbackID: playbackID, position: time.seconds)
}
```

*Save on teardown* — in `tearDown()`:
```swift
if let playbackID = currentContent?.muxPlaybackID {
    let pos = player.currentTime().seconds
    if pos > 5 { ResumeStore.shared.save(playbackID: playbackID, position: pos) }
}
```

*Clear on completion* — in `handleItemEnded()`, capture the completed item's playbackID before advancing:
```swift
let completedPlaybackID = currentContent?.muxPlaybackID
// ... existing advance logic ...
if let pid = completedPlaybackID { ResumeStore.shared.clear(playbackID: pid) }
hasRestoredPosition = false  // reset for next item
```

---

## Spår 4 — Mux Data SDK
**Merges after Spår 2.** Spår 4 only touches `AVPlayerRepresentable` and its `Coordinator`; Spår 2 only touches `PlayerViewModel`. No overlap.

**Files:** `PlayerView.swift` (AVPlayerRepresentable + Coordinator + one line in PlayerViewModel.handleItemEnded)

### Step 1: Monitor player in makeUIViewController

In `AVPlayerRepresentable.makeUIViewController(context:)`, after the existing `vc.player = viewModel.player` setup:
```swift
import MuxStatsSdkAvplayer  // add to imports

let playerData = MUXSDKCustomerPlayerData(environmentKey: "ENV_KEY_PLACEHOLDER")
// ENV_KEY_PLACEHOLDER should be replaced with actual Mux environment key from dashboard
let videoData = MUXSDKCustomerVideoData()
videoData.videoTitle = viewModel.currentContent?.title
videoData.videoId = viewModel.currentContent?.muxPlaybackID
let customerData = MUXSDKCustomerData(
    customerPlayerData: playerData,
    videoData: videoData,
    viewData: nil
)!
MUXSDKStats.monitorAVPlayerViewController(vc, withPlayerName: "mainPlayer", customerData: customerData)
```

### Step 2: videoChange notification

Add to `PlayerView.swift` (outside any class):
```swift
extension Notification.Name {
    static let lunaflixVideoChanged = Notification.Name("lunaflixVideoChanged")
}
```

In `PlayerViewModel.handleItemEnded()`, after updating `currentContent` to the new item, add:
```swift
NotificationCenter.default.post(
    name: .lunaflixVideoChanged,
    object: newContent  // the new LunaContent after advance
)
```

In `AVPlayerRepresentable.Coordinator.init` (or `makeCoordinator()`), add observer:
```swift
NotificationCenter.default.addObserver(
    forName: .lunaflixVideoChanged,
    object: nil,
    queue: .main
) { [weak self] note in
    guard let content = note.object as? LunaContent else { return }
    let videoData = MUXSDKCustomerVideoData()
    videoData.videoTitle = content.title
    videoData.videoId = content.muxPlaybackID
    let customerData = MUXSDKCustomerData(customerPlayerData: nil, videoData: videoData, viewData: nil)!
    MUXSDKStats.videoChange(forPlayer: "mainPlayer", with: customerData)
}
```

Store the observer token in the Coordinator and remove it in `deinit`:
```swift
deinit {
    if let token = videoChangedObserver {
        NotificationCenter.default.removeObserver(token)
    }
}
```

### Step 3: Destroy player

In `AVPlayerRepresentable.dismantleUIViewController(_:coordinator:)`:
```swift
MUXSDKStats.destroyPlayer("mainPlayer")
```

---

## Merge Order & Agent Assignments

| Agent | Spår | Primary files |
|---|---|---|
| Agent 1 | Spår 1 | MuxService.swift, Content.swift, ContentDetailView.swift |
| Agent 2 | Spår 2 | ContentDetailView.swift (preload only), PlayerView.swift |
| Agent 3 | Spår 4 | PlayerView.swift (AVPlayerRepresentable + Coordinator only) |
| Agent 4 | Spår 3 | AppTheme.swift, HeroCarouselView.swift, LunaflixApp.swift, HomeViewModel.swift, HomeView.swift, ProfileViewModel.swift, ContentView.swift, new ResumeStore.swift, PlayerView.swift (additive) |

**PlayerView.swift merge order:** Agent 2 (Spår 2) → Agent 3 (Spår 4) → Agent 4 (Spår 3). Each touches distinct methods/sections with no line-level overlap.

**ContentDetailView.swift:** Agent 1 changes saveTitle/deleteVideo bodies. Agent 2 adds preloadedAsset state + .task modifier. Non-overlapping.

**Bug-dev agent** runs after all 4 complete — builds project, fixes compilation errors.

---

## Success Criteria
- [ ] `listAssets()` returns >100 items when library has >100 assets (verifiable via debugger/log)
- [ ] No thumbnail spinner visible on second HomeView appearance (Kingfisher disk cache)
- [ ] Player controls appear without buffering spinner on WiFi — observable by user watching play start instantly
- [ ] Lock screen and Control Center show title + artwork; play/pause/skip work via headphones
- [ ] After watching >10s of a video then closing and reopening the app, playback resumes from saved position (tearDown saves unconditionally)
- [ ] Build: 0 errors; no new warnings beyond the pre-existing Swift 6 concurrency and deprecated `onChange` warnings present at baseline
