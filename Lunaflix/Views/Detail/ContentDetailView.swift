import SwiftUI

struct ContentDetailView: View {
    let content: LunaContent
    @Environment(\.dismiss) private var dismiss
    @State private var showPlayer = false
    @State private var isInWatchlist = false
    @State private var selectedSeason = 1
    @State private var selectedNestedContent: LunaContent? = nil
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var showEditTitle = false
    @State private var editedTitle = ""
    @State private var isSavingTitle = false
    @ObservedObject private var dm = DownloadManager.shared

    private var filteredEpisodes: [Episode] {
        content.episodes.filter { $0.seasonNumber == selectedSeason }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.lunaBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroSection
                        .frame(height: 380)

                    contentInfo
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    actionButtons
                        .padding(.horizontal, 16)
                        .padding(.top, 18)

                    statsRow
                        .padding(.horizontal, 16)
                        .padding(.top, 18)

                    // Luna age row (only for Mux library clips with recording date)
                    if let date = content.recordingDate {
                        lunaAgeRow(date: date)
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                    }

                    descriptionSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    if content.type == .series && !content.episodes.isEmpty {
                        episodesSection
                            .padding(.top, 24)
                    }

                    similarSection
                        .padding(.top, 24)
                        .padding(.bottom, 60)
                }
            }

            topNav
        }
        .ignoresSafeArea(edges: .top)
        .fullScreenCover(isPresented: $showPlayer) {
            let library = ContentStore.shared.allContent
            let playlist = library.isEmpty ? [content] : library
            PlayerView(content: content, playlist: playlist)
        }
        .sheet(item: $selectedNestedContent) { item in
            ContentDetailView(content: item)
        }
        .confirmationDialog(
            "Radera video?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Radera permanent", role: .destructive) {
                Task { await deleteVideo() }
            }
        } message: {
            Text("Videon raderas från Mux och kan inte återställas.")
        }
        .alert("Ändra titel", isPresented: $showEditTitle) {
            TextField("Titel", text: $editedTitle)
                .autocorrectionDisabled()
            Button("Spara") {
                Task { await saveTitle() }
            }
            .disabled(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Ange ett nytt namn för videon.")
        }
    }

    private func saveTitle() async {
        guard let muxID = content.muxPlaybackID else { return }
        let newTitle = editedTitle.trimmingCharacters(in: .whitespaces)
        guard !newTitle.isEmpty else { return }
        isSavingTitle = true
        do {
            let assets = try await MuxService.shared.listAssets()
            if let asset = assets.first(where: { $0.primaryPlaybackID == muxID }) {
                try await MuxService.shared.updateAssetPassthrough(
                    id: asset.id,
                    title: newTitle,
                    recordingDate: content.recordingDate
                )
                LunaHaptic.success()
            }
        } catch {}
        isSavingTitle = false
    }

    private func deleteVideo() async {
        guard let muxID = content.muxPlaybackID else { return }
        isDeleting = true
        // Extract asset ID from playback ID is not possible directly — we need to
        // search ContentStore for the matching Mux asset ID. We use the content.id
        // which maps to the muxPlaybackID indirectly.
        // Best approach: find the asset via the stored playbackID in ContentStore.
        // Since MuxService works with asset IDs, we list and match.
        do {
            let assets = try await MuxService.shared.listAssets()
            if let asset = assets.first(where: { $0.primaryPlaybackID == muxID }) {
                try await MuxService.shared.deleteAsset(id: asset.id)
                LunaHaptic.success()
            }
        } catch {
            // Silently fail — user can try again
        }
        isDeleting = false
        dismiss()
    }

    // MARK: - Hero

    private var heroThumbnailURL: URL? {
        guard let pid = content.muxPlaybackID else { return nil }
        return URL(string: "https://image.mux.com/\(pid)/thumbnail.jpg?width=800&height=450&fit_mode=smartcrop&time=2")
    }

    private var heroSection: some View {
        ZStack {
            // Background — real thumbnail when available
            GeometryReader { geo in
                let w = geo.size.width

                if let url = heroThumbnailURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: w, height: 380)
                                .clipped()
                                .overlay(
                                    content.heroGradient.gradient
                                        .opacity(0.30)
                                        .ignoresSafeArea(edges: .top)
                                )
                                .transition(.opacity.animation(.easeIn(duration: 0.3)))
                        case .failure:
                            gradientHero(w: w)
                        default:
                            gradientHero(w: w)
                                .overlay(
                                    Rectangle()
                                        .fill(Color.lunaCard.opacity(0.4))
                                        .shimmering()
                                        .ignoresSafeArea(edges: .top)
                                )
                        }
                    }
                } else {
                    gradientHero(w: w)
                }
            }
            .ignoresSafeArea(edges: .top)

            // Bottom gradient — richer fade for readability
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        .clear,
                        Color.lunaBackground.opacity(0.25),
                        Color.lunaBackground.opacity(0.72),
                        Color.lunaBackground.opacity(0.93),
                        Color.lunaBackground
                    ],
                    startPoint: .init(x: 0.5, y: 0),
                    endPoint: .bottom
                )
                .frame(height: 240)
            }

            // Centered play button — larger, more confident
            Button {
                LunaHaptic.medium()
                showPlayer = true
            } label: {
                ZStack {
                    // Outer glow ring
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 96, height: 96)
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.25), lineWidth: 1.5)
                        )
                    Image(systemName: "play.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: 3)
                }
            }
            .buttonStyle(LunaPressStyle(scale: 0.90))
            .lunaGlow(color: .white, radius: 18)
        }
    }

    @ViewBuilder
    private func gradientHero(w: CGFloat) -> some View {
        content.heroGradient.gradient
            .ignoresSafeArea(edges: .top)

        Circle()
            .fill(content.heroGradient.accentColor.opacity(0.22))
            .frame(width: w * 0.8)
            .blur(radius: 50)
            .offset(x: w * 0.12, y: -40)
            .allowsHitTesting(false)

        Text(content.title.prefix(1))
            .font(.system(size: 210, weight: .black, design: .rounded))
            .foregroundColor(.white.opacity(0.055))
            .offset(x: w * 0.28, y: -10)
            .allowsHitTesting(false)
    }

    // MARK: - Content Info

    private var contentInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Type + badges
            HStack(spacing: 8) {
                Label(content.type.rawValue, systemImage: content.type.icon)
                    .font(LunaFont.caption())
                    .foregroundColor(content.heroGradient.accentColor)

                if content.isNew {
                    badgeView("NYTT", bg: .lunaAccent, fg: .white)
                }
                if content.isTrending {
                    badgeView("POPULÄRT", bg: .lunaGold, fg: .black)
                }
            }

            // Title + edit button
            HStack(alignment: .top, spacing: 8) {
                Text(content.title)
                    .font(LunaFont.hero())
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if content.muxPlaybackID != nil {
                    Button {
                        LunaHaptic.light()
                        editedTitle = content.title
                        showEditTitle = true
                    } label: {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.lunaTextMuted)
                            .padding(.top, 6)
                    }
                    .buttonStyle(LunaPressStyle())
                }
            }

            // Subtitle
            if !content.subtitle.isEmpty {
                Text(content.subtitle)
                    .font(LunaFont.body())
                    .foregroundColor(.lunaTextSecondary)
            }

            // Meta row
            HStack(spacing: 8) {
                if content.rating > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.lunaGold)
                        Text(content.formattedRating)
                            .font(LunaFont.mono(13))
                            .foregroundColor(.lunaGold)
                    }
                    Text("·").foregroundColor(.lunaTextMuted)
                }
                Text("\(content.year)")
                    .font(LunaFont.body())
                    .foregroundColor(.lunaTextSecondary)

                Text("·").foregroundColor(.lunaTextMuted)
                Text(content.duration)
                    .font(LunaFont.body())
                    .foregroundColor(.lunaTextSecondary)

                Text("·").foregroundColor(.lunaTextMuted)
                Text(content.ageRating.label)
                    .font(LunaFont.tag())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(content.ageRating.color.opacity(0.2))
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(content.ageRating.color.opacity(0.4), lineWidth: 1))
            }

            // Genre chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(content.genre, id: \.rawValue) { genre in
                        Text(genre.displayName)
                            .font(LunaFont.caption())
                            .foregroundColor(content.heroGradient.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(content.heroGradient.accentColor.opacity(0.12))
                            .cornerRadius(20)
                            .overlay(Capsule().stroke(content.heroGradient.accentColor.opacity(0.25), lineWidth: 1))
                    }
                }
            }
        }
    }

    private func badgeView(_ text: String, bg: Color, fg: Color) -> some View {
        Text(text)
            .font(LunaFont.tag())
            .foregroundColor(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .cornerRadius(4)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Primary: Play / Continue
            Button {
                LunaHaptic.medium()
                showPlayer = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: content.isContinuing ? "arrow.clockwise" : "play.fill")
                    Text(content.isContinuing ? "Fortsätt titta" : "Spela upp")
                        .fontWeight(.bold)
                }
                .font(LunaFont.body())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LinearGradient.lunaAccentGradient)
                .cornerRadius(14)
                .shadow(color: Color.lunaAccent.opacity(0.45), radius: 14, x: 0, y: 5)
            }
            .buttonStyle(LunaPressStyle(scale: 0.97))

            // Watchlist
            Button {
                LunaHaptic.light()
                withAnimation(.lunaSpring) {
                    isInWatchlist.toggle()
                }
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: isInWatchlist ? "checkmark" : "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(isInWatchlist ? .lunaAccentLight : .white)
                    Text(isInWatchlist ? "Sparad" : "Min lista")
                        .font(LunaFont.tag())
                        .foregroundColor(isInWatchlist ? .lunaAccentLight : .lunaTextSecondary)
                }
                .frame(width: 70)
                .padding(.vertical, 10)
                .background(Color.lunaCard)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isInWatchlist ? Color.lunaAccentLight.opacity(0.4) : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(LunaPressStyle())

            // Download
            Button {
                LunaHaptic.light()
                if !dm.isDownloaded(content) && !dm.isDownloading(content) {
                    dm.download(content)
                }
            } label: {
                let downloaded = dm.isDownloaded(content)
                let downloading = dm.isDownloading(content)
                let progress = dm.item(for: content)?.progress ?? 0
                VStack(spacing: 5) {
                    if downloading {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                .frame(width: 20, height: 20)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(Color.lunaAccentLight, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                .frame(width: 20, height: 20)
                                .rotationEffect(.degrees(-90))
                        }
                    } else {
                        Image(systemName: downloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(downloaded ? .lunaAccentLight : .white)
                    }
                    Text(downloaded ? "Nedladdad" : downloading ? "\(Int(progress * 100))%" : "Ladda ner")
                        .font(LunaFont.tag())
                        .foregroundColor(downloaded ? .lunaAccentLight : .lunaTextSecondary)
                }
                .frame(width: 70)
                .padding(.vertical, 10)
                .background(Color.lunaCard)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            downloaded ? Color.lunaAccentLight.opacity(0.4) : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(LunaPressStyle())
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(
                value: content.rating > 0 ? content.formattedRating : "–",
                label: "Betyg",
                icon: "star.fill",
                color: content.rating > 0 ? .lunaGold : .lunaTextMuted
            )
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1, height: 36)
            statItem(
                value: "\(content.year)",
                label: "År",
                icon: "calendar",
                color: .lunaAccentLight
            )
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1, height: 36)
            statItem(
                value: content.type.rawValue,
                label: "Typ",
                icon: content.type.icon,
                color: .lunaCyan
            )
        }
        .padding(.vertical, 16)
        .background(Color.lunaCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(color)
            Text(value)
                .font(LunaFont.mono(14))
                .foregroundColor(.white)
            Text(label)
                .font(LunaFont.caption())
                .foregroundColor(.lunaTextMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Luna Age Row

    private func lunaAgeRow(date: Date) -> some View {
        HStack(spacing: 14) {
            // Moon icon in warm glow circle
            ZStack {
                Circle()
                    .fill(Color.lunaWarm.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.lunaWarm, Color.lunaAccentLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .lunaGlow(color: .lunaWarm, radius: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(LunaAge.ageLabel(at: date))
                    .font(LunaFont.body())
                    .fontWeight(.semibold)
                    .foregroundColor(.lunaTextPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                        .foregroundColor(.lunaTextMuted)
                    Text("Inspelat \(LunaAge.formatted(date))")
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextMuted)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.lunaWarm.opacity(0.08), Color.lunaAccent.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.lunaWarm.opacity(0.18), lineWidth: 1))
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Om titeln")
                .font(LunaFont.title3())
                .foregroundColor(.lunaTextPrimary)

            Text(content.description)
                .font(LunaFont.body())
                .foregroundColor(.lunaTextSecondary)
                .lineSpacing(5)
        }
    }

    // MARK: - Episodes

    private var episodesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Avsnitt")
                    .font(LunaFont.title3())
                    .foregroundColor(.lunaTextPrimary)
                Spacer()

                if let seasons = content.numberOfSeasons, seasons > 1 {
                    Menu {
                        ForEach(1...seasons, id: \.self) { s in
                            Button {
                                withAnimation(.lunaSnappy) { selectedSeason = s }
                            } label: {
                                HStack {
                                    Text("Säsong \(s)")
                                    if selectedSeason == s {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Säsong \(selectedSeason)")
                                .font(LunaFont.caption())
                                .foregroundColor(.lunaAccentLight)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(.lunaAccentLight)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.lunaCard)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.lunaAccentLight.opacity(0.3), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 16)

            let episodes = filteredEpisodes.isEmpty ? content.episodes : filteredEpisodes
            ForEach(episodes) { episode in
                EpisodeRow(episode: episode) {
                    LunaHaptic.medium()
                    showPlayer = true
                }
            }
        }
    }

    // MARK: - Similar / More clips

    private var similarSection: some View {
        let others = ContentStore.shared.allContent
            .filter { $0.id != content.id }
            .prefix(8)

        return Group {
            if !others.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Fler klipp")
                        .font(LunaFont.title3())
                        .foregroundColor(.lunaTextPrimary)
                        .padding(.horizontal, 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(others)) { item in
                                Button {
                                    LunaHaptic.light()
                                    selectedNestedContent = item
                                } label: {
                                    WideCard(content: item, width: 220, height: 128)
                                }
                                .buttonStyle(LunaPressStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    // MARK: - Top Nav

    private var topNav: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 38, height: 38)
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(LunaPressStyle())

            Spacer()

            HStack(spacing: 10) {
                // Share button — opens system share sheet with Mux stream URL
                if let pid = content.muxPlaybackID,
                   let shareURL = URL(string: "https://stream.mux.com/\(pid).m3u8") {
                    ShareLink(item: shareURL, subject: Text(content.title), message: Text("Titta på \(content.title) i Lunaflix")) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 38, height: 38)
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(LunaPressStyle())
                }

                // Delete button (only if Mux playback ID exists)
                if content.muxPlaybackID != nil {
                    Button {
                        LunaHaptic.medium()
                        showDeleteConfirm = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 38, height: 38)
                                .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            if isDeleting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.65)
                                    .tint(.white)
                            } else {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.red.opacity(0.85))
                            }
                        }
                    }
                    .buttonStyle(LunaPressStyle())
                    .disabled(isDeleting)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
    }
}

// MARK: - Episode Row

struct EpisodeRow: View {
    let episode: Episode
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 12) {
                // Thumbnail
                ZStack {
                    Rectangle()
                        .fill(episode.thumbnailStyle.gradient)
                        .frame(width: 114, height: 66)
                        .cornerRadius(9)

                    // Play icon with slight blur backdrop
                    ZStack {
                        Circle()
                            .fill(.black.opacity(0.3))
                            .frame(width: 32, height: 32)
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 1)
                    }

                    if episode.progress > 0 {
                        VStack {
                            Spacer()
                            LunaProgressBar(progress: episode.progress, height: 3)
                                .padding(.horizontal, 6)
                                .padding(.bottom, 4)
                        }
                    }
                }
                .frame(width: 114, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 9))

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(episode.episodeNumber). \(episode.title)")
                        .font(LunaFont.body())
                        .foregroundColor(.lunaTextPrimary)
                        .lineLimit(1)

                    Text(episode.description)
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextMuted)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundColor(.lunaTextMuted)
                        Text(episode.duration)
                            .font(LunaFont.caption())
                            .foregroundColor(.lunaTextMuted)
                    }
                }

                Spacer()

                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(.lunaTextMuted)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(LunaPressStyle(scale: 0.98))
    }
}

#Preview {
    ContentDetailView(content: LunaContent(
        title: "Förhandsgranskning",
        description: "Lunas klipp",
        type: .movie, genre: [], rating: 0, year: 2025,
        duration: "2 min", thumbnailGradient: .violet
    ))
}
