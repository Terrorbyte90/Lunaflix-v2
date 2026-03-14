import SwiftUI

struct HeroCarouselView: View {
    let contents: [LunaContent]
    @Binding var currentIndex: Int
    let onSelect: (Int) -> Void
    let onTap: (LunaContent) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var animating = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Hero cards with paging
            TabView(selection: $currentIndex) {
                ForEach(Array(contents.enumerated()), id: \.element.id) { index, content in
                    HeroCard(content: content, onTap: { onTap(content) })
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: currentIndex) { _, newVal in
                onSelect(newVal)
            }

            // Bottom gradient + info overlay
            VStack(spacing: 0) {
                Spacer()

                if let hero = contents[safe: currentIndex] {
                    heroInfoOverlay(hero)
                }
            }
        }
        .clipped()
    }

    @ViewBuilder
    private func heroInfoOverlay(_ content: LunaContent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Genre chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
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
            }
            .padding(.leading, 16)

            // Title
            Text(content.title)
                .font(LunaFont.hero())
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 8)
                .padding(.horizontal, 16)

            // Meta info
            HStack(spacing: 12) {
                Text(String(format: "%.1f", content.rating))
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaGold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.lunaGold.opacity(0.15))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.lunaGold.opacity(0.3), lineWidth: 1))

                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.lunaGold)

                Text(content.metaString)
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaTextSecondary)
            }
            .padding(.horizontal, 16)

            // Action buttons
            HStack(spacing: 12) {
                Button { onTap(content) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                        Text(content.isContinuing ? "Fortsätt" : "Spela")
                    }
                    .accentButton()
                }
                .lunaGlow()

                Button { onTap(content) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                        Text("Info")
                    }
                    .secondaryButton()
                }

                Spacer()

                // Watchlist button
                Button {} label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.lunaElevated)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                }
            }
            .padding(.horizontal, 16)

            // Dot indicators
            HStack(spacing: 6) {
                ForEach(0..<contents.count, id: \.self) { i in
                    Capsule()
                        .fill(i == currentIndex ? Color.white : Color.white.opacity(0.3))
                        .frame(width: i == currentIndex ? 20 : 6, height: 6)
                        .animation(.lunaSnappy, value: currentIndex)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .animation(.lunaSmooth, value: content.id)
    }
}

// MARK: - Hero Card (single page)

struct HeroCard: View {
    let content: LunaContent
    let onTap: () -> Void

    var body: some View {
        ZStack {
            // Background gradient
            content.heroGradient.gradient
                .ignoresSafeArea()

            // Decorative elements
            GeometryReader { geo in
                Circle()
                    .fill(content.heroGradient.accentColor.opacity(0.15))
                    .frame(width: geo.size.width * 0.9)
                    .blur(radius: 60)
                    .offset(x: geo.size.width * 0.1, y: -geo.size.height * 0.15)

                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: -geo.size.width * 0.1, y: geo.size.height * 0.2)

                // Radial "spotlight" effect
                RadialGradient(
                    colors: [content.heroGradient.accentColor.opacity(0.2), .clear],
                    center: .init(x: 0.7, y: 0.3),
                    startRadius: 0,
                    endRadius: geo.size.width * 0.6
                )
                .frame(width: geo.size.width, height: geo.size.height)

                // Subtle grain texture via small dots
                Canvas { ctx, size in
                    for _ in 0..<50 {
                        let x = CGFloat.random(in: 0...size.width)
                        let y = CGFloat.random(in: 0...size.height)
                        let r = CGFloat.random(in: 0.5...2)
                        let opacity = Double.random(in: 0.02...0.08)
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                            with: .color(.white.opacity(opacity))
                        )
                    }
                }
                .allowsHitTesting(false)
            }

            // Bottom overlay for text readability
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.lunaBackground.opacity(0.3), Color.lunaBackground.opacity(0.8), Color.lunaBackground],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: UIScreen.main.bounds.height * 0.55)
            }

            // Large decorative title watermark
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(content.title.prefix(1))
                        .font(.system(size: 200, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.04))
                        .offset(x: 30, y: 40)
                }
            }
        }
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
