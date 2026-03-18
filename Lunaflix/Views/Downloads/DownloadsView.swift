import SwiftUI

struct DownloadsView: View {
    @ObservedObject private var dm = DownloadManager.shared
    @State private var selectedContent: LunaContent? = nil

    private var storageUsedFraction: Double {
        let bytes = dm.totalStorageBytes
        guard bytes > 0 else { return 0 }
        return min(Double(bytes) / 10_000_000_000, 1.0) // 10 GB cap
    }

    private var storageUsedString: String {
        let bytes = dm.totalStorageBytes
        let gb = Double(bytes) / 1_000_000_000
        let mb = Double(bytes) / 1_000_000
        if gb >= 0.1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", mb)
    }

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
                        if !dm.downloads.isEmpty {
                            Text("\(dm.downloads.filter { $0.isReady }.count) titlar nedladdade")
                                .font(LunaFont.caption())
                                .foregroundColor(.lunaTextMuted)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if dm.downloads.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            // Storage card (only when there are completed downloads)
                            if dm.downloads.contains(where: { $0.isReady }) {
                                storageCard
                                    .padding(.horizontal, 16)
                            }

                            // Download list
                            VStack(spacing: 10) {
                                ForEach(dm.downloads) { item in
                                    DownloadRow(item: item) {
                                        LunaHaptic.light()
                                        selectedContent = item.toLunaContent()
                                    } onDelete: {
                                        LunaHaptic.medium()
                                        dm.delete(item)
                                    } onRetry: {
                                        LunaHaptic.light()
                                        dm.retry(item)
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
                Text("\(storageUsedString) av 10 GB")
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaTextMuted)
            }

            LunaProgressBar(
                progress: storageUsedFraction,
                height: 6,
                color: storageUsedFraction > 0.8 ? .red : .lunaAccentLight
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
                    .fill(Color.lunaAccent.opacity(0.08))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(Color.lunaCard)
                    .frame(width: 100, height: 100)
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(LinearGradient.lunaAccentGradient)
            }
            .lunaGlow(color: .lunaAccent, radius: 18)

            VStack(spacing: 8) {
                Text("Inga nedladdningar")
                    .font(LunaFont.title2())
                    .foregroundColor(.lunaTextPrimary)

                Text("Öppna ett videoklipp och tryck på\nnedladdningsknappen för att spara offline.")
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
    let item: DownloadItem
    let onTap: () -> Void
    let onDelete: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail with real Mux image
            Button(action: onTap) {
                ZStack {
                    MuxThumbnailImage(
                        playbackID: item.muxPlaybackID,
                        fallbackGradient: item.thumbnailGradient,
                        width: 88,
                        height: 64
                    )
                    .cornerRadius(10)

                    // State overlay
                    if item.isReady {
                        Color.black.opacity(0.25)
                            .cornerRadius(10)
                        Image(systemName: "play.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white.opacity(0.90))
                    } else if item.errorMessage != nil {
                        Color.black.opacity(0.45)
                            .cornerRadius(10)
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.red.opacity(0.85))
                    } else {
                        Color.black.opacity(0.35)
                            .cornerRadius(10)
                        // Progress ring
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 3)
                                .frame(width: 32, height: 32)
                            Circle()
                                .trim(from: 0, to: item.progress)
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 32, height: 32)
                                .rotationEffect(.degrees(-90))
                                .animation(.linear(duration: 0.3), value: item.progress)
                        }
                    }
                }
                .frame(width: 88, height: 64)
            }
            .buttonStyle(LunaPressStyle(scale: 0.93))

            // Info
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(LunaFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.lunaTextPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("Video")
                            .font(LunaFont.tag())
                            .foregroundColor(.lunaTextMuted)
                        Text("·")
                            .foregroundColor(.lunaTextMuted)
                            .font(LunaFont.caption())
                        Text(item.duration)
                            .font(LunaFont.caption())
                            .foregroundColor(.lunaTextMuted)
                        if item.isReady {
                            Text("·")
                                .foregroundColor(.lunaTextMuted)
                                .font(LunaFont.caption())
                            Text("HD")
                                .font(LunaFont.tag())
                                .foregroundColor(.lunaAccentLight)
                        }
                    }

                    statusRow
                }
            }
            .buttonStyle(LunaPressStyle(scale: 0.98))

            Spacer()

            // Action button
            if let _ = item.errorMessage {
                Button {
                    onRetry()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.lunaAccentLight)
                        .frame(width: 36, height: 36)
                        .background(Color.lunaElevated)
                        .cornerRadius(10)
                }
                .buttonStyle(LunaPressStyle())
            } else {
                Button {
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
        }
        .padding(12)
        .background(Color.lunaCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    @ViewBuilder
    private var statusRow: some View {
        if item.errorMessage != nil {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                Text("Misslyckades")
                    .font(LunaFont.caption())
                    .foregroundColor(.red)
            }
        } else if item.isReady {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: "10B981"))
                    .frame(width: 6, height: 6)
                Text("Redo att titta")
                    .font(LunaFont.caption())
                    .foregroundColor(Color(hex: "10B981"))
                if !item.fileSizeString.isEmpty && item.fileSizeString != "–" {
                    Text("· \(item.fileSizeString)")
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextMuted)
                }
            }
        } else {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.lunaAccentLight)
                    .frame(width: 6, height: 6)
                Text("Laddar ner \(Int(item.progress * 100))%")
                    .font(LunaFont.caption())
                    .foregroundColor(.lunaAccentLight)
            }
        }
    }
}
