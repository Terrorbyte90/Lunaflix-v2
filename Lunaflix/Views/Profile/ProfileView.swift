import SwiftUI

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @State private var selectedContent: LunaContent? = nil
    @State private var showStreamingPicker = false
    @State private var showDownloadPicker = false

    var body: some View {
        ZStack {
            Color.lunaBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    profileHeader.padding(.bottom, 24)

                    if vm.user.isPremium {
                        premiumCard
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }

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
        }
        .sheet(item: $selectedContent) { content in
            ContentDetailView(content: content)
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

                    // Premium crown badge
                    if vm.user.isPremium {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.lunaGold, Color.lunaGold.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .overlay(Circle().stroke(Color.lunaBackground, lineWidth: 2))
                            .offset(x: 30, y: 30)
                    }
                }
                .padding(.top, 56)

                VStack(spacing: 5) {
                    Text(vm.user.name)
                        .font(LunaFont.title1())
                        .foregroundColor(.white)

                    if vm.user.isPremium {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.lunaGold)
                            Text("Premium")
                                .font(LunaFont.caption())
                                .foregroundColor(.lunaGold)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.lunaGold.opacity(0.15))
                        .cornerRadius(20)
                        .overlay(Capsule().stroke(Color.lunaGold.opacity(0.3), lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - Premium Card

    private var premiumCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [Color(hex: "2E1065"), Color(hex: "4C1D95"), Color(hex: "7C3AED")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            // Decorative blobs
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 130)
                .offset(x: 110, y: -45)
            Circle()
                .fill(.white.opacity(0.03))
                .frame(width: 80)
                .offset(x: 140, y: 30)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.lunaGold)
                        Text("PREMIUM AKTIV")
                            .font(LunaFont.tag())
                            .foregroundColor(.lunaGold)
                            .tracking(0.5)
                    }

                    Text("Obegränsad\nstreaming")
                        .font(LunaFont.title1())
                        .foregroundColor(.white)
                        .lineSpacing(3)

                    Text("Förnyelse 15 april 2026")
                        .font(LunaFont.caption())
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer()

                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(LinearGradient(
                        colors: [.white.opacity(0.95), .lunaAccentLight],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            }
            .padding(20)
        }
        .frame(height: 135)
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
                statCard("Tittar på", value: "\(vm.user.watchHistory.count)", icon: "play.circle.fill", color: .lunaAccentLight)
                statCard("Bevakningslista", value: "\(vm.user.watchlist.count)", icon: "bookmark.fill", color: .lunaCyan)
                statCard("Nedladdningar", value: "3", icon: "arrow.down.circle.fill", color: .lunaGold)
                statCard("Prenumeration", value: vm.user.isPremium ? "Premium" : "Bas", icon: "crown.fill", color: .lunaGold)
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

    private var recentSection: some View {
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
                    Button {} label: {
                        settingsNavRow("Hantera prenumeration", icon: "creditcard.fill", color: .lunaAccentLight, value: nil)
                    }
                    .buttonStyle(LunaPressStyle(scale: 0.99))
                }
                settingsDivider
                settingsRow {
                    Button {} label: {
                        settingsNavRow("Hjälp & support", icon: "questionmark.circle.fill", color: .lunaCyan, value: nil)
                    }
                    .buttonStyle(LunaPressStyle(scale: 0.99))
                }
                settingsDivider
                settingsRow {
                    Button {} label: {
                        settingsNavRow("Logga ut", icon: "rectangle.portrait.and.arrow.right", color: .red, value: nil, destructive: true)
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
