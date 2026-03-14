import SwiftUI

struct LunaTabBar: View {
    @Binding var selectedTab: Tab
    @Namespace private var namespace

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
                    .fill(Color.lunaBackground.opacity(0.75))
            }
            .ignoresSafeArea()
        )
        .overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.lunaAccent.opacity(0.15), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1),
            alignment: .top
        )
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
                    if selectedTab == tab {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.lunaAccent.opacity(0.18))
                            .frame(width: 48, height: 32)
                            .matchedGeometryEffect(id: "tab_bg", in: namespace)
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: selectedTab == tab ? .bold : .regular))
                        .foregroundStyle(
                            selectedTab == tab
                            ? AnyShapeStyle(LinearGradient.lunaAccentGradient)
                            : AnyShapeStyle(Color.lunaTextMuted)
                        )
                        .frame(width: 48, height: 32)
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
