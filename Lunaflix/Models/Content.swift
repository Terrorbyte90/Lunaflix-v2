import SwiftUI

// MARK: - Content Model

struct LunaContent: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let description: String
    let type: ContentType
    let genre: [Genre]
    let rating: Double
    let year: Int
    let duration: String
    let ageRating: AgeRating
    let thumbnailGradient: ThumbnailStyle
    let heroGradient: ThumbnailStyle
    let isTrending: Bool
    let isNew: Bool
    let isContinuing: Bool
    let continueProgress: Double     // 0.0 - 1.0
    let numberOfSeasons: Int?
    let episodes: [Episode]
    let muxPlaybackID: String?
    let recordingDate: Date?

    /// "Luna var X gammal" — non-nil only when recording date is known
    var lunaAgeAtRecording: String? {
        recordingDate.map { LunaAge.ageLabel(at: $0) }
    }

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String = "",
        description: String,
        type: ContentType,
        genre: [Genre],
        rating: Double,
        year: Int,
        duration: String,
        ageRating: AgeRating = .teen,
        thumbnailGradient: ThumbnailStyle,
        heroGradient: ThumbnailStyle? = nil,
        isTrending: Bool = false,
        isNew: Bool = false,
        isContinuing: Bool = false,
        continueProgress: Double = 0,
        numberOfSeasons: Int? = nil,
        episodes: [Episode] = [],
        muxPlaybackID: String? = nil,
        recordingDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.description = description
        self.type = type
        self.genre = genre
        self.rating = rating
        self.year = year
        self.duration = duration
        self.ageRating = ageRating
        self.thumbnailGradient = thumbnailGradient
        self.heroGradient = heroGradient ?? thumbnailGradient
        self.isTrending = isTrending
        self.isNew = isNew
        self.isContinuing = isContinuing
        self.continueProgress = continueProgress
        self.numberOfSeasons = numberOfSeasons
        self.episodes = episodes
        self.muxPlaybackID = muxPlaybackID
        self.recordingDate = recordingDate
    }

    static func == (lhs: LunaContent, rhs: LunaContent) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var formattedRating: String { String(format: "%.1f", rating) }
    var genreString: String { genre.prefix(2).map(\.displayName).joined(separator: " • ") }
    var metaString: String { "\(year) • \(duration) • \(ageRating.label)" }
}

// MARK: - Supporting Types

enum ContentType: String, CaseIterable {
    case movie = "Film"
    case series = "Serie"
    case documentary = "Dokumentär"
    case short = "Kortfilm"

    var icon: String {
        switch self {
        case .movie: return "film"
        case .series: return "tv"
        case .documentary: return "camera.metering.unknown"
        case .short: return "play.circle"
        }
    }
}

enum Genre: String, CaseIterable {
    case action, adventure, animation, comedy, crime, documentary
    case drama, fantasy, horror, mystery, romance, scifi, thriller

    var displayName: String {
        switch self {
        case .action: return "Action"
        case .adventure: return "Äventyr"
        case .animation: return "Animation"
        case .comedy: return "Komedi"
        case .crime: return "Krim"
        case .documentary: return "Dokumentär"
        case .drama: return "Drama"
        case .fantasy: return "Fantasy"
        case .horror: return "Skräck"
        case .mystery: return "Mystik"
        case .romance: return "Romantik"
        case .scifi: return "Sci-Fi"
        case .thriller: return "Thriller"
        }
    }
}

enum AgeRating: String {
    case all = "Alla"
    case child = "7"
    case teen = "13"
    case mature = "16"
    case adult = "18"

    var label: String { rawValue == "Alla" ? "Alla åldrar" : "\(rawValue)+" }
    var color: Color {
        switch self {
        case .all: return .green
        case .child: return .blue
        case .teen: return .yellow
        case .mature: return .orange
        case .adult: return .red
        }
    }
}

enum ThumbnailStyle {
    case purple, blue, teal, rose, amber, indigo, emerald, crimson, violet, ocean

    var gradient: LinearGradient {
        switch self {
        case .purple:
            return LinearGradient(colors: [Color(hex: "4C1D95"), Color(hex: "7C3AED"), Color(hex: "A78BFA")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .blue:
            return LinearGradient(colors: [Color(hex: "1E3A8A"), Color(hex: "2563EB"), Color(hex: "60A5FA")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .teal:
            return LinearGradient(colors: [Color(hex: "134E4A"), Color(hex: "0D9488"), Color(hex: "5EEAD4")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .rose:
            return LinearGradient(colors: [Color(hex: "881337"), Color(hex: "E11D48"), Color(hex: "FB7185")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .amber:
            return LinearGradient(colors: [Color(hex: "78350F"), Color(hex: "D97706"), Color(hex: "FCD34D")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .indigo:
            return LinearGradient(colors: [Color(hex: "1E1B4B"), Color(hex: "4338CA"), Color(hex: "818CF8")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .emerald:
            return LinearGradient(colors: [Color(hex: "064E3B"), Color(hex: "059669"), Color(hex: "6EE7B7")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .crimson:
            return LinearGradient(colors: [Color(hex: "450A0A"), Color(hex: "B91C1C"), Color(hex: "FCA5A5")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .violet:
            return LinearGradient(colors: [Color(hex: "2E1065"), Color(hex: "7E22CE"), Color(hex: "D8B4FE")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        case .ocean:
            return LinearGradient(colors: [Color(hex: "0C4A6E"), Color(hex: "0284C7"), Color(hex: "7DD3FC")],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var accentColor: Color {
        switch self {
        case .purple: return Color(hex: "A78BFA")
        case .blue: return Color(hex: "60A5FA")
        case .teal: return Color(hex: "5EEAD4")
        case .rose: return Color(hex: "FB7185")
        case .amber: return Color(hex: "FCD34D")
        case .indigo: return Color(hex: "818CF8")
        case .emerald: return Color(hex: "6EE7B7")
        case .crimson: return Color(hex: "FCA5A5")
        case .violet: return Color(hex: "D8B4FE")
        case .ocean: return Color(hex: "7DD3FC")
        }
    }
}

// MARK: - Episode

struct Episode: Identifiable, Hashable {
    let id: UUID
    let title: String
    let episodeNumber: Int
    let seasonNumber: Int
    let duration: String
    let description: String
    let thumbnailStyle: ThumbnailStyle
    let progress: Double

    init(
        id: UUID = UUID(),
        title: String,
        episodeNumber: Int,
        seasonNumber: Int = 1,
        duration: String = "45 min",
        description: String = "",
        thumbnailStyle: ThumbnailStyle,
        progress: Double = 0
    ) {
        self.id = id
        self.title = title
        self.episodeNumber = episodeNumber
        self.seasonNumber = seasonNumber
        self.duration = duration
        self.description = description
        self.thumbnailStyle = thumbnailStyle
        self.progress = progress
    }
}

// MARK: - Category Row

struct ContentCategory: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String?
    let contents: [LunaContent]
    let style: CategoryStyle

    enum CategoryStyle {
        case standard      // Regular horizontal scroll with poster cards
        case featured      // Larger cards, prominent display
        case top10         // Netflix-style numbered list
        case wideCard      // Wider landscape cards
        case continueWatching
    }

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        contents: [LunaContent],
        style: CategoryStyle = .standard
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.contents = contents
        self.style = style
    }
}

// MARK: - User

struct User: Identifiable {
    let id: UUID
    let name: String
    let avatar: AvatarStyle
    let isPremium: Bool
    var watchlist: [LunaContent]
    var watchHistory: [LunaContent]

    enum AvatarStyle {
        case purple, blue, rose, teal, amber

        var gradient: LinearGradient {
            switch self {
            case .purple:
                return LinearGradient(colors: [Color.lunaAccent, Color.lunaAccentLight],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
            case .blue:
                return LinearGradient(colors: [Color(hex: "1D4ED8"), Color(hex: "60A5FA")],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
            case .rose:
                return LinearGradient(colors: [Color(hex: "BE123C"), Color(hex: "FB7185")],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
            case .teal:
                return LinearGradient(colors: [Color(hex: "0F766E"), Color(hex: "5EEAD4")],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
            case .amber:
                return LinearGradient(colors: [Color(hex: "B45309"), Color(hex: "FCD34D")],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }

        var initials: String {
            switch self {
            case .purple: return "LN"
            case .blue: return "AB"
            case .rose: return "EC"
            case .teal: return "MK"
            case .amber: return "RS"
            }
        }
    }

    static let mock = User(
        id: UUID(),
        name: "Luna",
        avatar: .purple,
        isPremium: true,
        watchlist: [],
        watchHistory: []
    )
}

// MARK: - Mux Asset Mapping

extension LunaContent {
    static func fromMuxAsset(_ asset: MuxAsset) -> LunaContent {
        let recordingDate = asset.recordingDate
        let year = recordingDate.map { Calendar.current.component(.year, from: $0) }
            ?? Calendar.current.component(.year, from: Date())
        let daysAgo = recordingDate.map {
            Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 99
        } ?? 99
        let isNew = daysAgo < 30

        let styles: [ThumbnailStyle] = [.purple, .blue, .teal, .rose, .amber,
                                        .indigo, .emerald, .crimson, .violet, .ocean]
        let style = styles[abs(asset.id.hashValue) % styles.count]

        return LunaContent(
            title: asset.displayTitle,
            description: asset.lunaAgeAtRecording ?? "Video från Lunas bibliotek.",
            type: .movie,
            genre: [],
            rating: 0,
            year: year,
            duration: asset.formattedDuration,
            ageRating: .all,
            thumbnailGradient: style,
            heroGradient: style,
            isNew: isNew,
            muxPlaybackID: asset.primaryPlaybackID,
            recordingDate: recordingDate
        )
    }
}
