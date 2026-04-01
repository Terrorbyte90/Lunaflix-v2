import SwiftUI

struct LunaTabBar: View {
    @Binding var selectedTab: Tab
    @Namespace private var namespace
    @ObservedObject private var um = UploadManager.shared
    @ObservedObject private var dm = DownloadManager.shared

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                tabItem(tab)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                Rectangle()
                    .fill(Color.lunaBackground.opacity(0.80))
            }
            .ignoresSafeArea()
        )
        // Top separator: a hairline with a subtle centre-glow
        .overlay(
            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)
                // Centre glow
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color.lunaAccent.opacity(0.35), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            },
            alignment: .top
        )
    }

    private func badgeCount(for tab: Tab) -> Int {
        switch tab {
        case .home:
            // No badge on home
            return 0
        case .downloads:
            // Show active downloads + uploads count
            let downloadCount = dm.downloads.filter { !$0.isReady && $0.errorMessage == nil }.count
            let uploadCount = um.activeCount
            return downloadCount + uploadCount
        default:
            return 0
        }
    }

    private func tabItem(_ tab: Tab) -> some View {
        Button {
            if selectedTab != tab {
                LunaHaptic.selection()
            }
            withAnimation(.lunaSnappy) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    // Animated pill background
                    if selectedTab == tab {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.lunaAccent.opacity(0.28),
                                        Color.lunaAccentLight.opacity(0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 34)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.lunaAccentLight.opacity(0.20), lineWidth: 1)
                            )
                            .matchedGeometryEffect(id: "tab_bg", in: namespace)
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: selectedTab == tab ? .bold : .regular))
                        .foregroundStyle(
                            selectedTab == tab
                            ? AnyShapeStyle(LinearGradient.lunaAccentGradient)
                            : AnyShapeStyle(Color.lunaTextMuted)
                        )
                        .frame(width: 52, height: 34)
                        .overlay(alignment: .topTrailing) {
                            let count = badgeCount(for: tab)
                            if count > 0 {
                                ZStack {
                                    Circle()
                                        .fill(Color.lunaAccent)
                                        .frame(width: 16, height: 16)
                                    Text("\(count)")
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                .offset(x: 4, y: -4)
                                .transition(.scale.combined(with: .opacity))
                                .animation(.lunaSpring, value: count)
                            }
                        }
                }

                Text(tab.title)
                    .font(LunaFont.tag())
                    .foregroundColor(selectedTab == tab ? .lunaAccentLight : .lunaTextMuted)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.lunaBackground.ignoresSafeArea()
        VStack {
            Spacer()
            LunaTabBar(selectedTab: .constant(.home))
        }
    }
}
