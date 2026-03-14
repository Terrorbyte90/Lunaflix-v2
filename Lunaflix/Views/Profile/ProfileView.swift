import SwiftUI

struct ProfileView: View {
    @StateObject private var vm = ProfileViewModel()
    @State private var selectedContent: LunaContent? = nil
    @State private var showSettings = false

    var body: some View {
        ZStack {
            Color.lunaBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    profileHeader
                        .padding(.bottom, 24)

                    // Premium card
                    if vm.user.isPremium {
                        premiumCard
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }

                    // Stats
                    statsSection
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)

                    // Recent activity
                    recentSection

                    // Settings
                    settingsSection
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)

                    // App info
                    appInfo
                        .padding(.horizontal, 16)
                        .padding(.bottom, 120)
                }
            }
        }
        .sheet(item: $selectedContent) { content in
            ContentDetailView(content: content)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        ZStack(alignment: .bottom) {
            // Background gradient
            LinearGradient(
                colors: [Color.lunaAccent.opacity(0.3), Color.lunaBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 220)
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(vm.user.avatar.gradient)
                        .frame(width: 90, height: 90)
                        .lunaGlow(color: .lunaAccent, radius: 20)

                    Text(vm.user.avatar.initials)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    // Premium badge
                    if vm.user.isPremium {
                        Circle()
                            .fill(LinearGradient.lunaAccentGradient)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 32, y: 32)
                    }
                }
                .padding(.top, 60)

                VStack(spacing: 4) {
                    Text(vm.user.name)
                        .font(LunaFont.title1())
                        .foregroundColor(.white)

                    if vm.user.isPremium {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 11))
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

            // Decorative
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 120)
                .offset(x: 120, y: -40)

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.lunaGold)
                        Text("Premium Aktiv")
                            .font(LunaFont.caption())
                            .foregroundColor(.lunaGold)
                    }

                    Text("Obegränsad\nstreaming")
                        .font(LunaFont.title2())
                        .foregroundColor(.white)
                        .lineSpacing(2)

                    Text("Förnyelse 15 april 2026")
                        .font(LunaFont.caption())
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(LinearGradient(
                        colors: [.white.opacity(0.9), .lunaAccentLight],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            }
            .padding(20)
        }
        .frame(height: 130)
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Din aktivitet")
                .font(LunaFont.title3())
                .foregroundColor(.lunaTextPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(vm.stats, id: \.label) { stat in
                    statCard(stat.label, value: stat.value)
                }
            }
        }
    }

    private func statCard(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(LunaFont.title2())
                .foregroundColor(.white)
            Text(label)
                .font(LunaFont.caption())
                .foregroundColor(.lunaTextMuted)
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
                        Button { selectedContent = content } label: {
                            PosterCard(content: content)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inställningar")
                .font(LunaFont.title3())
                .foregroundColor(.lunaTextPrimary)

            VStack(spacing: 2) {
                settingsToggle("Aviseringar", icon: "bell.fill", isOn: $vm.notificationsEnabled)
                Divider().background(Color.white.opacity(0.06))
                settingsToggle("Automatisk uppspelning", icon: "play.rectangle.fill", isOn: $vm.autoplayEnabled)
                Divider().background(Color.white.opacity(0.06))
                settingsPicker("Streamingkvalitet", icon: "antenna.radiowaves.left.and.right",
                               value: vm.streamingQuality.rawValue)
                Divider().background(Color.white.opacity(0.06))
                settingsPicker("Nedladdningskvalitet", icon: "arrow.down.circle.fill",
                               value: vm.downloadQuality.rawValue)
                Divider().background(Color.white.opacity(0.06))
                settingsButton("Hantera prenumeration", icon: "creditcard.fill", color: .lunaAccentLight)
                Divider().background(Color.white.opacity(0.06))
                settingsButton("Hjälp & support", icon: "questionmark.circle.fill", color: .lunaCyan)
                Divider().background(Color.white.opacity(0.06))
                settingsButton("Logga ut", icon: "rectangle.portrait.and.arrow.right", color: .red)
            }
            .background(Color.lunaCard)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }

    private func settingsToggle(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.lunaAccentLight)
                .frame(width: 28, height: 28)
                .background(Color.lunaAccent.opacity(0.15))
                .cornerRadius(7)
            Text(title)
                .font(LunaFont.body())
                .foregroundColor(.lunaTextPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(.lunaAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func settingsPicker(_ title: String, icon: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.lunaAccentLight)
                .frame(width: 28, height: 28)
                .background(Color.lunaAccent.opacity(0.15))
                .cornerRadius(7)
            Text(title)
                .font(LunaFont.body())
                .foregroundColor(.lunaTextPrimary)
            Spacer()
            Text(value)
                .font(LunaFont.body())
                .foregroundColor(.lunaTextMuted)
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.lunaTextMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func settingsButton(_ title: String, icon: String, color: Color) -> some View {
        Button {} label: {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.15))
                    .cornerRadius(7)
                Text(title)
                    .font(LunaFont.body())
                    .foregroundColor(color == .red ? .red : .lunaTextPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.lunaTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - App Info

    private var appInfo: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
                Text("Lunaflix")
                    .font(LunaFont.body())
                    .fontWeight(.bold)
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
            }

            Text("Version 2.0.0 • © 2025 Lunaflix AB")
                .font(LunaFont.caption())
                .foregroundColor(.lunaTextMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProfileView()
}
