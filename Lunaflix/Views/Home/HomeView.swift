import SwiftUI

struct HomeView: View {
    @State private var vm = HomeViewModel()
    @EnvironmentObject var appState: AppState
    @State private var selectedContent: LunaContent? = nil
    @State private var scrollOffset: CGFloat = 0
    @State private var showUpload = false

    private var showNavBackground: Bool { scrollOffset > 240 }

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.top ?? 44
    }

    var body: some View {
        @Bindable var vm = vm
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
                        .frame(height: UIScreen.main.bounds.height * 0.40)
                    } else {
                        heroSkeleton
                    }

                    // Content categories
                    VStack(spacing: 0) {
                        if vm.isLoading {
                            skeletonRows
                        } else {
                            ForEach(Array(vm.categories.enumerated()), id: \.element.id) { index, category in
                                ContentRowView(
                                    category: category,
                                    onTap: { selectedContent = $0 }
                                )
                                .padding(.bottom, 8)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .animation(
                                    .easeOut(duration: 0.4).delay(Double(index) * 0.06),
                                    value: vm.isLoading
                                )
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: -geo.frame(in: .named("homeScroll")).minY
                        )
                    }
                )
            }
            .coordinateSpace(name: "homeScroll")
            .ignoresSafeArea(edges: .top)
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                scrollOffset = value
            }
            .refreshable {
                await withCheckedContinuation { continuation in
                    vm.refresh()
                    // Give the load task a moment to fire, then resolve
                    Task {
                        try? await Task.sleep(for: .milliseconds(800))
                        continuation.resume()
                    }
                }
            }

            // Navigation bar — always present, background fades in on scroll
            navigationBar
        }
        .sheet(item: $selectedContent) { content in
            ContentDetailView(content: content)
        }
        .sheet(isPresented: $showUpload, onDismiss: {
            // Refresh library so any newly uploaded video appears
            vm.refreshAfterUpload()
        }) {
            UploadView()
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack(spacing: 0) {
            // Logo — always visible
            HStack(spacing: 5) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
                Text("Lunaflix")
                    .font(LunaFont.title2())
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
            }

            Spacer()

            HStack(spacing: 14) {
                Button {
                    LunaHaptic.medium()
                    showUpload = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(showNavBackground ? .lunaTextSecondary : .white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(LunaPressStyle())

                Button {
                    LunaHaptic.light()
                    withAnimation(.lunaSnappy) {
                        appState.selectedTab = .search
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(showNavBackground ? .lunaTextSecondary : .white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(LunaPressStyle())

                // User avatar
                Circle()
                    .fill(LinearGradient.lunaAccentGradient)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Text("L")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    )
                    .lunaGlow(color: .lunaAccent, radius: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, safeAreaTop + 8)
        .padding(.bottom, 10)
        .background(
            ZStack {
                // Always: subtle gradient so logo is readable against hero
                if !showNavBackground {
                    LinearGradient(
                        colors: [Color.black.opacity(0.4), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                }

                // On scroll: frosted glass
                if showNavBackground {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .top)
                        .overlay(
                            Rectangle()
                                .fill(Color.lunaBackground.opacity(0.65))
                                .ignoresSafeArea(edges: .top)
                        )
                        .transition(.opacity)
                }
            }
            .animation(.lunaSmooth, value: showNavBackground)
        )
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Skeleton Views

    private var heroSkeleton: some View {
        Rectangle()
            .fill(Color.lunaCard)
            .frame(height: UIScreen.main.bounds.height * 0.40)
            .shimmering()
    }

    private var skeletonRows: some View {
        VStack(alignment: .leading, spacing: 28) {
            // Wide card row skeleton
            VStack(alignment: .leading, spacing: 12) {
                skeletonLabel(width: 160)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.lunaCard)
                                .frame(width: 240, height: 135)
                                .cornerRadius(12)
                                .shimmering()
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            // Standard poster row skeleton
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 12) {
                    skeletonLabel(width: 120)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(0..<6, id: \.self) { _ in
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
        .transition(.opacity.animation(.easeIn(duration: 0.3)))
    }

    private func skeletonLabel(width: CGFloat) -> some View {
        Rectangle()
            .fill(Color.lunaElevated)
            .frame(width: width, height: 16)
            .cornerRadius(5)
            .padding(.horizontal, 16)
            .shimmering()
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
                        Color.white.opacity(0.02),
                        Color.white.opacity(0.10),
                        Color.white.opacity(0.02)
                    ],
                    startPoint: .init(x: phase - 0.4, y: 0),
                    endPoint: .init(x: phase + 0.4, y: 0)
                )
                .blendMode(.plusLighter)
                .onAppear {
                    withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                        phase = 1.4
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
