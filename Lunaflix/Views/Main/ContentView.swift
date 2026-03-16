import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedContent: LunaContent? = nil
    @State private var showSplash = true
    @State private var showUpload = false

    var body: some View {
        ZStack {
            Color.lunaBackground.ignoresSafeArea()

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(10)
            } else {
                mainContent
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showSplash = false
                }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showSplash)
        .sheet(isPresented: $showUpload) {
            UploadView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openUploadSheet)) { _ in
            showUpload = true
        }
    }

    // MARK: - Main Content (tabs)

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            Color.lunaBackground.ignoresSafeArea()

            Group {
                switch appState.selectedTab {
                case .home:
                    HomeView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)),
                            removal: .opacity
                        ))
                case .search:
                    SearchView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity
                        ))
                case .downloads:
                    DownloadsView()
                        .transition(.opacity)
                case .profile:
                    ProfileView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity
                        ))
                }
            }
            .animation(.lunaSmooth, value: appState.selectedTab)

            // Upload FAB (only when Mux is configured)
            if KeychainService.hasMuxCredentials {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            LunaHaptic.medium()
                            showUpload = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient.lunaAccentGradient)
                                    .frame(width: 52, height: 52)
                                    .shadow(color: Color.lunaAccent.opacity(0.45), radius: 12, x: 0, y: 4)
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(LunaPressStyle(scale: 0.93))
                        .padding(.trailing, 20)
                        .padding(.bottom, 100)
                    }
                }
            }

            // Custom tab bar
            VStack(spacing: 0) {
                Spacer()
                LunaTabBar(selectedTab: $appState.selectedTab)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Splash Screen

struct SplashView: View {
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20

    var body: some View {
        ZStack {
            Color.lunaBackground.ignoresSafeArea()

            // Background glow
            RadialGradient(
                colors: [
                    Color.lunaAccent.opacity(0.3 * glowOpacity),
                    Color.lunaBackground
                ],
                center: .center,
                startRadius: 0,
                endRadius: 280
            )
            .ignoresSafeArea()
            .animation(.easeOut(duration: 1.0), value: glowOpacity)

            VStack(spacing: 14) {
                // Moon icon
                ZStack {
                    Circle()
                        .fill(LinearGradient.lunaAccentGradient)
                        .frame(width: 80, height: 80)
                        .opacity(opacity)

                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(opacity)
                }
                .scaleEffect(scale)
                .lunaGlow(color: .lunaAccent, radius: 24 * glowOpacity)

                VStack(spacing: 4) {
                    Text("Lunaflix")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient.lunaAccentGradient)
                        .opacity(opacity)
                        .offset(y: titleOffset)

                    Text("Lunas videoarkiv")
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextMuted)
                        .opacity(opacity * 0.7)
                        .offset(y: titleOffset)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
                titleOffset = 0
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                glowOpacity = 1.0
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openUploadSheet = Notification.Name("LunaOpenUploadSheet")
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
