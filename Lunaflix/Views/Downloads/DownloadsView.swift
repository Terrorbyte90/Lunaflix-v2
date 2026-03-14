import SwiftUI

struct DownloadsView: View {
    @State private var selectedContent: LunaContent? = nil
    @State private var deleteTarget: LunaContent? = nil
    @State private var downloads = Array(MockData.allContent.prefix(3))

    private let storageUsed: Double = 0.24  // 24%
    private let storageTotal = "10 GB"
    private let storageUsedGB = "2,4 GB"

    var body: some View {
        ZStack {
            Color.lunaBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nedladdningar")
                            .font(LunaFont.hero())
                            .foregroundColor(.lunaTextPrimary)
                        if !downloads.isEmpty {
                            Text("\(downloads.count) titlar nedladdade")
                                .font(LunaFont.caption())
                                .foregroundColor(.lunaTextMuted)
                        }
                    }
                    Spacer()
                    if !downloads.isEmpty {
                        Button {
                            LunaHaptic.light()
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.lunaTextSecondary)
                                .frame(width: 36, height: 36)
                                .background(Color.lunaCard)
                                .cornerRadius(10)
                        }
                        .buttonStyle(LunaPressStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 58)
                .padding(.bottom, 12)

                if downloads.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Storage card
                            storageCard
                                .padding(.horizontal, 16)

                            // Download list
                            VStack(spacing: 10) {
                                ForEach(downloads) { content in
                                    DownloadRow(content: content) {
                                        LunaHaptic.light()
                                        selectedContent = content
                                    } onDelete: {
                                        withAnimation(.lunaSpring) {
                                            downloads.removeAll { $0.id == content.id }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .sheet(item: $selectedContent) { content in
            ContentDetailView(content: content)
        }
    }

    // MARK: - Storage Card

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.lunaAccentLight)
                        .frame(width: 28, height: 28)
                        .background(Color.lunaAccent.opacity(0.15))
                        .cornerRadius(7)
                    Text("Lagringsutrymme")
                        .font(LunaFont.body())
                        .foregroundColor(.lunaTextPrimary)
                }
                Spacer()
                Text("\(storageUsedGB) av \(storageTotal)")
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaTextMuted)
            }

            LunaProgressBar(
                progress: storageUsed,
                height: 6,
                color: storageUsed > 0.8 ? .red : .lunaAccentLight
            )
        }
        .padding(16)
        .background(Color.lunaCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.lunaCard)
                    .frame(width: 100, height: 100)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
            }
            .lunaGlow(color: .lunaAccent, radius: 15)

            VStack(spacing: 8) {
                Text("Inga nedladdningar")
                    .font(LunaFont.title2())
                    .foregroundColor(.lunaTextPrimary)

                Text("Ladda ner dina favoritfilmer och serier\nför att titta utan internet")
                    .font(LunaFont.body())
                    .foregroundColor(.lunaTextMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer()
        }
    }
}

// MARK: - Download Row

struct DownloadRow: View {
    let content: LunaContent
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail — tappable to open detail
            Button(action: onTap) {
                ZStack {
                    Rectangle()
                        .fill(content.thumbnailGradient.gradient)
                        .frame(width: 88, height: 64)
                        .cornerRadius(10)

                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .buttonStyle(LunaPressStyle(scale: 0.93))

            // Info
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(content.title)
                        .font(LunaFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.lunaTextPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(content.type.rawValue)
                            .font(LunaFont.tag())
                            .foregroundColor(.lunaTextMuted)
                        Text("·")
                            .foregroundColor(.lunaTextMuted)
                            .font(LunaFont.caption())
                        Text(content.duration)
                            .font(LunaFont.caption())
                            .foregroundColor(.lunaTextMuted)
                        Text("·")
                            .foregroundColor(.lunaTextMuted)
                            .font(LunaFont.caption())
                        Text("HD")
                            .font(LunaFont.tag())
                            .foregroundColor(.lunaAccentLight)
                    }

                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: "10B981"))
                            .frame(width: 6, height: 6)
                        Text("Redo att titta")
                            .font(LunaFont.caption())
                            .foregroundColor(Color(hex: "10B981"))
                    }
                }
            }
            .buttonStyle(LunaPressStyle(scale: 0.98))

            Spacer()

            // Delete button
            Button {
                LunaHaptic.medium()
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.lunaTextMuted)
                    .frame(width: 36, height: 36)
                    .background(Color.lunaElevated)
                    .cornerRadius(10)
            }
            .buttonStyle(LunaPressStyle())
        }
        .padding(12)
        .background(Color.lunaCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}
