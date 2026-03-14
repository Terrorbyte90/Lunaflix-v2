import SwiftUI

struct DownloadsView: View {
    @State private var selectedContent: LunaContent? = nil

    // Simulated downloaded content
    private let downloads = Array(MockData.allContent.prefix(3))

    var body: some View {
        ZStack {
            Color.lunaBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Nedladdningar")
                        .font(LunaFont.hero())
                        .foregroundColor(.lunaTextPrimary)
                    Spacer()
                    Button {} label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18))
                            .foregroundColor(.lunaTextSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
                .padding(.bottom, 8)

                // Storage indicator
                storageCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)

                if downloads.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(downloads) { content in
                                DownloadRow(content: content) {
                                    selectedContent = content
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .sheet(item: $selectedContent) { content in
            ContentDetailView(content: content)
        }
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "internaldrive.fill")
                    .foregroundColor(.lunaAccentLight)
                Text("Lagringsutrymme")
                    .font(LunaFont.body())
                    .foregroundColor(.lunaTextPrimary)
                Spacer()
                Text("2,4 GB / 10 GB")
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaTextMuted)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.lunaCard)
                        .frame(height: 6)
                    Capsule()
                        .fill(LinearGradient.lunaAccentGradient)
                        .frame(width: geo.size.width * 0.24, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(Color.lunaSurface)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.lunaCard)
                    .frame(width: 90, height: 90)
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
            }
            Text("Inga nedladdningar")
                .font(LunaFont.title2())
                .foregroundColor(.lunaTextPrimary)
            Text("Ladda ner filmer och serier\nför att titta offline")
                .font(LunaFont.body())
                .foregroundColor(.lunaTextMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}

struct DownloadRow: View {
    let content: LunaContent
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Thumbnail
                ZStack {
                    Rectangle()
                        .fill(content.thumbnailGradient.gradient)
                        .frame(width: 80, height: 60)
                        .cornerRadius(10)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(content.title)
                        .font(LunaFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.lunaTextPrimary)
                        .lineLimit(1)

                    Text("\(content.duration) • HD")
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextMuted)

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "10B981"))
                        Text("Redo att titta")
                            .font(LunaFont.tag())
                            .foregroundColor(.lunaTextMuted)
                    }
                }

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    Button {} label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(LinearGradient.lunaAccentGradient)
                    }
                    Button {} label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.lunaTextMuted)
                    }
                }
            }
            .padding(12)
            .background(Color.lunaCard)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

