# Lunaflix Full Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate startup buffering lag, add lock screen / headphone controls, cache thumbnails, paginate Mux API for 1000+ videos, add resume position, and add Mux Data analytics.

**Architecture:** 4 parallel tracks targeting non-overlapping files (Spår 1–4), merged in a defined order for the one shared file (PlayerView.swift: Spår2 → Spår4 → Spår3). A bug-dev agent validates the final build.

**Tech Stack:** Swift/SwiftUI iOS 17, AVQueuePlayer, Kingfisher 8.x (image cache), mux-stats-sdk-avplayer 4.x (analytics), MediaPlayer framework (lock screen), UserDefaults (resume store).

**Spec:** `docs/superpowers/specs/2026-03-19-full-modernization-design.md`

---

## Task 0 — Prerequisite: Add Swift Packages

> **Must complete before any other task begins.**

**Files:**
- Modify: `Lunaflix.xcodeproj` (via Xcode SPM UI)

- [ ] **Step 1: Add Kingfisher**
  Open `Lunaflix.xcodeproj` in Xcode. File → Add Package Dependencies.
  URL: `https://github.com/onevcat/Kingfisher`
  Version rule: Up to Next Major from `8.0.0`
  Add to target: `Lunaflix`

- [ ] **Step 2: Add Mux Data SDK**
  File → Add Package Dependencies.
  URL: `https://github.com/muxinc/mux-stats-sdk-avplayer.git`
  Version rule: Up to Next Major from `4.0.0`
  Add to target: `Lunaflix`

- [ ] **Step 3: Verify build still passes**
  ```bash
  xcodebuild -project Lunaflix.xcodeproj -scheme Lunaflix \
    -destination 'id=8249A808-0E96-4AD7-A51F-E00799B1BBB7' \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**
  ```bash
  git add Lunaflix.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
  git add Lunaflix.xcodeproj/project.pbxproj
  git commit -m "feat: add Kingfisher and Mux Data SDK packages"
  ```

---

## Task 1 — Spår 1: Network & Mux Layer

> **Parallel with Tasks 2, 3, 4** — touches only `MuxService.swift`, `Content.swift`, `ContentDetailView.swift`.

**Files:**
- Modify: `Lunaflix/Models/Content.swift`
- Modify: `Lunaflix/Services/MuxService.swift`
- Modify: `Lunaflix/Views/Detail/ContentDetailView.swift`

### Step 1.1 — Add assetId to LunaContent

- [ ] **Open `Lunaflix/Models/Content.swift`**

- [ ] **Add `assetId` field to LunaContent struct (after `muxPlaybackID`):**
  ```swift
  let muxPlaybackID: String?
  let assetId: String?          // Mux asset ID — enables direct edit/delete without re-listing
  let recordingDate: Date?
  ```

- [ ] **Add `assetId` to the init signature (after `muxPlaybackID` param):**
  ```swift
  muxPlaybackID: String? = nil,
  assetId: String? = nil,
  recordingDate: Date? = nil
  ```

- [ ] **Add `self.assetId = assetId` to init body (after `self.muxPlaybackID = muxPlaybackID`):**
  ```swift
  self.muxPlaybackID = muxPlaybackID
  self.assetId = assetId
  self.recordingDate = recordingDate
  ```

- [ ] **Update `fromMuxAsset(_:)` to populate assetId (in the `return LunaContent(` call):**
  ```swift
  muxPlaybackID: asset.primaryPlaybackID,
  assetId: asset.id,
  recordingDate: recordingDate
  ```

- [ ] **`DownloadItem.toLunaContent()` already passes `assetId: nil` implicitly** (it uses the default). No change needed there.

### Step 1.2 — Pagination in MuxService

- [ ] **Open `Lunaflix/Services/MuxService.swift`**

- [ ] **Add `withRetry` as a private method on the actor (before the `// MARK: - List Assets` block):**
  ```swift
  // MARK: - Retry Helper

  private func withRetry<T>(
      maxAttempts: Int = 3,
      baseDelay: Double = 0.5,
      _ operation: () async throws -> T
  ) async throws -> T {
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
              if case .serverError(let code) = error, code >= 500 {
                  attempt += 1
                  if attempt >= maxAttempts { throw error }
                  let delay = baseDelay * pow(2.0, Double(attempt - 1))
                  try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
              } else {
                  throw error
              }
          }
      }
  }
  ```

- [ ] **Add `fetchAssetsPage` private helper (inside the actor, after `withRetry`):**

  > **CRITICAL:** Do NOT use `authorizedRequest(path:)` here — it calls `baseURL.appendingPathComponent(path)` which percent-encodes `?` and `&`, breaking the query string. Build the URL directly with `URL(string:)` and call `authorizedRequest` with a fully-formed URL by duplicating the auth header logic, or add a new `authorizedRequest(url:method:body:)` overload. The simplest fix: add the following private helper that takes a `URL` directly:

  First, add a URL-based overload of `authorizedRequest` (below the existing one):
  ```swift
  private func authorizedRequest(
      url: URL,
      method: String = "GET",
      body: Data? = nil
  ) throws -> URLRequest {
      let tid = KeychainService.muxTokenID
      let tsc = KeychainService.muxTokenSecret
      guard !tid.isEmpty, !tsc.isEmpty else { throw MuxError.missingCredentials }
      var req = URLRequest(url: url)
      req.httpMethod = method
      req.setValue(authHeader(tokenID: tid, tokenSecret: tsc), forHTTPHeaderField: "Authorization")
      req.setValue("application/json", forHTTPHeaderField: "Content-Type")
      req.httpBody = body
      return req
  }
  ```

  Then add `fetchAssetsPage`:
  ```swift
  private func fetchAssetsPage(page: Int, limit: Int) async throws -> [MuxAsset] {
      guard let url = URL(string: "https://api.mux.com/video/v1/assets?limit=\(limit)&page=\(page)&order_direction=desc") else {
          throw MuxError.invalidResponse
      }
      let req = try authorizedRequest(url: url)
      let (data, response) = try await session.data(for: req)
      try validate(response)
      return try JSONDecoder().decode(MuxAssetListResponse.self, from: data).data
  }
  ```

- [ ] **Replace the body of `listAssets(limit:)` with the paginating loop:**
  Change the signature to `func listAssets() async throws -> [MuxAsset]` (remove the `limit` parameter — callers don't pass it):
  ```swift
  func listAssets() async throws -> [MuxAsset] {
      var all: [MuxAsset] = []
      var page = 1
      let limit = 100
      let maxPages = 20
      var batch: [MuxAsset]
      repeat {
          batch = try await withRetry { try await self.fetchAssetsPage(page: page, limit: limit) }
          all.append(contentsOf: batch)
          page += 1
      } while batch.count == limit && page <= maxPages
      return all
  }
  ```

- [ ] **Wrap `createDirectUpload` body in `withRetry`.**
  The current body makes one `session.data(for: req)` call. Wrap the whole do-work portion:
  ```swift
  func createDirectUpload(title: String?, recordingDate: Date? = nil) async throws -> MuxDirectUpload {
      let passthrough = MuxPassthroughMeta.encode(title: title, recordingDate: recordingDate)
      let body = MuxCreateUploadRequest(
          newAssetSettings: .init(playbackPolicy: ["public"], passthrough: passthrough)
      )
      let bodyData = try JSONEncoder().encode(body)
      return try await withRetry {
          let req = try self.authorizedRequest(path: "/video/v1/uploads", method: "POST", body: bodyData)
          let (data, response) = try await self.session.data(for: req)
          try self.validate(response)
          return try JSONDecoder().decode(MuxUploadResponse.self, from: data).data
      }
  }
  ```

### Step 1.3 — Fix saveTitle and deleteVideo in ContentDetailView

- [ ] **Open `Lunaflix/Views/Detail/ContentDetailView.swift`**

- [ ] **Replace `saveTitle()` body (lines 99–116):**
  ```swift
  private func saveTitle() async {
      let newTitle = editedTitle.trimmingCharacters(in: .whitespaces)
      guard !newTitle.isEmpty else { return }
      guard let assetId = content.assetId else { return }
      isSavingTitle = true
      do {
          try await MuxService.shared.updateAssetPassthrough(
              id: assetId,
              title: newTitle,
              recordingDate: content.recordingDate
          )
          LunaHaptic.success()
      } catch {}
      isSavingTitle = false
  }
  ```

- [ ] **Replace `deleteVideo()` body (lines 118–137):**
  ```swift
  private func deleteVideo() async {
      guard let assetId = content.assetId else { return }
      isDeleting = true
      do {
          try await MuxService.shared.deleteAsset(id: assetId)
          LunaHaptic.success()
      } catch {}
      isDeleting = false
      dismiss()
  }
  ```

### Step 1.4 — Build and commit

- [ ] **Build:**
  ```bash
  xcodebuild -project Lunaflix.xcodeproj -scheme Lunaflix \
    -destination 'id=8249A808-0E96-4AD7-A51F-E00799B1BBB7' \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Commit:**
  ```bash
  git add Lunaflix/Models/Content.swift \
          Lunaflix/Services/MuxService.swift \
          Lunaflix/Views/Detail/ContentDetailView.swift
  git commit -m "feat: paginate Mux API, add retry, store assetId for direct edit/delete"
  ```

---

## Task 2 — Spår 2: Player & Playback

> **Parallel with Tasks 1, 3, 4.** Touches `ContentDetailView.swift` (preload section only — non-overlapping with Task 1's saveTitle/deleteVideo section) and `PlayerView.swift`.

**Files:**
- Modify: `Lunaflix/Views/Detail/ContentDetailView.swift` (add preloadedAsset state + .task)
- Modify: `Lunaflix/Views/Player/PlayerView.swift`

### Step 2.1 — Pre-load AVURLAsset in ContentDetailView

- [ ] **Open `Lunaflix/Views/Detail/ContentDetailView.swift`**

- [ ] **Add import AVFoundation at the top if not present.**

- [ ] **Add `preloadedAsset` state property (after the existing @State properties at the top of the struct):**
  ```swift
  @State private var preloadedAsset: AVURLAsset? = nil
  ```

- [ ] **Add `.task` modifier to the main `body` ZStack or ScrollView (add it alongside the existing `.fullScreenCover` modifier):**
  ```swift
  .task {
      guard let pid = content.muxPlaybackID,
            let url = URL(string: "https://stream.mux.com/\(pid).m3u8") else { return }
      let options = [AVURLAssetPreferPreciseDurationAndTimingKey: true] as [String: Any]
      let asset = AVURLAsset(url: url, options: options)
      _ = try? await asset.load(.isPlayable)
      preloadedAsset = asset
  }
  ```

- [ ] **Update the `.fullScreenCover` PlayerView call to pass `preloadedAsset`:**
  ```swift
  .fullScreenCover(isPresented: $showPlayer) {
      let library = ContentStore.shared.allContent
      let playlist = library.isEmpty ? [content] : library
      PlayerView(content: content, playlist: playlist, preloadedAsset: preloadedAsset)
  }
  ```

### Step 2.2 — Update PlayerView and PlayerViewModel init

- [ ] **Open `Lunaflix/Views/Player/PlayerView.swift`**

- [ ] **Add `import MediaPlayer` at the top (alongside existing imports).**

- [ ] **Add `preloadedAsset` property to `PlayerView` (after `var playlist`):**
  ```swift
  var preloadedAsset: AVURLAsset? = nil
  ```

- [ ] **Update `PlayerView.init` to accept and forward `preloadedAsset`:**
  ```swift
  init(content: LunaContent, playlist: [LunaContent] = [], preloadedAsset: AVURLAsset? = nil) {
      self.content = content
      self.playlist = playlist
      self.preloadedAsset = preloadedAsset
      _vm = StateObject(wrappedValue: PlayerViewModel(
          content: content,
          playlist: playlist,
          preloadedAsset: preloadedAsset
      ))
  }
  ```

- [ ] **Add `preloadedAsset` param to `PlayerViewModel.init`:**
  ```swift
  // After: init(content: LunaContent, playlist: [LunaContent] = []) {
  init(content: LunaContent, playlist: [LunaContent] = [], preloadedAsset: AVURLAsset? = nil) {
      let list = playlist.isEmpty ? [content] : playlist
      self.playlist = list
      self.currentIndex = list.firstIndex(of: content) ?? 0
      self.player = AVQueuePlayer()
      self.preloadedAsset = preloadedAsset
      setup()
  }
  ```

- [ ] **Add `private var preloadedAsset: AVURLAsset?` to PlayerViewModel stored properties.**

### Step 2.3 — Update makePlayerItem

- [ ] **Replace `makePlayerItem(for:)` in PlayerViewModel:**
  ```swift
  private func makePlayerItem(for content: LunaContent, isFirstItem: Bool = false) -> AVPlayerItem? {
      guard let pid = content.muxPlaybackID else { return nil }

      let asset: AVURLAsset
      if isFirstItem, let preloaded = preloadedAsset {
          asset = preloaded
      } else {
          guard let url = URL(string: "https://stream.mux.com/\(pid).m3u8") else { return nil }
          asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
      }

      let item = AVPlayerItem(asset: asset)
      item.preferredForwardBufferDuration = 30
      item.preferredPeakBitRate = 0

      // Cap resolution to screen — avoids downloading 4K segments on a 390pt display
      let screenSize = UIScreen.main.bounds.size
      let scale = UIScreen.main.scale
      item.preferredMaximumResolution = CGSize(
          width: screenSize.width * scale,
          height: screenSize.height * scale
      )

      // Set title metadata synchronously
      let titleItem = AVMutableMetadataItem()
      titleItem.identifier = .commonIdentifierTitle
      titleItem.value = content.title as NSString
      item.externalMetadata = [titleItem]

      // Append artwork asynchronously from Kingfisher cache (non-blocking)
      let capturedItem = item
      let capturedTitle = content.title
      Task.detached { [weak self] in
          guard let url = content.thumbnailURL else { return }
          if let result = try? await KingfisherManager.shared.retrieveImage(
              with: ImageResource(downloadURL: url)
          ) {
              let artItem = AVMutableMetadataItem()
              artItem.identifier = .commonIdentifierArtwork
              artItem.value = result.image.pngData() as NSData?
              await MainActor.run {
                  capturedItem.externalMetadata += [artItem]
              }
          }
      }

      return item
  }
  ```

- [ ] **Update `buildQueue(from:)` to pass `isFirstItem` for the first queued item:**
  ```swift
  private func buildQueue(from index: Int) {
      player.removeAllItems()
      let end = min(index + 2, playlist.count)
      for i in index..<end {
          if let item = makePlayerItem(for: playlist[i], isFirstItem: i == index) {
              player.insert(item, after: player.items().last)
          }
      }
      player.automaticallyWaitsToMinimizeStalling = true
  }
  ```

- [ ] **Update `handleItemEnded()` — the n+2 pre-queue call uses `makePlayerItem(for:isFirstItem:false)` (default). No change needed there.**

### Step 2.4 — MPNowPlayingInfoCenter

- [ ] **Add `updateNowPlaying()` method to PlayerViewModel:**
  ```swift
  private func updateNowPlaying() {
      var info: [String: Any] = [:]
      info[MPMediaItemPropertyTitle] = currentContent.title
      info[MPMediaItemPropertyPlaybackDuration] = duration
      info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime().seconds
      info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0

      // Artwork from Kingfisher memory cache (sync — no I/O)
      if let thumbURL = URL(string: "https://image.mux.com/\(currentContent.muxPlaybackID ?? "")/thumbnail.jpg?width=400&height=225&fit_mode=smartcrop&time=2"),
         let cached = KingfisherManager.shared.cache.retrieveImageInMemoryCache(
             forKey: thumbURL.absoluteString) {
          info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: cached.size) { _ in cached }
      }

      MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }
  ```

- [ ] **Call `updateNowPlaying()` at end of `attachObservers()` (after all observers are set up).**

- [ ] **In the periodic time observer closure, add gated update (after the bufferedProgress calculation):**
  ```swift
  // Update Now Playing every ~5 seconds
  if Int(time.seconds) % 5 == 0 {
      self.updateNowPlaying()
  }
  ```

- [ ] **Call `updateNowPlaying()` in `togglePlayback()` after the play/pause call:**
  ```swift
  func togglePlayback() {
      if player.timeControlStatus == .paused {
          player.play()
      } else {
          player.pause()
      }
      updateNowPlaying()
  }
  ```

- [ ] **Call `updateNowPlaying()` at end of `handleItemEnded()` (after `currentIndex = next`).**

- [ ] **Clear Now Playing in `tearDown()` (before the audio session deactivation line):**
  ```swift
  MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  ```

### Step 2.5 — MPRemoteCommandCenter

- [ ] **Add `private var remoteCommandsRegistered = false` to PlayerViewModel stored properties.**

- [ ] **Add `seekToAbsoluteTime` helper to PlayerViewModel:**
  ```swift
  func seekToAbsoluteTime(_ seconds: Double) {
      let time = CMTime(seconds: seconds, preferredTimescale: 600)
      player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
  }
  ```

- [ ] **Add `setupRemoteCommands()` to PlayerViewModel:**
  ```swift
  private func setupRemoteCommands() {
      guard !remoteCommandsRegistered else { return }
      remoteCommandsRegistered = true
      let center = MPRemoteCommandCenter.shared()
      center.playCommand.addTarget { [weak self] _ in
          self?.player.play(); return .success
      }
      center.pauseCommand.addTarget { [weak self] _ in
          self?.player.pause(); return .success
      }
      center.skipForwardCommand.preferredIntervals = [10]
      center.skipForwardCommand.addTarget { [weak self] _ in
          self?.seek(by: 10); return .success
      }
      center.skipBackwardCommand.preferredIntervals = [10]
      center.skipBackwardCommand.addTarget { [weak self] _ in
          self?.seek(by: -10); return .success
      }
      center.changePlaybackPositionCommand.addTarget { [weak self] event in
          guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
          self?.seekToAbsoluteTime(e.positionTime)
          return .success
      }
  }
  ```

- [ ] **Call `setupRemoteCommands()` in `PlayerViewModel.init`, after `setup()`:**
  ```swift
  setup()
  setupRemoteCommands()
  ```

- [ ] **In `tearDown()`, remove all remote command targets (add before the audio session line):**
  ```swift
  let center = MPRemoteCommandCenter.shared()
  [center.playCommand, center.pauseCommand, center.skipForwardCommand,
   center.skipBackwardCommand, center.changePlaybackPositionCommand]
      .forEach { $0.removeTarget(nil) }
  remoteCommandsRegistered = false
  ```

### Step 2.6 — Build and commit

- [ ] **Build:**
  ```bash
  xcodebuild -project Lunaflix.xcodeproj -scheme Lunaflix \
    -destination 'id=8249A808-0E96-4AD7-A51F-E00799B1BBB7' \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Commit:**
  ```bash
  git add Lunaflix/Views/Detail/ContentDetailView.swift \
          Lunaflix/Views/Player/PlayerView.swift
  git commit -m "feat: preload AVURLAsset, lock screen controls, resolution cap, metadata"
  ```

---

## Task 3 — Spår 4: Mux Data SDK
> **NOTE: Task 3 = Spår 4 (Mux Data SDK). Task 4 = Spår 3 (Caching & State). The numbering differs from the Spår numbering — Spår 3 and 4 swap order due to merge dependencies.**

> **Merges AFTER Task 2** (PlayerView.swift: Spår2 → Spår4 → Spår3). Touches only `AVPlayerRepresentable` and its Coordinator in `PlayerView.swift`.

**Files:**
- Modify: `Lunaflix/Views/Player/PlayerView.swift` (AVPlayerRepresentable + Coordinator + one line in PlayerViewModel.handleItemEnded)

### Step 3.0 — Verify Mux Data SDK module name

- [ ] **After Task 0 adds the package, verify the exact importable module name:**
  ```bash
  find ~/Library/Developer/Xcode/DerivedData -name "MuxStatsSdkAvplayer.swiftmodule" 2>/dev/null | head -3
  find ~/Library/Developer/Xcode/DerivedData -name "*.swiftmodule" 2>/dev/null | grep -i mux | head -5
  ```
  The correct import is typically `import MuxStatsSdkAvplayer`. If the search returns a different name, use that exact name in all `import` statements below.

### Step 3.1 — Add Notification.Name extension

- [ ] **Open `Lunaflix/Views/Player/PlayerView.swift`**

- [ ] **Add `Notification.Name` extension near the top (after the imports, outside any type):**
  ```swift
  extension Notification.Name {
      static let lunaflixVideoChanged = Notification.Name("lunaflixVideoChanged")
  }
  ```

### Step 3.2 — Post notification in handleItemEnded

- [ ] **In `PlayerViewModel.handleItemEnded()`, after `currentIndex = next`, post the notification:**
  ```swift
  // Notify Mux Data SDK about video change
  let newContent = playlist[next]
  NotificationCenter.default.post(name: .lunaflixVideoChanged, object: newContent)
  ```

### Step 3.3 — Add Coordinator to AVPlayerRepresentable

- [ ] **Replace `AVPlayerRepresentable` with a version that has a Coordinator:**
  ```swift
  struct AVPlayerRepresentable: UIViewControllerRepresentable {
      let player: AVQueuePlayer
      @ObservedObject var viewModel: PlayerViewModel

      func makeCoordinator() -> Coordinator {
          Coordinator()
      }

      func makeUIViewController(context: Context) -> AVPlayerViewController {
          let vc = AVPlayerViewController()
          vc.player = player
          vc.showsPlaybackControls = false
          vc.videoGravity = .resizeAspect
          vc.view.backgroundColor = .black
          vc.allowsPictureInPicturePlayback = true

          // Mux Data SDK monitoring
          let playerData = MUXSDKCustomerPlayerData(environmentKey: "ENV_KEY_PLACEHOLDER")
          let videoData = MUXSDKCustomerVideoData()
          videoData.videoTitle = viewModel.currentContent.title
          videoData.videoId = viewModel.currentContent.muxPlaybackID
          if let customerData = MUXSDKCustomerData(
              customerPlayerData: playerData,
              videoData: videoData,
              viewData: nil
          ) {
              MUXSDKStats.monitorAVPlayerViewController(
                  vc, withPlayerName: "mainPlayer", customerData: customerData
              )
          }

          context.coordinator.startObserving()
          return vc
      }

      func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
          if vc.player !== player { vc.player = player }
      }

      static func dismantleUIViewController(_ vc: AVPlayerViewController, coordinator: Coordinator) {
          MUXSDKStats.destroyPlayer("mainPlayer")
          coordinator.stopObserving()
      }

      // MARK: - Coordinator

      final class Coordinator {
          private var token: NSObjectProtocol?

          func startObserving() {
              token = NotificationCenter.default.addObserver(
                  forName: .lunaflixVideoChanged,
                  object: nil,
                  queue: .main
              ) { [weak self] note in
                  guard let content = note.object as? LunaContent else { return }
                  let videoData = MUXSDKCustomerVideoData()
                  videoData.videoTitle = content.title
                  videoData.videoId = content.muxPlaybackID
                  if let customerData = MUXSDKCustomerData(
                      customerPlayerData: nil,
                      videoData: videoData,
                      viewData: nil
                  ) {
                      MUXSDKStats.videoChange(forPlayer: "mainPlayer", with: customerData)
                  }
              }
          }

          func stopObserving() {
              if let t = token { NotificationCenter.default.removeObserver(t) }
              token = nil
          }

          deinit { stopObserving() }
      }
  }
  ```

- [ ] **Update the `AVPlayerRepresentable` call site in `PlayerView.body` (in `videoLayer`):**
  ```swift
  // Change:
  AVPlayerRepresentable(player: vm.player)
  // To:
  AVPlayerRepresentable(player: vm.player, viewModel: vm)
  ```

- [ ] **Add `import MuxStatsSdkAvplayer` (check exact module name — may be `MuxCore` or `MUXSDKStats`; verify in Xcode after package resolves). If uncertain, try:**
  ```swift
  import MuxStatsSdkAvplayer
  ```

### Step 3.4 — Build and commit

- [ ] **Build:**
  ```bash
  xcodebuild -project Lunaflix.xcodeproj -scheme Lunaflix \
    -destination 'id=8249A808-0E96-4AD7-A51F-E00799B1BBB7' \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Commit:**
  ```bash
  git add Lunaflix/Views/Player/PlayerView.swift
  git commit -m "feat: integrate Mux Data SDK for playback analytics"
  ```

---

## Task 4 — Spår 3: Caching & State
> **NOTE: Task 4 = Spår 3 (Caching & State). Task 3 = Spår 4 (Mux Data SDK). See merge order note above.**

> **Merges AFTER Task 2** (PlayerView.swift additions are to PlayerViewModel — additive, no conflict with Task 3's Coordinator additions). Can be done in parallel with Task 3 on all files except PlayerView.swift; merge PlayerView.swift changes last.

**Files:**
- Modify: `Lunaflix/Theme/AppTheme.swift`
- Modify: `Lunaflix/Views/Home/HeroCarouselView.swift`
- Modify: `Lunaflix/App/LunaflixApp.swift`
- Modify: `Lunaflix/ViewModels/HomeViewModel.swift`
- Modify: `Lunaflix/Views/Home/HomeView.swift`
- Modify: `Lunaflix/ViewModels/ProfileViewModel.swift`
- Modify: `Lunaflix/Views/Main/ContentView.swift`
- Create: `Lunaflix/Services/ResumeStore.swift`
- Modify: `Lunaflix/Views/Player/PlayerView.swift` (PlayerViewModel only — after Task 3 merge)

### Step 4.1 — Kingfisher cache config in LunaflixApp

- [ ] **Open `Lunaflix/App/LunaflixApp.swift`**

- [ ] **Add `import Kingfisher` at the top.**

- [ ] **Add a custom `init()` to the App struct (or add to existing init):**
  ```swift
  init() {
      // Kingfisher disk cache: 200 MB, memory cache: 50 MB
      KingfisherManager.shared.cache.diskStorage.config.sizeLimit = 200 * 1024 * 1024
      KingfisherManager.shared.cache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024
  }
  ```

### Step 4.2 — Replace AsyncImage with KFImage in MuxThumbnailImage

- [ ] **Open `Lunaflix/Theme/AppTheme.swift`**

- [ ] **Add `import Kingfisher` at the top.**

- [ ] **Find `MuxThumbnailImage` (the view that uses `AsyncImage`). Replace the `AsyncImage` block with:**
  ```swift
  KFImage(thumbnailURL)
      .placeholder {
          // Existing fallback gradient (whatever is currently in the failure/default case)
          content.thumbnailGradient.gradient
              .cornerRadius(/* match existing cornerRadius */)
      }
      .fade(duration: 0.2)
      .resizable()
      .aspectRatio(contentMode: .fill)
  ```
  Preserve all existing modifiers (`.cornerRadius`, `.clipped`, etc.) that were on the `AsyncImage` result.

### Step 4.3 — Replace AsyncImage with KFImage in HeroCard

- [ ] **Open `Lunaflix/Views/Home/HeroCarouselView.swift`**

- [ ] **Add `import Kingfisher` at the top.**

- [ ] **Find any `AsyncImage` usage in `HeroCard` and replace with `KFImage` using the same pattern as Step 4.2.**

### Step 4.4 — ImagePrefetcher in HomeViewModel

- [ ] **Open `Lunaflix/ViewModels/HomeViewModel.swift`**

- [ ] **Add `import Kingfisher` at the top.**

- [ ] **In `load()`, after `ContentStore.shared.update(contents)`, add:**
  ```swift
  // Prefetch first 50 thumbnails (hero + first visible rows)
  let visibleURLs = contents.prefix(50).compactMap { content -> URL? in
      guard let pid = content.muxPlaybackID else { return nil }
      return URL(string: "https://image.mux.com/\(pid)/thumbnail.jpg?width=400&height=225&fit_mode=smartcrop&time=2")
  }
  ImagePrefetcher(urls: Array(visibleURLs)).start()
  ```

### Step 4.5 — @Observable migration for HomeViewModel

- [ ] **In `HomeViewModel.swift`, make the following changes:**

  Change class declaration:
  ```swift
  // Before:
  @MainActor
  final class HomeViewModel: ObservableObject {
  // After:
  @Observable
  @MainActor
  final class HomeViewModel {
  ```

  Remove `@Published` from all 5 properties:
  ```swift
  // Before:
  @Published var heroContents: [LunaContent] = []
  @Published var categories: [ContentCategory] = []
  @Published var currentHeroIndex: Int = 0
  @Published var isLoading: Bool = true
  @Published var isConfigured: Bool = false
  // After:
  var heroContents: [LunaContent] = []
  var categories: [ContentCategory] = []
  var currentHeroIndex: Int = 0
  var isLoading: Bool = true
  var isConfigured: Bool = false
  ```

  Keep `import Combine` and `private var heroTimer: AnyCancellable?` — they are valid inside `@Observable`.

### Step 4.6 — @Observable migration for ProfileViewModel

- [ ] **Open `Lunaflix/ViewModels/ProfileViewModel.swift`**

- [ ] **Change class declaration:**
  ```swift
  // Before:
  @MainActor
  final class ProfileViewModel: ObservableObject {
  // After:
  @Observable
  @MainActor
  final class ProfileViewModel {
  ```

- [ ] **Remove `@Published` from all 5 properties.** The `didSet` blocks stay — they work identically on plain stored properties in `@Observable`:
  ```swift
  // Before:
  @Published var user: User
  @Published var notificationsEnabled: Bool {
  @Published var autoplayEnabled: Bool {
  @Published var downloadQuality: DownloadQuality {
  @Published var streamingQuality: StreamingQuality {
  // After (just remove @Published from each — keep didSet bodies unchanged):
  var user: User
  var notificationsEnabled: Bool {
  var autoplayEnabled: Bool {
  var downloadQuality: DownloadQuality {
  var streamingQuality: StreamingQuality {
  ```

### Step 4.7 — Update call sites for @Observable

- [ ] **Open `Lunaflix/Views/Home/HomeView.swift`**

- [ ] **Change `@StateObject private var viewModel = HomeViewModel()` to `@State private var viewModel = HomeViewModel()`.**

- [ ] **Open `Lunaflix/Views/Main/ContentView.swift`** — update any `@StateObject`/`@ObservedObject` for `HomeViewModel` or `ProfileViewModel` to `@State`. If none exist, no change needed.

- [ ] **Open `Lunaflix/Views/Profile/ProfileView.swift`** — find the `ProfileViewModel` property (likely `@StateObject private var vm = ProfileViewModel()`) and change to `@State private var vm = ProfileViewModel()`.

### Step 4.8 — Create ResumeStore

- [ ] **Create `Lunaflix/Services/ResumeStore.swift`:**
  ```swift
  import Foundation

  struct ResumeStore {
      static let shared = ResumeStore()
      private let defaults = UserDefaults.standard
      private let keyPrefix = "lunaflix.resume."

      private init() {}

      func save(playbackID: String, position: Double) {
          defaults.set(position, forKey: keyPrefix + playbackID)
      }

      /// Returns nil if saved position is ≤ 5s (not worth resuming from)
      func position(for playbackID: String) -> Double? {
          let v = defaults.double(forKey: keyPrefix + playbackID)
          return v > 5 ? v : nil
      }

      func clear(playbackID: String) {
          defaults.removeObject(forKey: keyPrefix + playbackID)
      }
  }
  ```

### Step 4.9 — Resume position in PlayerViewModel

- [ ] **Open `Lunaflix/Views/Player/PlayerView.swift`** (after Task 3's changes are merged)

- [ ] **Add to PlayerViewModel stored properties:**
  ```swift
  private var hasRestoredPosition = false
  private var resumeSaveCounter = 0
  ```

- [ ] **In `setupItemStatusObserver(for:)`, in the `.readyToPlay` case, add resume restore (after `self.error = nil`):**
  ```swift
  case .readyToPlay:
      if self.error != nil { self.error = nil }
      // Restore resume position (one-time per item)
      if !self.hasRestoredPosition,
         let playbackID = self.currentContent.muxPlaybackID,
         let savedPos = ResumeStore.shared.position(for: playbackID) {
          let dur = itm.duration.seconds
          if dur.isNaN || savedPos < dur * 0.95 {
              let t = CMTime(seconds: savedPos, preferredTimescale: 600)
              self.player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
          }
          self.hasRestoredPosition = true
      }
  ```

- [ ] **In `attachObservers()`, inside the periodic time observer Task closure, add save counter (after the `showUpNext` logic):**
  ```swift
  // Save resume position every ~10s
  self.resumeSaveCounter += 1
  if self.resumeSaveCounter % 40 == 0,
     let playbackID = self.currentContent.muxPlaybackID {
      ResumeStore.shared.save(playbackID: playbackID, position: time.seconds)
  }
  ```

- [ ] **In `tearDown()`, add save (before `MPNowPlayingInfoCenter.default().nowPlayingInfo = nil`):**
  ```swift
  // Save resume position on exit
  if let playbackID = currentContent.muxPlaybackID {
      let pos = player.currentTime().seconds
      if pos > 5 { ResumeStore.shared.save(playbackID: playbackID, position: pos) }
  }
  ```

- [ ] **Replace `handleItemEnded()` in PlayerViewModel entirely (capture completedPlaybackID BEFORE advancing currentIndex):**
  ```swift
  private func handleItemEnded() {
      let completedPlaybackID = currentContent.muxPlaybackID  // capture BEFORE currentIndex advances
      let next = currentIndex + 1
      guard next < playlist.count else { return }

      // AVQueuePlayer already advanced; sync our index
      currentIndex = next
      progress     = 0
      duration     = 1
      showUpNext   = false
      hasRestoredPosition = false    // reset for new item
      resumeSaveCounter   = 0        // reset periodic save counter

      // Clear resume for the completed item (watched to end = no resume needed)
      if let pid = completedPlaybackID { ResumeStore.shared.clear(playbackID: pid) }

      // Notify Mux Data SDK (Task 3 adds this line)
      let newContent = playlist[next]
      NotificationCenter.default.post(name: .lunaflixVideoChanged, object: newContent)

      // Update Now Playing for new item (Task 2 adds this)
      updateNowPlaying()

      // Pre-queue the item after next (n+2) so the queue always has 2 items
      let afterNext = next + 1
      if afterNext < playlist.count,
         let item = makePlayerItem(for: playlist[afterNext]) {
          item.preferredForwardBufferDuration = 30
          player.insert(item, after: player.items().last)
      }
  }
  ```
  **Note:** The final `handleItemEnded()` combines changes from Task 2 (updateNowPlaying), Task 3 (NotificationCenter post), and Task 4 (ResumeStore). If implementing as separate parallel merges, each agent adds only their lines to the existing method body.

### Step 4.10 — Build and commit

- [ ] **Build:**
  ```bash
  xcodebuild -project Lunaflix.xcodeproj -scheme Lunaflix \
    -destination 'id=8249A808-0E96-4AD7-A51F-E00799B1BBB7' \
    build 2>&1 | tail -5
  ```
  Expected: `** BUILD SUCCEEDED **`

- [ ] **Commit:**
  ```bash
  git add Lunaflix/App/LunaflixApp.swift \
          Lunaflix/Theme/AppTheme.swift \
          Lunaflix/Views/Home/HeroCarouselView.swift \
          Lunaflix/ViewModels/HomeViewModel.swift \
          Lunaflix/Views/Home/HomeView.swift \
          Lunaflix/ViewModels/ProfileViewModel.swift \
          Lunaflix/Views/Main/ContentView.swift \
          Lunaflix/Services/ResumeStore.swift \
          Lunaflix/Views/Player/PlayerView.swift
  git commit -m "feat: Kingfisher cache, @Observable migration, resume position"
  ```

---

## Task 5 — Final Build Validation

> **Runs after all 4 tasks complete.** Use the `bug-dev` subagent.

**Prompt for bug-dev agent:**
> Build the Lunaflix iOS project at `/Users/tedsvard/Library/Mobile Documents/com~apple~CloudDocs/Lunaflix` using:
> `xcodebuild -project Lunaflix.xcodeproj -scheme Lunaflix -destination 'id=8249A808-0E96-4AD7-A51F-E00799B1BBB7' build`
> Fix all compilation errors. Do not fix pre-existing warnings about Swift 6 concurrency in PlayerView or deprecated `onChange` — those are baseline. Fix everything else until the build succeeds with 0 errors.

- [ ] **Dispatch bug-dev agent with the prompt above**

- [ ] **After bug-dev confirms build success, commit any fixes:**
  ```bash
  git add -A
  git commit -m "fix: resolve compilation errors from full modernization"
  ```

- [ ] **Final verification — run build one more time:**
  ```bash
  xcodebuild -project Lunaflix.xcodeproj -scheme Lunaflix \
    -destination 'id=8249A808-0E96-4AD7-A51F-E00799B1BBB7' \
    build 2>&1 | tail -3
  ```
  Expected: `** BUILD SUCCEEDED **`

---

## Merge Order Summary

```
Task 0 (prerequisite) → Tasks 1, 2, 3, 4 run in parallel
                                         ↓
Task 3 (Spår 4) merges PlayerView AFTER Task 2 (Spår 2)
Task 4 (Spår 3) merges PlayerView AFTER Task 3 (Spår 4)
                                         ↓
                                    Task 5 (build validation)
```

## Success Checklist
- [ ] `listAssets()` fetches all pages (>100 videos returned)
- [ ] No thumbnail re-download after first app launch (Kingfisher disk cache)
- [ ] Tapping Play starts video without visible buffering spinner on WiFi
- [ ] Lock screen shows title and artwork; headphone play/pause/skip work
- [ ] Resume position restored after app restart for video watched >10s
- [ ] Build: 0 errors, no new warnings beyond pre-existing baseline
