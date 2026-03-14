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
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                Rectangle()
                    .fill(Color.lunaBackground.opacity(0.8))
            }
            .ignoresSafeArea()
        )
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1),
            alignment: .top
        )
    }

    private func tabItem(_ tab: Tab) -> some View {
        Button {
            withAnimation(.lunaSnappy) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if selectedTab == tab {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.lunaAccent.opacity(0.2))
                            .frame(width: 44, height: 30)
                            .matchedGeometryEffect(id: "tab_bg", in: namespace)
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: selectedTab == tab ? .bold : .regular))
                        .foregroundStyle(selectedTab == tab
                            ? LinearGradient.lunaAccentGradient
                            : LinearGradient(colors: [.lunaTextMuted], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 44, height: 30)
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
