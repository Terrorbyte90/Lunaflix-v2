import SwiftUI

struct HeroCarouselView: View {
    let contents: [LunaContent]
    @Binding var currentIndex: Int
    let onSelect: (Int) -> Void
    let onTap: (LunaContent) -> Void

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
            .onChange(of: currentIndex) { newVal in
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
        VStack(alignment: .leading, spacing: 10) {
            // Genre chips
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

            // Title
            Text(content.title)
                .font(LunaFont.hero())
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.6), radius: 10, x: 0, y: 2)
                .padding(.horizontal, 16)

            // Meta info row
            HStack(spacing: 8) {
                // Rating badge
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

                Text(content.metaString)
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaTextSecondary)
            }
            .padding(.horizontal, 16)

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

                // Watchlist
                Button {
                    LunaHaptic.light()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(LunaPressStyle())
            }
            .padding(.horizontal, 16)

            // Page dots
            HStack(spacing: 5) {
                ForEach(0..<contents.count, id: \.self) { i in
                    Capsule()
                        .fill(i == currentIndex ? Color.white : Color.white.opacity(0.25))
                        .frame(width: i == currentIndex ? 18 : 5, height: 5)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
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

    var body: some View {
        ZStack {
            // Background
            content.heroGradient.gradient
                .ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                // Ambient glow
                Circle()
                    .fill(content.heroGradient.accentColor.opacity(0.18))
                    .frame(width: w * 0.9)
                    .blur(radius: 55)
                    .offset(x: w * 0.1, y: -h * 0.12)

                Circle()
                    .fill(Color.white.opacity(0.03))
                    .frame(width: w * 0.45)
                    .offset(x: -w * 0.08, y: h * 0.18)

                // Spotlight
                RadialGradient(
                    colors: [content.heroGradient.accentColor.opacity(0.18), .clear],
                    center: .init(x: 0.72, y: 0.28),
                    startRadius: 0,
                    endRadius: w * 0.55
                )
                .frame(width: w, height: h)

                // Deterministic grain texture
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

            // Bottom readability gradient
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        .clear,
                        Color.lunaBackground.opacity(0.2),
                        Color.lunaBackground.opacity(0.75),
                        Color.lunaBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: UIScreen.main.bounds.height * 0.52)
            }

            // Watermark letter — decorative
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(content.title.prefix(1))
                        .font(.system(size: 190, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.035))
                        .offset(x: 24, y: 36)
                }
            }
        }
        .onTapGesture(perform: onTap)
        .contentShape(Rectangle())
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
