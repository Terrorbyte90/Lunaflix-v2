import SwiftUI
import AVKit
import AVFoundation

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
    private var timeObserver: Any?
    private var itemEndObserver: Any?
    private var demoTask: Task<Void, Never>?

    // MARK: Init
    init(content: LunaContent, playlist: [LunaContent] = []) {
        let list = playlist.isEmpty ? [content] : playlist
        self.playlist = list
        self.currentIndex = list.firstIndex(of: content) ?? 0
        self.player = AVQueuePlayer()
        setup()
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
        // Queue current + next for gapless transition
        let end = min(index + 2, playlist.count)
        for i in index..<end {
            if let item = makePlayerItem(for: playlist[i]) {
                player.insert(item, after: player.items().last)
            }
        }
        player.automaticallyWaitsToMinimizeStalling = true
    }

    private func makePlayerItem(for content: LunaContent) -> AVPlayerItem? {
        guard let pid = content.muxPlaybackID,
              let url = URL(string: "https://stream.mux.com/\(pid).m3u8")
        else { return nil }

        let asset = AVURLAsset(url: url, options: [
            AVURLAssetPreferPreciseDurationAndTimingKey: true
        ])
        let item = AVPlayerItem(asset: asset)
        // 30s forward buffer for lag-free, seamless playback
        item.preferredForwardBufferDuration = 30
        // Prefer higher quality variants
        item.preferredPeakBitRate = 0         // no cap
        item.preferredMaximumResolution = .zero // no cap
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

        // Pre-queue the item after next (n+2) so the queue always has 2 items
        let afterNext = next + 1
        if afterNext < playlist.count,
           let item = makePlayerItem(for: playlist[afterNext]) {
            item.preferredForwardBufferDuration = 30
            player.insert(item, after: player.items().last)
        }
    }

    // MARK: - Controls (called from View)

    var isScrubbing = false

    func togglePlayback() {
        if player.timeControlStatus == .paused {
            player.play()
        } else {
            player.pause()
        }
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
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Player View

private enum DoubleTapSide { case left, right }

struct PlayerView: View {
    let content: LunaContent
    var playlist: [LunaContent] = []

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: PlayerViewModel

    @State private var showControls  = true
    @State private var isScrubbing   = false
    @State private var isFullscreen  = false
    @State private var showSettings  = false
    @State private var hideTask: Task<Void, Never>? = nil
    @State private var doubleTapSide: DoubleTapSide? = nil

    init(content: LunaContent, playlist: [LunaContent] = []) {
        self.content  = content
        self.playlist = playlist
        _vm = StateObject(wrappedValue: PlayerViewModel(content: content, playlist: playlist))
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
            PlayerSettingsSheet()
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
            AVPlayerRepresentable(player: vm.player)
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
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
                .tint(.white)
            Text("Buffrar…")
                .font(LunaFont.caption())
                .foregroundColor(.white.opacity(0.6))
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

            HStack(spacing: 12) {
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
                Button {} label: {
                    Label("Textning", systemImage: "captions.bubble.fill")
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

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = false
        vc.videoGravity = .resizeAspect
        vc.view.backgroundColor = .black
        // Allow subtitles / captions from HLS stream
        vc.allowsPictureInPicturePlayback = false
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if vc.player !== player { vc.player = player }
    }
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
    @Environment(\.dismiss) private var dismiss

    let qualities  = ["Automatisk", "4K Ultra HD", "HD 1080p", "HD 720p", "SD"]
    let languages  = ["Svenska", "Engelska", "Norska", "Danska"]
    let subtitles  = ["Av", "Svenska", "Engelska"]

    @State private var selectedQuality = "Automatisk"
    @State private var selectedLang    = "Svenska"
    @State private var selectedSub     = "Av"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lunaSurface.ignoresSafeArea()
                List {
                    settingsSection("Kvalitet",  options: qualities,  selected: $selectedQuality)
                    settingsSection("Ljud",      options: languages,  selected: $selectedLang)
                    settingsSection("Textning",  options: subtitles,  selected: $selectedSub)
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

    @ViewBuilder
    private func settingsSection(_ title: String, options: [String], selected: Binding<String>) -> some View {
        Section(title) {
            ForEach(options, id: \.self) { opt in
                Button {
                    LunaHaptic.selection()
                    selected.wrappedValue = opt
                } label: {
                    HStack {
                        Text(opt).foregroundColor(.lunaTextPrimary)
                        Spacer()
                        if selected.wrappedValue == opt {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.lunaAccentLight)
                        }
                    }
                }
                .listRowBackground(Color.lunaCard)
            }
        }
    }
}
