import SwiftUI

struct ContentDetailView: View {
    let content: LunaContent
    @Environment(\.dismiss) private var dismiss
    @State private var showPlayer = false
    @State private var isInWatchlist = false
    @State private var selectedSeason = 1
    @State private var selectedNestedContent: LunaContent? = nil

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
            PlayerView(content: content)
        }
        .sheet(item: $selectedNestedContent) { item in
            ContentDetailView(content: item)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack {
            // Background gradient
            content.heroGradient.gradient
                .ignoresSafeArea(edges: .top)

            GeometryReader { geo in
                let w = geo.size.width

                // Glow blobs
                Circle()
                    .fill(content.heroGradient.accentColor.opacity(0.22))
                    .frame(width: w * 0.8)
                    .blur(radius: 50)
                    .offset(x: w * 0.12, y: -40)
                    .allowsHitTesting(false)

                // Watermark letter
                Text(content.title.prefix(1))
                    .font(.system(size: 210, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.055))
                    .offset(x: w * 0.28, y: -10)
                    .allowsHitTesting(false)
            }

            // Bottom gradient
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        .clear,
                        Color.lunaBackground.opacity(0.4),
                        Color.lunaBackground.opacity(0.85),
                        Color.lunaBackground
                    ],
                    startPoint: .init(x: 0, y: 0.2),
                    endPoint: .bottom
                )
                .frame(height: 220)
            }

            // Centered play button
            Button {
                LunaHaptic.medium()
                showPlayer = true
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    Image(systemName: "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: 2)
                }
            }
            .buttonStyle(LunaPressStyle(scale: 0.92))
            .lunaGlow(color: .white, radius: 12)
        }
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
                    badgeView("TRENDING", bg: .lunaGold, fg: .black)
                }
            }

            // Title
            Text(content.title)
                .font(LunaFont.hero())
                .foregroundColor(.white)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            // Subtitle
            if !content.subtitle.isEmpty {
                Text(content.subtitle)
                    .font(LunaFont.body())
                    .foregroundColor(.lunaTextSecondary)
            }

            // Meta row
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.lunaGold)
                    Text(content.formattedRating)
                        .font(LunaFont.mono(13))
                        .foregroundColor(.lunaGold)
                }

                Text("·").foregroundColor(.lunaTextMuted)
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
            } label: {
                VStack(spacing: 5) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Text("Ladda ner")
                        .font(LunaFont.tag())
                        .foregroundColor(.lunaTextSecondary)
                }
                .frame(width: 70)
                .padding(.vertical, 10)
                .background(Color.lunaCard)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(LunaPressStyle())
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(
                value: content.formattedRating,
                label: "Betyg",
                icon: "star.fill",
                color: .lunaGold
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

    // MARK: - Similar

    private var similarSection: some View {
        let similar = MockData.allContent
            .filter { $0.id != content.id }
            .filter { !Set($0.genre).isDisjoint(with: Set(content.genre)) }
            .prefix(8)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Du kanske också gillar")
                .font(LunaFont.title3())
                .foregroundColor(.lunaTextPrimary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(similar)) { item in
                        Button {
                            LunaHaptic.light()
                            selectedNestedContent = item
                        } label: {
                            PosterCard(content: item)
                        }
                        .buttonStyle(LunaPressStyle())
                    }
                }
                .padding(.horizontal, 16)
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

            Button {
                LunaHaptic.light()
                // Share sheet would go here
            } label: {
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
    ContentDetailView(content: MockData.movies[0])
}
