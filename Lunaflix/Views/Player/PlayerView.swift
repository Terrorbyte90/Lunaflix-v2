import SwiftUI
import AVKit
import AVFoundation

// MARK: - Player View

struct PlayerView: View {
    let content: LunaContent
    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer? = nil
    @State private var isPlaying = true
    @State private var showControls = true
    @State private var progress: Double = 0
    @State private var duration: Double = 1
    @State private var isMuted = false
    @State private var showSettings = false
    @State private var isScrubbing = false
    @State private var isFullscreen = false
    @State private var hideTask: Task<Void, Never>? = nil
    @State private var timeObserver: Any? = nil

    private let controlHideDelay: TimeInterval = 3.5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                // Real AVPlayer
                AVPlayerRepresentable(player: player)
                    .ignoresSafeArea()
            } else {
                // Fallback gradient while loading
                ZStack {
                    content.heroGradient.gradient.ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }

            // Dimming overlay
            if showControls {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.3), value: showControls)
            }

            // Controls overlay
            controls
                .opacity(showControls ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: showControls)
                .allowsHitTesting(showControls)

            // Paused indicator
            if !isPlaying && !showControls {
                Image(systemName: "pause.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.3))
                    .transition(.opacity)
            }
        }
        .statusBarHidden()
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.22)) {
                showControls.toggle()
            }
            if showControls { scheduleHide() }
        }
        .onAppear {
            setupPlayer()
            scheduleHide()
            OrientationManager.shared.allowLandscape = true
        }
        .onDisappear {
            tearDownPlayer()
            OrientationManager.shared.allowLandscape = false
            // Force back to portrait
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { _ in }
            }
        }
        .sheet(isPresented: $showSettings) {
            PlayerSettingsSheet()
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 0) {
            // Top bar
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
                    Text(content.title)
                        .font(LunaFont.body())
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if content.type == .series {
                        Text("S1 • E1")
                            .font(LunaFont.caption())
                            .foregroundColor(.lunaTextSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        LunaHaptic.light()
                        isMuted.toggle()
                        player?.isMuted = isMuted
                    } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
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

            Spacer()

            // Center transport controls
            HStack(spacing: 52) {
                Button {
                    LunaHaptic.light()
                    seek(by: -10)
                    rescheduleHide()
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .contentShape(Rectangle())
                }
                .buttonStyle(LunaPressStyle())

                Button {
                    LunaHaptic.medium()
                    togglePlayback()
                    if isPlaying { rescheduleHide() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 70, height: 70)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(LunaPressStyle(scale: 0.92))

                Button {
                    LunaHaptic.light()
                    seek(by: 10)
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

            Spacer()

            // Bottom: seekbar + time + fullscreen
            VStack(spacing: 14) {
                // Seekbar
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        let totalWidth = geo.size.width
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: isScrubbing ? 6 : 4)
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: totalWidth * min(progress + 0.08, 1), height: isScrubbing ? 6 : 4)
                            Capsule()
                                .fill(LinearGradient.lunaAccentGradient)
                                .frame(width: totalWidth * progress, height: isScrubbing ? 6 : 4)
                            Circle()
                                .fill(Color.white)
                                .frame(width: isScrubbing ? 20 : 14, height: isScrubbing ? 20 : 14)
                                .shadow(color: .black.opacity(0.35), radius: 4)
                                .offset(x: totalWidth * progress - (isScrubbing ? 10 : 7))
                        }
                        .animation(.lunaSnappy, value: isScrubbing)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { val in
                                    if !isScrubbing {
                                        isScrubbing = true
                                        LunaHaptic.light()
                                        hideTask?.cancel()
                                    }
                                    let newProgress = max(0, min(1, val.location.x / totalWidth))
                                    progress = newProgress
                                }
                                .onEnded { _ in
                                    isScrubbing = false
                                    seekToProgress(progress)
                                    rescheduleHide()
                                }
                        )
                    }
                    .frame(height: 20)

                    HStack {
                        Text(timeString(from: progress * duration))
                            .font(LunaFont.mono(11))
                            .foregroundColor(.lunaTextSecondary)
                        Spacer()
                        Text("-" + timeString(from: (1 - progress) * duration))
                            .font(LunaFont.mono(11))
                            .foregroundColor(.lunaTextSecondary)
                    }
                }
                .padding(.horizontal, 20)

                // Bottom row
                HStack {
                    Button {} label: {
                        Label("Textning", systemImage: "captions.bubble.fill")
                            .font(LunaFont.caption())
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .buttonStyle(LunaPressStyle())

                    Spacer()

                    if content.type == .series {
                        Button { LunaHaptic.light() } label: {
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
                        Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
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
    }

    // MARK: - AVPlayer Setup

    private func setupPlayer() {
        if let playbackID = content.muxPlaybackID {
            let hlsURL = URL(string: "https://stream.mux.com/\(playbackID).m3u8")!
            let asset = AVURLAsset(url: hlsURL, options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true
            ])
            let item = AVPlayerItem(asset: asset)
            // Buffer 10 seconds ahead for lag-free playback
            item.preferredForwardBufferDuration = 10
            item.automaticallyPreservesTimeOffsetFromLive = false

            let avPlayer = AVPlayer(playerItem: item)
            avPlayer.automaticallyWaitsToMinimizeStalling = true
            avPlayer.isMuted = isMuted

            // Observe time
            let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak avPlayer] time in
                guard let avPlayer, let item = avPlayer.currentItem else { return }
                let d = item.duration.seconds
                guard d.isFinite, d > 0 else { return }
                DispatchQueue.main.async {
                    if !isScrubbing {
                        progress = time.seconds / d
                    }
                    duration = d
                }
            }

            player = avPlayer
            avPlayer.play()
        }
    }

    private func tearDownPlayer() {
        hideTask?.cancel()
        if let observer = timeObserver, let p = player {
            p.removeTimeObserver(observer)
        }
        player?.pause()
        player = nil
        timeObserver = nil
    }

    private func togglePlayback() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        withAnimation(.lunaSnappy) { isPlaying.toggle() }
    }

    private func seek(by seconds: Double) {
        guard let player else { return }
        let current = player.currentTime().seconds
        let target = max(0, min(duration, current + seconds))
        let time = CMTime(seconds: target, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func seekToProgress(_ p: Double) {
        guard let player else { return }
        let target = p * duration
        let time = CMTime(seconds: target, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func toggleFullscreen() {
        isFullscreen.toggle()
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let orientation: UIInterfaceOrientationMask = isFullscreen ? .landscapeRight : .portrait
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation)) { _ in }
    }

    // MARK: - Control timing

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(controlHideDelay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if isPlaying && !isScrubbing {
                    withAnimation(.easeInOut(duration: 0.4)) { showControls = false }
                }
            }
        }
    }

    private func rescheduleHide() {
        if showControls { scheduleHide() }
    }

    // MARK: - Time helpers

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

// MARK: - AVPlayer UIViewControllerRepresentable

struct AVPlayerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = false   // we use our own controls
        vc.videoGravity = .resizeAspect
        vc.view.backgroundColor = .black
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        vc.player = player
    }
}

// MARK: - Player Settings Sheet (unchanged)

struct PlayerSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let qualities  = ["Automatisk", "4K Ultra HD", "HD 1080p", "HD 720p", "SD"]
    let languages  = ["Svenska", "Engelska", "Norska", "Danska"]
    let subtitles  = ["Av", "Svenska", "Engelska"]

    @State private var selectedQuality = "HD 1080p"
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
