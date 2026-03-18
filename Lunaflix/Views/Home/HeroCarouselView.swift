import SwiftUI

struct HeroCarouselView: View {
    let contents: [LunaContent]
    @Binding var currentIndex: Int
    let onSelect: (Int) -> Void
    let onTap: (LunaContent) -> Void

    @State private var watchlistIDs: Set<UUID> = []

    var body: some View {
        ZStack(alignment: .bottom) {
            // Hero pages
            TabView(selection: $currentIndex) {
                ForEach(Array(contents.enumerated()), id: \.element.id) { index, content in
                    HeroCard(content: content, onTap: { onTap(content) })
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentIndex) { _, newVal in
                LunaHaptic.light()
                onSelect(newVal)
            }

            // Info overlay (slides with content change)
            if let hero = contents[safe: currentIndex] {
                heroInfoOverlay(hero)
                    .transition(.opacity)
                    .id(hero.id)
                    .animation(.lunaSmooth, value: currentIndex)
            }
        }
        .clipped()
    }

    @ViewBuilder
    private func heroInfoOverlay(_ content: LunaContent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            // Luna age badge — the emotional centrepiece of this family app
            if let age = content.lunaAgeAtRecording {
                HStack(spacing: 5) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.lunaWarm)
                    Text(age)
                        .font(LunaFont.tag())
                        .foregroundColor(.lunaWarm)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial.opacity(0.8))
                .background(Color.lunaWarm.opacity(0.08))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.lunaWarm.opacity(0.25), lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            } else if !content.genre.isEmpty {
                // Genre chips (only shown if content has genres)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(content.genre, id: \.rawValue) { genre in
                            Text(genre.displayName)
                                .font(LunaFont.tag())
                                .foregroundColor(content.heroGradient.accentColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(content.heroGradient.accentColor.opacity(0.15))
                                .cornerRadius(20)
                                .overlay(
                                    Capsule()
                                        .stroke(content.heroGradient.accentColor.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)
            }

            // Title
            Text(content.title)
                .font(LunaFont.hero())
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.7), radius: 12, x: 0, y: 3)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            // Meta info row
            HStack(spacing: 8) {
                if content.rating > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.lunaGold)
                        Text(String(format: "%.1f", content.rating))
                            .font(LunaFont.mono(12))
                            .foregroundColor(.lunaGold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.lunaGold.opacity(0.12))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.lunaGold.opacity(0.25), lineWidth: 1))

                    Text("•")
                        .foregroundColor(.lunaTextMuted)
                        .font(LunaFont.caption())
                }

                Text(content.metaString)
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            // Action buttons
            HStack(spacing: 10) {
                Button {
                    LunaHaptic.medium()
                    onTap(content)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text(content.isContinuing ? "Fortsätt" : "Spela")
                            .fontWeight(.bold)
                    }
                    .accentButton()
                }
                .buttonStyle(LunaPressStyle(scale: 0.97))
                .lunaGlow()

                Button {
                    onTap(content)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                        Text("Info")
                    }
                    .secondaryButton()
                }
                .buttonStyle(LunaPressStyle(scale: 0.97))

                Spacer()

                // Watchlist toggle
                Button {
                    LunaHaptic.light()
                    withAnimation(.lunaSpring) {
                        if watchlistIDs.contains(content.id) {
                            watchlistIDs.remove(content.id)
                        } else {
                            watchlistIDs.insert(content.id)
                        }
                    }
                } label: {
                    let inList = watchlistIDs.contains(content.id)
                    Image(systemName: inList ? "checkmark" : "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(inList ? .lunaAccentLight : .white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(
                            inList ? Color.lunaAccentLight.opacity(0.4) : Color.white.opacity(0.15),
                            lineWidth: 1
                        ))
                }
                .buttonStyle(LunaPressStyle())
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            // Page dots
            HStack(spacing: 5) {
                ForEach(0..<contents.count, id: \.self) { i in
                    Capsule()
                        .fill(i == currentIndex ? Color.white : Color.white.opacity(0.25))
                        .frame(width: i == currentIndex ? 20 : 5, height: 5)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .animation(.lunaSnappy, value: currentIndex)
        }
    }
}

// MARK: - Hero Card

// Deterministic "grain" pattern using a fixed seed to avoid re-rendering flicker
private let heroGrainDots: [(CGFloat, CGFloat, CGFloat, Double)] = {
    var rng = SeededRNG(seed: 42)
    return (0..<60).map { _ in
        (rng.next(in: 0...1), rng.next(in: 0...1), rng.next(in: 0.5...2), rng.next(in: 0.02...0.07))
    }
}()

struct HeroCard: View {
    let content: LunaContent
    let onTap: () -> Void

    private var thumbnailURL: URL? {
        guard let pid = content.muxPlaybackID else { return nil }
        // Mux animated GIF thumbnail for hero gives motion feel; fallback to static
        return URL(string: "https://image.mux.com/\(pid)/thumbnail.jpg?width=800&height=450&fit_mode=smartcrop&time=2")
    }

    var body: some View {
        ZStack {
            // Background — real thumbnail or gradient fallback
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                if let url = thumbnailURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: w, height: h)
                                .clipped()
                                // Slight color tint so UI text stays readable
                                .overlay(
                                    content.heroGradient.gradient
                                        .opacity(0.45)
                                        .ignoresSafeArea()
                                )
                        default:
                            // Gradient while loading
                            ZStack {
                                content.heroGradient.gradient.ignoresSafeArea()
                                gradientDecoration(w: w, h: h)
                            }
                        }
                    }
                } else {
                    ZStack {
                        content.heroGradient.gradient.ignoresSafeArea()
                        gradientDecoration(w: w, h: h)
                    }
                }
            }
            .ignoresSafeArea()

            // Bottom readability gradient — tall enough for the info overlay
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        .clear,
                        Color.lunaBackground.opacity(0.15),
                        Color.lunaBackground.opacity(0.75),
                        Color.lunaBackground.opacity(0.95),
                        Color.lunaBackground
                    ],
                    startPoint: .init(x: 0.5, y: 0),
                    endPoint: .bottom
                )
                .frame(height: UIScreen.main.bounds.height * 0.60)
            }
        }
        .onTapGesture(perform: onTap)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func gradientDecoration(w: CGFloat, h: CGFloat) -> some View {
        Circle()
            .fill(content.heroGradient.accentColor.opacity(0.18))
            .frame(width: w * 0.9)
            .blur(radius: 55)
            .offset(x: w * 0.1, y: -h * 0.12)

        // Grain texture
        Canvas { ctx, size in
            for (nx, ny, r, op) in heroGrainDots {
                let x = nx * size.width
                let y = ny * size.height
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                    with: .color(.white.opacity(op))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Seeded RNG (deterministic grain)

private struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next(in range: ClosedRange<CGFloat>) -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let t = state >> 33
        let fraction = CGFloat(t) / CGFloat(UInt32.max)
        return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let t = state >> 33
        let fraction = Double(t) / Double(UInt32.max)
        return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
    }
}
