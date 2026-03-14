import SwiftUI

struct PlayerView: View {
    let content: LunaContent
    @Environment(\.dismiss) private var dismiss

    @State private var isPlaying = true
    @State private var showControls = true
    @State private var progress: Double = 0.15
    @State private var isMuted = false
    @State private var showSettings = false
    @State private var isScrubbing = false

    // Cancellable auto-hide task
    @State private var hideTask: Task<Void, Never>? = nil

    private let controlHideDelay: TimeInterval = 3.5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Video background (gradient stand-in)
            ZStack {
                content.heroGradient.gradient
                    .ignoresSafeArea()

                GeometryReader { geo in
                    Circle()
                        .fill(content.heroGradient.accentColor.opacity(0.18))
                        .frame(width: geo.size.width * 0.9)
                        .blur(radius: 80)
                        .position(x: geo.size.width * 0.6, y: geo.size.height * 0.4)
                }

                // Dimming overlay for readability
                Color.black
                    .opacity(showControls ? 0.55 : 0.08)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.3), value: showControls)
            }

            // Controls overlay
            controls
                .opacity(showControls ? 1 : 0)
                .animation(.easeInOut(duration: 0.25), value: showControls)
                .allowsHitTesting(showControls)

            // Paused indicator (only when paused AND controls hidden)
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
            if showControls {
                scheduleHide()
            }
        }
        .onAppear { scheduleHide() }
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
                        Text("S1 • E3 • Avslöjandet")
                            .font(LunaFont.caption())
                            .foregroundColor(.lunaTextSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        LunaHaptic.light()
                        isMuted.toggle()
                    } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(LunaPressStyle())

                    Button {
                        showSettings = true
                    } label: {
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

            // Center play controls
            HStack(spacing: 52) {
                Button {
                    LunaHaptic.light()
                    progress = max(0, progress - 0.1)
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
                    withAnimation(.lunaSnappy) { isPlaying.toggle() }
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
                    progress = min(1, progress + 0.1)
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

            // Bottom: seekbar + time + actions
            VStack(spacing: 14) {
                // Seekbar
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        let totalWidth = geo.size.width

                        ZStack(alignment: .leading) {
                            // Track background
                            Capsule()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: isScrubbing ? 6 : 4)

                            // Buffered
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: totalWidth * min(progress + 0.15, 1), height: isScrubbing ? 6 : 4)

                            // Played
                            Capsule()
                                .fill(LinearGradient.lunaAccentGradient)
                                .frame(width: totalWidth * progress, height: isScrubbing ? 6 : 4)

                            // Scrubber thumb
                            Circle()
                                .fill(Color.white)
                                .frame(
                                    width: isScrubbing ? 20 : 14,
                                    height: isScrubbing ? 20 : 14
                                )
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
                                    progress = max(0, min(1, val.location.x / totalWidth))
                                }
                                .onEnded { _ in
                                    isScrubbing = false
                                    rescheduleHide()
                                }
                        )
                    }
                    .frame(height: 20)

                    // Time labels
                    HStack {
                        Text(timeString(from: progress * totalSeconds))
                            .font(LunaFont.mono(11))
                            .foregroundColor(.lunaTextSecondary)
                        Spacer()
                        Text("-" + timeString(from: (1 - progress) * totalSeconds))
                            .font(LunaFont.mono(11))
                            .foregroundColor(.lunaTextSecondary)
                    }
                }
                .padding(.horizontal, 20)

                // Bottom action row
                HStack {
                    Button {} label: {
                        Label("Textning", systemImage: "captions.bubble.fill")
                            .font(LunaFont.caption())
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .buttonStyle(LunaPressStyle())

                    Spacer()

                    if content.type == .series {
                        Button {
                            LunaHaptic.light()
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

                    Button {} label: {
                        Label("AirPlay", systemImage: "airplayvideo")
                            .font(LunaFont.caption())
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .buttonStyle(LunaPressStyle())
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 50)
        }
    }

    // MARK: - Helpers

    private var totalSeconds: Double {
        if content.duration.contains("t") {
            let parts = content.duration.components(separatedBy: "t ")
            let hours = Double(parts[0].trimmingCharacters(in: .whitespaces)) ?? 0
            let minStr = parts.last?.replacingOccurrences(of: "min", with: "").trimmingCharacters(in: .whitespaces)
            let mins = Double(minStr ?? "0") ?? 0
            return (hours * 60 + mins) * 60
        }
        return 5400
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

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(controlHideDelay))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if isPlaying && !isScrubbing {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showControls = false
                    }
                }
            }
        }
    }

    private func rescheduleHide() {
        if showControls { scheduleHide() }
    }
}

// MARK: - Player Settings Sheet

struct PlayerSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let qualities = ["Automatisk", "4K Ultra HD", "HD 1080p", "HD 720p", "SD"]
    let languages = ["Svenska", "Engelska", "Norska", "Danska"]
    let subtitles = ["Av", "Svenska", "Engelska"]

    @State private var selectedQuality = "HD 1080p"
    @State private var selectedLang = "Svenska"
    @State private var selectedSub = "Av"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lunaSurface.ignoresSafeArea()

                List {
                    settingsSection("Kvalitet", options: qualities, selected: $selectedQuality)
                    settingsSection("Ljud", options: languages, selected: $selectedLang)
                    settingsSection("Textning", options: subtitles, selected: $selectedSub)
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
                        Text(opt)
                            .foregroundColor(.lunaTextPrimary)
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
