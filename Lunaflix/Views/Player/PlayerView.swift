import SwiftUI
import AVKit
import AVFoundation
import MediaPlayer
import Kingfisher
import MUXSDKStats

extension Notification.Name {
    static let lunaflixVideoChanged = Notification.Name("lunaflixVideoChanged")
}

// MARK: - Player ViewModel

@MainActor
final class PlayerViewModel: ObservableObject {

    // MARK: Published UI state
    @Published var isPlaying        = true
    @Published var isBuffering      = false
    @Published var playerReady      = false
    @Published var progress: Double = 0
    @Published var bufferedProgress: Double = 0
    @Published var duration: Double = 1
    @Published var isMuted          = false
    @Published var error: String?   = nil
    @Published var currentIndex: Int
    @Published var showUpNext       = false

    // MARK: Player
    let player: AVQueuePlayer

    // MARK: Playlist
    let playlist: [LunaContent]
    var currentContent: LunaContent { playlist[currentIndex] }
    var nextContent: LunaContent? {
        let next = currentIndex + 1
        return next < playlist.count ? playlist[next] : nil
    }

    // MARK: Demo mode (no muxPlaybackID)
    var isDemoMode: Bool { currentContent.muxPlaybackID == nil }

    // MARK: Private
    private var timeControlObservation: NSKeyValueObservation?
    private var currentItemObserver: NSKeyValueObservation?
    private var itemStatusObserver: NSKeyValueObservation?
    private var interruptionObserver: Any?
    private var timeObserver: Any?
    private var itemEndObserver: Any?
    private var demoTask: Task<Void, Never>?
    private var preloadedAsset: AVURLAsset?
    private var remoteCommandsRegistered = false
    private var remoteCommandTokens: [Any] = []

    // MARK: Init
    init(content: LunaContent, playlist: [LunaContent] = [], preloadedAsset: AVURLAsset? = nil) {
        let list = playlist.isEmpty ? [content] : playlist
        self.playlist = list
        self.currentIndex = list.firstIndex(of: content) ?? 0
        self.player = AVQueuePlayer()
        self.preloadedAsset = preloadedAsset
        setup()
        setupRemoteCommands()
    }

    // MARK: - Setup

    private func setup() {
        configureAudioSession()

        if isDemoMode {
            startDemoMode()
            return
        }

        buildQueue(from: currentIndex)
        attachObservers()
        player.play()
        updateNowPlaying()  // after play, so isPlaying is accurate
    }

    private func configureAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .moviePlayback,
            options: [.allowAirPlay]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Queue management

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
        let nativeBounds = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen ?? UIScreen.main).nativeBounds
        item.preferredMaximumResolution = CGSize(
            width: nativeBounds.width,
            height: nativeBounds.height
        )

        // Set title metadata synchronously
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = content.title as NSString
        item.externalMetadata = [titleItem]

        // Append artwork asynchronously from Kingfisher cache (non-blocking)
        let capturedItem = item
        Task.detached {
            // Kingfisher 8.x: pass URL directly
            guard let pid = content.muxPlaybackID,
                  let url = URL(string: "https://image.mux.com/\(pid)/thumbnail.jpg?width=400&height=225&fit_mode=smartcrop&time=2") else { return }
            if let result = try? await KingfisherManager.shared.retrieveImage(with: url) {
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

    // MARK: - Observers

    private func attachObservers() {
        // timeControlStatus → isPlaying / isBuffering
        timeControlObservation = player.observe(
            \.timeControlStatus, options: [.new, .initial]
        ) { [weak self] p, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch p.timeControlStatus {
                case .playing:
                    self.isPlaying   = true
                    self.isBuffering = false
                    self.playerReady = true
                case .paused:
                    self.isPlaying   = false
                    self.isBuffering = false
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                @unknown default:
                    break
                }
            }
        }

        // Periodic time → progress + buffered range + Up Next
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let item = self.player.currentItem else { return }

                let d = item.duration.seconds
                guard d.isFinite, d > 0 else { return }

                self.duration = d
                if !self.isScrubbing {
                    self.progress = time.seconds / d
                }

                // Real buffered range from AVPlayerItem
                if let range = item.loadedTimeRanges.first?.timeRangeValue {
                    let end = (range.start + range.duration).seconds
                    self.bufferedProgress = min(1, end / d)
                }

                // "Up Next" banner: show 15s before end when a next item exists
                let remaining = d - time.seconds
                if remaining < 15, remaining > 0, self.nextContent != nil {
                    if !self.showUpNext { self.showUpNext = true }
                } else if remaining >= 15 {
                    if self.showUpNext { self.showUpNext = false }
                }

                // Update Now Playing every ~5 seconds
                if Int(time.seconds) % 5 == 0 {
                    self.updateNowPlaying()
                }
            }
        }

        // Auto-advance when current item finishes
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleItemEnded()
            }
        }

        // Observe currentItem changes to track per-item errors and clear stale state
        currentItemObserver = player.observe(\.currentItem, options: [.new, .initial]) { [weak self] p, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.error = nil
                self.setupItemStatusObserver(for: p.currentItem)
            }
        }

        // Handle audio interruptions (phone calls, Siri, alarms, etc.)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notif in
            guard let typeValue = notif.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch type {
                case .began:
                    self.player.pause()
                case .ended:
                    if let optValue = notif.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt,
                       AVAudioSession.InterruptionOptions(rawValue: optValue).contains(.shouldResume) {
                        self.player.play()
                    }
                @unknown default: break
                }
            }
        }

    }

    private func setupItemStatusObserver(for item: AVPlayerItem?) {
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        guard let item else { return }
        itemStatusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] itm, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch itm.status {
                case .failed:
                    self.error = itm.error?.localizedDescription ?? "Uppspelningen misslyckades"
                    self.isBuffering = false
                case .readyToPlay:
                    if self.error != nil { self.error = nil }
                default:
                    break
                }
            }
        }
    }

    // MARK: - Item end handling

    private func handleItemEnded() {
        let next = currentIndex + 1
        guard next < playlist.count else { return }

        // AVQueuePlayer already advanced; sync our index
        currentIndex = next
        progress     = 0
        duration     = 1
        showUpNext   = false

        // Notify Mux Data SDK about video change
        let newContent = playlist[next]
        NotificationCenter.default.post(name: .lunaflixVideoChanged, object: newContent)

        // Pre-queue the item after next (n+2) so the queue always has 2 items
        let afterNext = next + 1
        if afterNext < playlist.count,
           let item = makePlayerItem(for: playlist[afterNext]) {
            item.preferredForwardBufferDuration = 30
            player.insert(item, after: player.items().last)
        }

        updateNowPlaying()
    }

    // MARK: - Controls (called from View)

    var isScrubbing = false

    func togglePlayback() {
        if player.timeControlStatus == .paused {
            player.play()
        } else {
            player.pause()
        }
        updateNowPlaying()
    }

    func seek(by delta: Double) {
        let current = player.currentTime().seconds
        let target  = max(0, min(duration, current + delta))
        let time    = CMTime(seconds: target, preferredTimescale: 600)
        // Small tolerance = fast decode, no block
        player.seek(to: time,
                    toleranceBefore: CMTime(seconds: 0.1, preferredTimescale: 600),
                    toleranceAfter:  CMTime(seconds: 0.1, preferredTimescale: 600))
    }

    func seekToProgress(_ p: Double, completion: (() -> Void)? = nil) {
        let target = max(0, min(duration, p * duration))
        let time   = CMTime(seconds: target, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            guard finished else { return }
            Task { @MainActor in
                self.player.play()
                completion?()
            }
        }
    }

    func skipToNext() {
        guard nextContent != nil else { return }
        player.advanceToNextItem()
        handleItemEnded()   // sync index + pre-queue n+2
    }

    func retryPlayback() {
        error = nil
        buildQueue(from: currentIndex)
        player.play()
    }

    func toggleMute() {
        isMuted.toggle()
        player.isMuted = isMuted
    }

    // MARK: - Demo mode (mock content without muxPlaybackID)

    private func startDemoMode() {
        playerReady  = true
        isPlaying    = true
        duration     = 5400 // 90 min demo
        progress     = 0.0
        demoTask     = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { break }
                if isPlaying {
                    progress = min(1, progress + 0.5 / duration)
                }
            }
        }
    }

    // MARK: - Now Playing

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

    // MARK: - Remote Commands

    func seekToAbsoluteTime(_ seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func setupRemoteCommands() {
        guard !remoteCommandsRegistered else { return }
        remoteCommandsRegistered = true
        let center = MPRemoteCommandCenter.shared()
        remoteCommandTokens = [
            center.playCommand.addTarget { [weak self] _ in
                self?.player.play(); return .success
            },
            center.pauseCommand.addTarget { [weak self] _ in
                self?.player.pause(); return .success
            },
            center.skipForwardCommand.addTarget { [weak self] _ in
                self?.seek(by: 10); return .success
            },
            center.skipBackwardCommand.addTarget { [weak self] _ in
                self?.seek(by: -10); return .success
            },
            center.changePlaybackPositionCommand.addTarget { [weak self] event in
                guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
                self?.seekToAbsoluteTime(e.positionTime)
                return .success
            }
        ]
        center.skipForwardCommand.preferredIntervals = [10]
        center.skipBackwardCommand.preferredIntervals = [10]
    }

    // MARK: - Teardown

    func tearDown() {
        demoTask?.cancel()
        player.pause()
        if let obs = timeObserver {
            player.removeTimeObserver(obs)
            timeObserver = nil
        }
        if let obs = itemEndObserver {
            NotificationCenter.default.removeObserver(obs)
            itemEndObserver = nil
        }
        if let obs = interruptionObserver {
            NotificationCenter.default.removeObserver(obs)
            interruptionObserver = nil
        }
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        currentItemObserver?.invalidate()
        currentItemObserver = nil
        itemStatusObserver?.invalidate()
        itemStatusObserver = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        let center = MPRemoteCommandCenter.shared()
        remoteCommandTokens.forEach { token in
            center.playCommand.removeTarget(token)
            center.pauseCommand.removeTarget(token)
            center.skipForwardCommand.removeTarget(token)
            center.skipBackwardCommand.removeTarget(token)
            center.changePlaybackPositionCommand.removeTarget(token)
        }
        remoteCommandTokens = []
        remoteCommandsRegistered = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Player View

private enum DoubleTapSide { case left, right }

struct PlayerView: View {
    let content: LunaContent
    var playlist: [LunaContent] = []
    var preloadedAsset: AVURLAsset? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: PlayerViewModel

    @State private var showControls  = true
    @State private var isScrubbing   = false
    @State private var isFullscreen  = false
    @State private var showSettings  = false
    @State private var hideTask: Task<Void, Never>? = nil
    private let controlHideDelay: Double = 3.0
    @State private var doubleTapSide: DoubleTapSide? = nil

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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Video layer
            videoLayer

            // Buffer loading spinner (center, when no controls)
            if vm.isBuffering && !showControls {
                bufferSpinner
            }

            // Dimming when controls are visible
            if showControls {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.25), value: showControls)
            }

            // Double-tap seek flash
            if let side = doubleTapSide {
                SeekFlash(side: side)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            // Controls
            controls
                .opacity(showControls ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: showControls)
                .allowsHitTesting(showControls)

            // Paused ghost icon (when controls are hidden and paused)
            if !vm.isPlaying && !showControls && !vm.isBuffering {
                Image(systemName: "pause.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.25))
                    .allowsHitTesting(false)
            }

            // Error overlay
            if let errorMsg = vm.error {
                errorOverlay(errorMsg)
            }

            // "Up Next" banner
            if vm.showUpNext, let next = vm.nextContent {
                VStack {
                    Spacer()
                    UpNextCard(content: next) {
                        vm.skipToNext()
                    }
                    .padding(.bottom, showControls ? 140 : 40)
                    .padding(.trailing, 20)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .animation(.lunaSpring, value: vm.showUpNext)
                }
                .allowsHitTesting(true)
            }
        }
        .statusBarHidden()
        .contentShape(Rectangle())
        // Single-tap: toggle controls
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.22)) { showControls.toggle() }
            if showControls { scheduleHide() }
        }
        // Double-tap: seek ±10s  (left/right halves via GeometryReader overlay)
        .overlay(doubleTapOverlay)
        .onAppear {
            scheduleHide()
            OrientationManager.shared.allowLandscape = true
        }
        .onDisappear {
            tearDown()
        }
        .sheet(isPresented: $showSettings) {
            PlayerSettingsSheet(player: vm.player)
        }
    }

    // MARK: - Error Overlay

    @ViewBuilder
    private func errorOverlay(_ message: String) -> some View {
        Color.black.opacity(0.75)
            .ignoresSafeArea()
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(.lunaAccentLight)
            Text("Uppspelningsfel")
                .font(LunaFont.body())
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(message)
                .font(LunaFont.caption())
                .foregroundColor(.lunaTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            HStack(spacing: 16) {
                Button {
                    LunaHaptic.medium()
                    vm.retryPlayback()
                } label: {
                    Label("Försök igen", systemImage: "arrow.clockwise")
                        .font(LunaFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.lunaAccent)
                        .cornerRadius(12)
                }
                .buttonStyle(LunaPressStyle())

                Button { dismiss() } label: {
                    Text("Stäng")
                        .font(LunaFont.body())
                        .foregroundColor(.lunaTextSecondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(12)
                }
                .buttonStyle(LunaPressStyle())
            }
        }
    }

    // MARK: - Video Layer

    @ViewBuilder
    private var videoLayer: some View {
        if vm.isDemoMode {
            // Gradient stand-in for content without a Mux playback ID
            ZStack {
                vm.currentContent.heroGradient.gradient.ignoresSafeArea()
                if !vm.playerReady {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.4)
                        .tint(.white)
                }
            }
        } else {
            AVPlayerRepresentable(player: vm.player, viewModel: vm)
                .ignoresSafeArea()

            // Loading overlay until first frame arrives
            if !vm.playerReady {
                ZStack {
                    vm.currentContent.heroGradient.gradient.ignoresSafeArea()
                    bufferSpinner
                }
            }
        }
    }

    // MARK: - Buffer Spinner

    private var bufferSpinner: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
                .tint(.white)

            VStack(spacing: 4) {
                Text("Buffrar…")
                    .font(LunaFont.caption())
                    .foregroundColor(.white.opacity(0.6))

                // Show Luna's age at recording while loading — a warm personal touch
                if let age = vm.currentContent.lunaAgeAtRecording {
                    HStack(spacing: 4) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.lunaWarm.opacity(0.8))
                        Text(age)
                            .font(LunaFont.tag())
                            .foregroundColor(.lunaWarm.opacity(0.8))
                    }
                }
            }
        }
    }

    // MARK: - Double-tap overlay

    private var doubleTapOverlay: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Left half → seek -10s
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        handleDoubleTap(.left)
                    }
                // Right half → seek +10s
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        handleDoubleTap(.right)
                    }
            }
        }
    }

    private func handleDoubleTap(_ side: DoubleTapSide) {
        let delta: Double = side == .left ? -10 : 10
        LunaHaptic.light()
        vm.seek(by: delta)
        rescheduleHide()

        withAnimation(.easeIn(duration: 0.1)) { doubleTapSide = side }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.2)) { doubleTapSide = nil }
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            transportRow
            Spacer()
            bottomBar
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(LunaPressStyle())

            Spacer()

            VStack(spacing: 3) {
                Text(vm.currentContent.title)
                    .font(LunaFont.body())
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                if vm.currentContent.type == .series {
                    Text("S1 • E\(vm.currentIndex + 1)")
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextSecondary)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    LunaHaptic.light()
                    vm.toggleMute()
                } label: {
                    Image(systemName: vm.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(LunaPressStyle())

                AirPlayButton()
                    .frame(width: 44, height: 44)

                Button { showSettings = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(LunaPressStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 56)
    }

    // MARK: Transport

    private var transportRow: some View {
        HStack(spacing: 52) {
            Button {
                LunaHaptic.light()
                vm.seek(by: -10)
                rescheduleHide()
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(LunaPressStyle())

            // Play/Pause or buffering spinner
            Button {
                LunaHaptic.medium()
                vm.togglePlayback()
                if vm.isPlaying { rescheduleHide() }
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 70, height: 70)

                    if vm.isBuffering {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.1)
                            .tint(.white)
                    } else {
                        Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: vm.isPlaying ? 0 : 2)
                    }
                }
            }
            .buttonStyle(LunaPressStyle(scale: 0.92))

            Button {
                LunaHaptic.light()
                vm.seek(by: 10)
                rescheduleHide()
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(LunaPressStyle())
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 14) {
            // Seekbar
            seekbar.padding(.horizontal, 20)

            // Action row
            HStack {
                Button { showSettings = true } label: {
                    Label("Kvalitet", systemImage: "slider.horizontal.3")
                        .font(LunaFont.caption())
                        .foregroundColor(.white.opacity(0.75))
                }
                .buttonStyle(LunaPressStyle())

                Spacer()

                // Next episode / next in queue
                if vm.nextContent != nil {
                    Button {
                        LunaHaptic.medium()
                        vm.skipToNext()
                    } label: {
                        HStack(spacing: 5) {
                            Text("Nästa")
                                .font(LunaFont.caption())
                            Image(systemName: "forward.end.fill")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.white.opacity(0.75))
                    }
                    .buttonStyle(LunaPressStyle())
                }

                Spacer()

                // Fullscreen toggle
                Button {
                    LunaHaptic.light()
                    toggleFullscreen()
                } label: {
                    Image(systemName: isFullscreen
                          ? "arrow.down.right.and.arrow.up.left"
                          : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.75))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(LunaPressStyle())
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 50)
    }

    // MARK: Seekbar

    private var seekbar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: isScrubbing ? 6 : 4)

                    // Buffered
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: w * vm.bufferedProgress, height: isScrubbing ? 6 : 4)

                    // Played
                    Capsule()
                        .fill(LinearGradient.lunaAccentGradient)
                        .frame(width: w * vm.progress, height: isScrubbing ? 6 : 4)

                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: isScrubbing ? 20 : 14, height: isScrubbing ? 20 : 14)
                        .shadow(color: .black.opacity(0.35), radius: 4)
                        .offset(x: w * vm.progress - (isScrubbing ? 10 : 7))
                }
                .animation(.lunaSnappy, value: isScrubbing)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            if !isScrubbing {
                                isScrubbing     = true
                                vm.isScrubbing  = true
                                LunaHaptic.light()
                                hideTask?.cancel()
                            }
                            vm.progress = max(0, min(1, val.location.x / w))
                        }
                        .onEnded { _ in
                            isScrubbing    = false
                            vm.isScrubbing = false
                            vm.seekToProgress(vm.progress)
                            rescheduleHide()
                        }
                )
            }
            .frame(height: 20)

            // Time labels
            HStack {
                Text(timeString(from: vm.progress * vm.duration))
                    .font(LunaFont.mono(11))
                    .foregroundColor(.lunaTextSecondary)
                Spacer()
                Text("−" + timeString(from: (1 - vm.progress) * vm.duration))
                    .font(LunaFont.mono(11))
                    .foregroundColor(.lunaTextSecondary)
            }
        }
    }

    // MARK: - Helpers

    private func toggleFullscreen() {
        isFullscreen.toggle()
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let orientation: UIInterfaceOrientationMask = isFullscreen ? .landscapeRight : .portrait
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation)) { _ in }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(controlHideDelay))
            guard !Task.isCancelled else { return }
            if vm.isPlaying && !isScrubbing {
                withAnimation(.easeInOut(duration: 0.4)) { showControls = false }
            }
        }
    }

    private func rescheduleHide() {
        if showControls { scheduleHide() }
    }

    private func tearDown() {
        hideTask?.cancel()
        vm.tearDown()
        OrientationManager.shared.allowLandscape = false
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { _ in }
        }
    }

    private func timeString(from seconds: Double) -> String {
        let s = max(0, seconds)
        let h = Int(s) / 3600
        let m = (Int(s) % 3600) / 60
        let sec = Int(s) % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%d:%02d", m, sec)
    }
}

// MARK: - AVPlayer Representable

struct AVPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVQueuePlayer
    let viewModel: PlayerViewModel

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

// MARK: - AirPlay Button

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.activeTintColor = UIColor(Color.lunaAccentLight)
        view.tintColor = UIColor.white
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

// MARK: - Seek Flash Overlay

private struct SeekFlash: View {
    let side: DoubleTapSide

    var body: some View {
        HStack(spacing: 0) {
            if side == .left {
                flashSide(icon: "gobackward.10", label: "10 sek")
                Spacer()
            } else {
                Spacer()
                flashSide(icon: "goforward.10", label: "10 sek")
            }
        }
    }

    private func flashSide(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
            Text(label)
                .font(LunaFont.caption())
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(24)
        .background(Color.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(32)
    }
}

// MARK: - Up Next Card

private struct UpNextCard: View {
    let content: LunaContent
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nästa")
                .font(LunaFont.caption())
                .foregroundColor(.lunaTextMuted)
                .textCase(.uppercase)
                .tracking(0.6)

            HStack(spacing: 12) {
                // Thumbnail
                RoundedRectangle(cornerRadius: 8)
                    .fill(content.thumbnailGradient.gradient)
                    .frame(width: 80, height: 46)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(content.title)
                        .font(LunaFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(content.duration)
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextMuted)
                }

                Spacer()

                Button {
                    LunaHaptic.medium()
                    onPlay()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.lunaAccent.opacity(0.7))
                        .clipShape(Circle())
                }
                .buttonStyle(LunaPressStyle(scale: 0.9))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .frame(width: 280)
    }
}

// MARK: - Player Settings Sheet

struct PlayerSettingsSheet: View {
    let player: AVQueuePlayer
    @Environment(\.dismiss) private var dismiss

    // Map label → peak bitrate cap (0 = no cap = auto)
    private let qualityOptions: [(label: String, bitrate: Double)] = [
        ("Automatisk",  0),
        ("HD 1080p",    8_000_000),
        ("HD 720p",     4_000_000),
        ("SD",          1_500_000)
    ]

    @State private var selectedQuality = "Automatisk"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lunaSurface.ignoresSafeArea()
                List {
                    Section("Videokvalitet") {
                        ForEach(qualityOptions, id: \.label) { option in
                            Button {
                                LunaHaptic.selection()
                                selectedQuality = option.label
                                applyQuality(bitrate: option.bitrate)
                            } label: {
                                HStack {
                                    Text(option.label)
                                        .foregroundColor(.lunaTextPrimary)
                                    Spacer()
                                    if selectedQuality == option.label {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.lunaAccentLight)
                                    }
                                }
                            }
                            .listRowBackground(Color.lunaCard)
                        }
                    }

                    Section("Information") {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.lunaTextMuted)
                                .font(.system(size: 13))
                            Text("Ljud- och textningsspår styrs av iOS systeminställningar för media.")
                                .font(LunaFont.caption())
                                .foregroundColor(.lunaTextMuted)
                                .lineSpacing(3)
                        }
                        .listRowBackground(Color.lunaCard)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.lunaSurface)
            }
            .navigationTitle("Uppspelning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Klar") { dismiss() }
                        .foregroundColor(.lunaAccentLight)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func applyQuality(bitrate: Double) {
        player.currentItem?.preferredPeakBitRate = bitrate
    }
}
