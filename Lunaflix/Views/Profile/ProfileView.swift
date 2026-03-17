import SwiftUI

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @ObservedObject private var dm = DownloadManager.shared
    @State private var selectedContent: LunaContent? = nil
    @State private var showStreamingPicker = false
    @State private var showDownloadPicker = false
    @State private var showMuxSettings = false
    @State private var showHelp = false

    var body: some View {
        ZStack {
            Color.lunaBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    profileHeader.padding(.bottom, 24)

                    statsSection
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)

                    recentSection
                        .padding(.bottom, 24)

                    settingsSection
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)

                    appInfo
                        .padding(.horizontal, 16)
                        .padding(.bottom, 120)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .sheet(item: $selectedContent) { content in
            ContentDetailView(content: content)
        }
        .sheet(isPresented: $showMuxSettings) {
            MuxSettingsView()
        }
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .confirmationDialog(
            "Streamingkvalitet",
            isPresented: $showStreamingPicker,
            titleVisibility: .visible
        ) {
            ForEach(ProfileViewModel.StreamingQuality.allCases, id: \.rawValue) { q in
                Button(q.rawValue) {
                    LunaHaptic.selection()
                    vm.streamingQuality = q
                }
            }
        }
        .confirmationDialog(
            "Nedladdningskvalitet",
            isPresented: $showDownloadPicker,
            titleVisibility: .visible
        ) {
            ForEach(ProfileViewModel.DownloadQuality.allCases, id: \.rawValue) { q in
                Button(q.rawValue) {
                    LunaHaptic.selection()
                    vm.downloadQuality = q
                }
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Color.lunaAccent.opacity(0.35),
                    Color.lunaAccent.opacity(0.1),
                    Color.lunaBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 230)
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 14) {
                ZStack {
                    // Glow ring
                    Circle()
                        .fill(Color.lunaAccent.opacity(0.25))
                        .frame(width: 110, height: 110)
                        .blur(radius: 16)

                    // Avatar
                    Circle()
                        .fill(vm.user.avatar.gradient)
                        .frame(width: 88, height: 88)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        )

                    Text(vm.user.avatar.initials)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                }
                .padding(.top, 56)

                VStack(spacing: 5) {
                    Text(vm.user.name)
                        .font(LunaFont.title1())
                        .foregroundColor(.white)

                    Text("Lunas videoarkiv")
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextMuted)
                }
            }
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Din aktivitet")
                .font(LunaFont.title3())
                .foregroundColor(.lunaTextPrimary)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                statCard("Videor", value: "\(ContentStore.shared.allContent.count)", icon: "play.circle.fill", color: .lunaAccentLight)
                statCard("Nedladdningar", value: "\(dm.downloads.filter { $0.isReady }.count)", icon: "arrow.down.circle.fill", color: .lunaGold)
            }
        }
    }

    private func statCard(_ label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(LunaFont.title2())
                    .foregroundColor(.white)
                Text(label)
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaTextMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.lunaCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Recent Activity

    @ViewBuilder
    private var recentSection: some View {
        if !vm.recentActivity.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Senast sett")
                    .font(LunaFont.title3())
                    .foregroundColor(.lunaTextPrimary)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vm.recentActivity) { content in
                            Button {
                                LunaHaptic.light()
                                selectedContent = content
                            } label: {
                                PosterCard(content: content)
                            }
                            .buttonStyle(LunaPressStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inställningar")
                .font(LunaFont.title3())
                .foregroundColor(.lunaTextPrimary)

            VStack(spacing: 0) {
                settingsRow {
                    settingsToggle("Aviseringar", icon: "bell.fill", color: .lunaAccentLight, isOn: $vm.notificationsEnabled)
                }
                settingsDivider
                settingsRow {
                    settingsToggle("Automatisk uppspelning", icon: "play.rectangle.fill", color: .lunaAccentLight, isOn: $vm.autoplayEnabled)
                }
                settingsDivider
                settingsRow {
                    Button { showStreamingPicker = true } label: {
                        settingsNavRow("Streamingkvalitet", icon: "antenna.radiowaves.left.and.right", color: .lunaAccentLight, value: vm.streamingQuality.rawValue)
                    }
                    .buttonStyle(LunaPressStyle(scale: 0.99))
                }
                settingsDivider
                settingsRow {
                    Button { showDownloadPicker = true } label: {
                        settingsNavRow("Nedladdningskvalitet", icon: "arrow.down.circle.fill", color: .lunaAccentLight, value: vm.downloadQuality.rawValue)
                    }
                    .buttonStyle(LunaPressStyle(scale: 0.99))
                }
                settingsDivider
                settingsRow {
                    Button { showMuxSettings = true } label: {
                        settingsNavRow(
                            "Mux-inställningar",
                            icon: "cloud.fill",
                            color: .lunaAccentLight,
                            value: KeychainService.hasMuxCredentials ? "Ansluten" : nil
                        )
                    }
                    .buttonStyle(LunaPressStyle(scale: 0.99))
                }
                settingsDivider
                settingsRow {
                    Button { showHelp = true } label: {
                        settingsNavRow("Hjälp & support", icon: "questionmark.circle.fill", color: .lunaCyan, value: nil)
                    }
                    .buttonStyle(LunaPressStyle(scale: 0.99))
                }
            }
            .background(Color.lunaCard)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }

    private func settingsRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content().padding(.horizontal, 16).padding(.vertical, 12)
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.05))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private func settingsToggle(_ title: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        HStack {
            iconBg(icon, color: color)
            Text(title)
                .font(LunaFont.body())
                .foregroundColor(.lunaTextPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(.lunaAccent)
                .labelsHidden()
        }
    }

    private func settingsNavRow(_ title: String, icon: String, color: Color, value: String?, destructive: Bool = false) -> some View {
        HStack {
            iconBg(icon, color: color)
            Text(title)
                .font(LunaFont.body())
                .foregroundColor(destructive ? .red : .lunaTextPrimary)
            Spacer()
            if let value {
                Text(value)
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaTextMuted)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.lunaTextMuted)
        }
    }

    private func iconBg(_ icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(color)
            .frame(width: 30, height: 30)
            .background(color.opacity(0.15))
            .cornerRadius(8)
    }

    // MARK: - App Info

    private var appInfo: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
                Text("Lunaflix")
                    .font(LunaFont.title3())
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
            }
            Text("Version 2.0.0 • © 2026 Lunaflix AB")
                .font(LunaFont.caption())
                .foregroundColor(.lunaTextMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProfileView()
}

// MARK: - Help View

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    private let features: [(icon: String, title: String, body: String)] = [
        ("play.circle.fill",   "Titta på Lunas klipp",    "Bläddra och spela upp alla videor direkt i appen via Mux-streamingtjänsten."),
        ("arrow.up.circle.fill", "Ladda upp nya klipp",   "Tryck på uppladdningsknappen (↑) på hemskärmen. Välj en video från foton, ange eventuell titel och tryck Starta."),
        ("calendar",           "Automatiskt inspelningsdatum", "Appen läser inspelningsdatumet direkt ur videofilen och räknar automatiskt ut hur gammal Luna var vid inspelningstillfället."),
        ("magnifyingglass",    "Sök",                     "Sök på titel eller Lunas ålder i sökfliken."),
        ("arrow.down.circle.fill", "Nedladdningar",       "Ladda ner klipp för att titta offline. Tryck på nedladdningsikonen på videokortet."),
        ("gear",               "Mux-inställningar",       "Under Inställningar → Mux-inställningar kopplar du in ditt Mux-konto med Token ID och Token Secret.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.lunaBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // About card
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                Image(systemName: "moon.stars.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(LinearGradient.lunaAccentGradient)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Lunaflix")
                                        .font(LunaFont.title2())
                                        .foregroundColor(.lunaTextPrimary)
                                    Text("Lunas personliga videoarkiv")
                                        .font(LunaFont.caption())
                                        .foregroundColor(.lunaTextMuted)
                                }
                            }

                            Text("Luna ville se videor på sig själv — så skapade pappa Ted den här appen. Lunaflix är ett privat videoarkiv där alla klipp av Luna samlas på ett ställe, strömmas sömlöst och märks upp med hur gammal Luna var när de spelades in.")
                                .font(LunaFont.body())
                                .foregroundColor(.lunaTextSecondary)
                                .lineSpacing(4)
                        }
                        .padding(16)
                        .background(Color.lunaCard)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))

                        // Features
                        Text("Funktioner")
                            .font(LunaFont.title3())
                            .foregroundColor(.lunaTextPrimary)

                        VStack(spacing: 0) {
                            ForEach(features.indices, id: \.self) { i in
                                let f = features[i]
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: f.icon)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.lunaAccentLight)
                                        .frame(width: 32, height: 32)
                                        .background(Color.lunaAccent.opacity(0.15))
                                        .cornerRadius(8)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(f.title)
                                            .font(LunaFont.body())
                                            .fontWeight(.semibold)
                                            .foregroundColor(.lunaTextPrimary)
                                        Text(f.body)
                                            .font(LunaFont.caption())
                                            .foregroundColor(.lunaTextMuted)
                                            .lineSpacing(3)
                                    }
                                }
                                .padding(14)

                                if i < features.count - 1 {
                                    Rectangle()
                                        .fill(Color.white.opacity(0.05))
                                        .frame(height: 1)
                                        .padding(.horizontal, 14)
                                }
                            }
                        }
                        .background(Color.lunaCard)
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))

                        Text("Version 2.0 • Skapad av Ted med ❤️ för Luna")
                            .font(LunaFont.caption())
                            .foregroundColor(.lunaTextMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Hjälp & info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stäng") { dismiss() }
                        .foregroundColor(.lunaAccentLight)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
