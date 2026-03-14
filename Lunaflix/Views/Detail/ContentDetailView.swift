import SwiftUI

struct ContentDetailView: View {
    let content: LunaContent
    @Environment(\.dismiss) private var dismiss
    @State private var showPlayer = false
    @State private var isInWatchlist = false
    @State private var selectedSeason = 1
    @State private var headerVisible = true

    var body: some View {
        ZStack(alignment: .top) {
            Color.lunaBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero image
                    heroSection
                        .frame(height: 360)

                    // Content info
                    contentInfo
                        .padding(.horizontal, 16)

                    // Action buttons
                    actionButtons
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // Stats row
                    statsRow
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // Description
                    descriptionSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // Episodes (for series)
                    if content.type == .series && !content.episodes.isEmpty {
                        episodesSection
                            .padding(.top, 20)
                    }

                    // Similar content
                    similarSection
                        .padding(.top, 20)
                        .padding(.bottom, 120)
                }
            }

            // Top navigation
            topNav
        }
        .ignoresSafeArea(edges: .top)
        .fullScreenCover(isPresented: $showPlayer) {
            PlayerView(content: content)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            content.heroGradient.gradient
                .ignoresSafeArea(edges: .top)

            // Decorative elements
            GeometryReader { geo in
                Circle()
                    .fill(content.heroGradient.accentColor.opacity(0.2))
                    .frame(width: geo.size.width * 0.8)
                    .blur(radius: 50)
                    .offset(x: geo.size.width * 0.1, y: -50)

                // Large watermark letter
                Text(content.title.prefix(1))
                    .font(.system(size: 220, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.06))
                    .offset(x: geo.size.width * 0.3, y: -20)
            }

            // Play button overlay
            Button { showPlayer = true } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 70, height: 70)
                    Image(systemName: "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: 3)
                }
            }
            .lunaGlow()
            .offset(y: -40)

            // Gradient overlay
            LinearGradient(
                colors: [.clear, Color.lunaBackground.opacity(0.5), Color.lunaBackground],
                startPoint: .init(x: 0, y: 0.3),
                endPoint: .bottom
            )
        }
    }

    // MARK: - Content Info

    private var contentInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Type + New badge
            HStack(spacing: 8) {
                Label(content.type.rawValue, systemImage: content.type.icon)
                    .font(LunaFont.caption())
                    .foregroundColor(content.heroGradient.accentColor)

                if content.isNew {
                    Text("NYTT")
                        .font(LunaFont.tag())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.lunaAccent)
                        .cornerRadius(4)
                }

                if content.isTrending {
                    Text("TRENDING")
                        .font(LunaFont.tag())
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.lunaGold)
                        .cornerRadius(4)
                }
            }

            // Title
            Text(content.title)
                .font(LunaFont.hero())
                .foregroundColor(.white)
                .lineLimit(3)

            // Subtitle
            if !content.subtitle.isEmpty {
                Text(content.subtitle)
                    .font(LunaFont.body())
                    .foregroundColor(.lunaTextSecondary)
            }

            // Meta
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.lunaGold)
                    Text(content.formattedRating)
                        .font(LunaFont.body())
                        .fontWeight(.semibold)
                        .foregroundColor(.lunaGold)
                }

                Text("•").foregroundColor(.lunaTextMuted)
                Text("\(content.year)").font(LunaFont.body()).foregroundColor(.lunaTextSecondary)

                Text("•").foregroundColor(.lunaTextMuted)
                Text(content.duration).font(LunaFont.body()).foregroundColor(.lunaTextSecondary)

                Text("•").foregroundColor(.lunaTextMuted)
                Text(content.ageRating.label)
                    .font(LunaFont.caption())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(content.ageRating.color.opacity(0.2))
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(content.ageRating.color.opacity(0.4), lineWidth: 1))
            }

            // Genres
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

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Primary play
            Button { showPlayer = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: content.isContinuing ? "play.fill" : "play.fill")
                    Text(content.isContinuing ? "Fortsätt titta" : "Spela upp")
                }
                .font(LunaFont.body())
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LinearGradient.lunaAccentGradient)
                .cornerRadius(14)
                .shadow(color: Color.lunaAccent.opacity(0.4), radius: 12, x: 0, y: 4)
            }

            // Watchlist
            Button {
                withAnimation(.lunaSpring) {
                    isInWatchlist.toggle()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: isInWatchlist ? "checkmark" : "plus")
                        .font(.system(size: 18, weight: .bold))
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
                        .stroke(isInWatchlist ? Color.lunaAccentLight.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Download
            Button {} label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 18, weight: .bold))
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
            .buttonStyle(.plain)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(value: content.formattedRating, label: "Betyg", icon: "star.fill", color: .lunaGold)
            Divider().frame(height: 30).background(Color.white.opacity(0.1))
            statItem(value: "\(content.year)", label: "År", icon: "calendar", color: .lunaAccentLight)
            Divider().frame(height: 30).background(Color.white.opacity(0.1))
            statItem(value: content.type.rawValue, label: "Typ", icon: content.type.icon, color: .lunaCyan)
        }
        .padding(.vertical, 16)
        .background(Color.lunaCard)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
            Text(value)
                .font(LunaFont.body())
                .fontWeight(.bold)
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
                .lineSpacing(4)
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
                            Button("Säsong \(s)") { selectedSeason = s }
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
                    }
                }
            }
            .padding(.horizontal, 16)

            ForEach(content.episodes) { episode in
                EpisodeRow(episode: episode) {
                    showPlayer = true
                }
            }
        }
    }

    // MARK: - Similar

    private var similarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Du kanske också gillar")
                .font(LunaFont.title3())
                .foregroundColor(.lunaTextPrimary)
                .padding(.horizontal, 16)

            let similar = MockData.allContent
                .filter { $0.id != content.id }
                .filter { !Set($0.genre).isDisjoint(with: Set(content.genre)) }
                .prefix(6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(similar)) { item in
                        PosterCard(content: item)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Top Nav

    private var topNav: some View {
        HStack {
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 36, height: 36)
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            Spacer()
            Button {} label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 36, height: 36)
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 54)
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
                        .frame(width: 110, height: 65)
                        .cornerRadius(8)

                    Image(systemName: "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))

                    if episode.progress > 0 {
                        VStack {
                            Spacer()
                            ProgressView(value: episode.progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .lunaAccentLight))
                                .scaleEffect(y: 1.5)
                                .padding(.horizontal, 4)
                                .padding(.bottom, 2)
                        }
                    }
                }
                .frame(width: 110, height: 65)

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

                    Text(episode.duration)
                        .font(LunaFont.caption())
                        .foregroundColor(.lunaTextMuted)
                }

                Spacer()

                Image(systemName: "ellipsis")
                    .font(.system(size: 16))
                    .foregroundColor(.lunaTextMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentDetailView(content: MockData.movies[0])
}
