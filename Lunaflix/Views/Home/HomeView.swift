import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @State private var selectedContent: LunaContent? = nil
    @State private var scrollOffset: CGFloat = 0
    @State private var showNavBar = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.lunaBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // Hero Carousel
                    if !vm.heroContents.isEmpty {
                        HeroCarouselView(
                            contents: vm.heroContents,
                            currentIndex: $vm.currentHeroIndex,
                            onSelect: { vm.selectHero($0) },
                            onTap: { selectedContent = $0 }
                        )
                        .frame(height: UIScreen.main.bounds.height * 0.62)
                    } else {
                        heroSkeleton
                    }

                    // Content categories
                    VStack(spacing: 0) {
                        if vm.isLoading {
                            skeletonRows
                        } else {
                            ForEach(vm.categories) { category in
                                ContentRowView(
                                    category: category,
                                    onTap: { selectedContent = $0 }
                                )
                                .padding(.bottom, 8)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 120) // Tab bar clearance
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: -geo.frame(in: .named("scroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                withAnimation(.lunaSnappy) {
                    showNavBar = value > 300
                }
                scrollOffset = value
            }

            // Navigation bar (appears on scroll)
            navigationBar
        }
        .sheet(item: $selectedContent) { content in
            ContentDetailView(content: content)
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            // Logo
            HStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
                Text("Lunaflix")
                    .font(LunaFont.title2())
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
            }

            Spacer()

            HStack(spacing: 16) {
                Button {
                    // Cast action
                } label: {
                    Image(systemName: "tv.badge.wifi")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.lunaTextSecondary)
                }

                Button {
                    // Search shortcut
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.lunaTextSecondary)
                }

                // User avatar
                Circle()
                    .fill(LinearGradient.lunaAccentGradient)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("L")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                if showNavBar {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .top)
                        .overlay(
                            Rectangle()
                                .fill(Color.lunaBackground.opacity(0.7))
                                .ignoresSafeArea(edges: .top)
                        )
                        .transition(.opacity)
                }
            }
        )
        .padding(.top, 0)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Skeleton Views

    private var heroSkeleton: some View {
        Rectangle()
            .fill(Color.lunaCard)
            .frame(height: UIScreen.main.bounds.height * 0.62)
            .shimmering()
    }

    private var skeletonRows: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    Rectangle()
                        .fill(Color.lunaCard)
                        .frame(width: 160, height: 20)
                        .cornerRadius(4)
                        .shimmering()

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(0..<5, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.lunaCard)
                                    .frame(width: 120, height: 180)
                                    .cornerRadius(10)
                                    .shimmering()
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .padding(.top, 16)
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.03),
                        Color.white.opacity(0.12),
                        Color.white.opacity(0.03)
                    ],
                    startPoint: .init(x: phase - 0.3, y: 0),
                    endPoint: .init(x: phase + 0.3, y: 0)
                )
                .blendMode(.plusLighter)
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 1.3
                    }
                }
            )
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
}
