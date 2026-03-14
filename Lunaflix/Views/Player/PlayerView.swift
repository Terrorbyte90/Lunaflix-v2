import SwiftUI

struct PlayerView: View {
    let content: LunaContent
    @Environment(\.dismiss) private var dismiss

    @State private var isPlaying = true
    @State private var showControls = true
    @State private var progress: Double = 0.15
    @State private var isMuted = false
    @State private var showSettings = false
    @GestureState private var isDragging = false

    private let controlHideDelay: TimeInterval = 3

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Video background (gradient placeholder)
            GeometryReader { geo in
                ZStack {
                    content.heroGradient.gradient
                        .ignoresSafeArea()

                    // Simulated video content
                    Circle()
                        .fill(content.heroGradient.accentColor.opacity(0.15))
                        .frame(width: geo.size.width * 0.8)
                        .blur(radius: 80)
                        .position(x: geo.size.width * 0.6, y: geo.size.height * 0.4)

                    // Subtle overlay
                    Color.black.opacity(showControls ? 0.5 : 0.1)
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.25), value: showControls)
                }
            }

            // Controls overlay
            if showControls {
                controls
                    .transition(.opacity)
            }

            // Loading indicator when not playing
            if !isPlaying {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .offset(x: 3)
                    )
            }
        }
        .statusBarHidden()
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls.toggle()
            }
            if showControls {
                autoHideControls()
            }
        }
        .onAppear { autoHideControls() }
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
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(content.title)
                        .font(LunaFont.body())
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    if content.type == .series {
                        Text("S1 • E3 • Avslöjandet")
                            .font(LunaFont.caption())
                            .foregroundColor(.lunaTextSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    Button { isMuted.toggle() } label: {
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }

                    Button { showSettings = true } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 54)

            Spacer()

            // Center play controls
            HStack(spacing: 50) {
                Button {
                    progress = max(0, progress - 0.1)
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(.white)
                }

                Button {
                    withAnimation(.lunaSnappy) {
                        isPlaying.toggle()
                    }
                    if isPlaying { autoHideControls() }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.white)
                }

                Button {
                    progress = min(1, progress + 0.1)
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            // Bottom: progress bar + time
            VStack(spacing: 12) {
                // Seekbar
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Background track
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 4)

                            // Buffered (slightly lighter)
                            Capsule()
                                .fill(Color.white.opacity(0.35))
                                .frame(width: geo.size.width * min(progress + 0.15, 1), height: 4)

                            // Played
                            Capsule()
                                .fill(LinearGradient.lunaAccentGradient)
                                .frame(width: geo.size.width * progress, height: 4)

                            // Scrubber
                            Circle()
                                .fill(Color.white)
                                .frame(width: 16, height: 16)
                                .shadow(color: .black.opacity(0.3), radius: 4)
                                .offset(x: geo.size.width * progress - 8)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { val in
                                    progress = max(0, min(1, val.location.x / geo.size.width))
                                }
                        )
                    }
                    .frame(height: 20)

                    // Time labels
                    HStack {
                        Text(timeString(from: progress * totalSeconds))
                            .font(LunaFont.caption())
                            .foregroundColor(.lunaTextSecondary)
                        Spacer()
                        Text(timeString(from: totalSeconds))
                            .font(LunaFont.caption())
                            .foregroundColor(.lunaTextSecondary)
                    }
                }
                .padding(.horizontal, 16)

                // Bottom actions
                HStack {
                    // Subtitle button
                    Button {} label: {
                        Label("Textning", systemImage: "captions.bubble")
                            .font(LunaFont.caption())
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()

                    // Next episode
                    if content.type == .series {
                        Button {} label: {
                            HStack(spacing: 4) {
                                Text("Nästa avsnitt")
                                    .font(LunaFont.caption())
                                Image(systemName: "forward.end.fill")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    Spacer()

                    // Airplay
                    Button {} label: {
                        Label("AirPlay", systemImage: "airplayvideo")
                            .font(LunaFont.caption())
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 44)
        }
    }

    private var totalSeconds: Double {
        // Parse "1t 45min" -> seconds
        if content.duration.contains("t") {
            let parts = content.duration.components(separatedBy: "t ")
            let hours = Double(parts[0].trimmingCharacters(in: .whitespaces)) ?? 0
            let minPart = parts.last?.replacingOccurrences(of: "min", with: "").trimmingCharacters(in: .whitespaces)
            let mins = Double(minPart ?? "0") ?? 0
            return (hours * 60 + mins) * 60
        }
        return 5400
    }

    private func timeString(from seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    private func autoHideControls() {
        DispatchQueue.main.asyncAfter(deadline: .now() + controlHideDelay) {
            withAnimation(.easeInOut(duration: 0.4)) {
                if isPlaying { showControls = false }
            }
        }
    }
}

// MARK: - Settings Sheet

struct PlayerSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    let qualities = ["Automatisk", "4K Ultra HD", "HD 1080p", "HD 720p", "SD"]
    let languages = ["Svenska", "Engelska", "Norska", "Danska"]
    let subtitles = ["Av", "Svenska", "Engelska"]

    @State private var selectedQuality = "HD 1080p"
    @State private var selectedLang = "Svenska"
    @State private var selectedSub = "Av"

    var body: some View {
        NavigationView {
            ZStack {
                Color.lunaSurface.ignoresSafeArea()
                List {
                    settingsSection(title: "Kvalitet", options: qualities, selected: $selectedQuality)
                    settingsSection(title: "Ljud", options: languages, selected: $selectedLang)
                    settingsSection(title: "Textning", options: subtitles, selected: $selectedSub)
                }
                .scrollContentBackground(.hidden)
                .background(Color.lunaSurface)
            }
            .navigationTitle("Inställningar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Klar") { dismiss() }
                        .foregroundColor(.lunaAccentLight)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func settingsSection(title: String, options: [String], selected: Binding<String>) -> some View {
        Section(title) {
            ForEach(options, id: \.self) { opt in
                Button {
                    selected.wrappedValue = opt
                } label: {
                    HStack {
                        Text(opt)
                            .foregroundColor(.lunaTextPrimary)
                        Spacer()
                        if selected.wrappedValue == opt {
                            Image(systemName: "checkmark")
                                .foregroundColor(.lunaAccentLight)
                        }
                    }
                }
                .listRowBackground(Color.lunaCard)
            }
        }
    }
}
