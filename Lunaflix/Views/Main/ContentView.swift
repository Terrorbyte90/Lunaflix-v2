import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedContent: LunaContent? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.lunaBackground.ignoresSafeArea()

            // Tab content
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

#Preview {
    ContentView()
        .environmentObject(AppState())
}
