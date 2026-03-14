import Foundation

// MARK: - Mock Data

enum MockData {
    static let allContent: [LunaContent] = movies + series + documentaries

    // MARK: - Movies

    static let movies: [LunaContent] = [
        LunaContent(
            title: "Skuggorna Vaknar",
            subtitle: "En episk sci-fi thriller",
            description: "I en framtid där mänskligheten koloniserat Mars börjar mystiska signaler nå jordens observatorier. En grupp elitforskare skickas ut på ett farligt uppdrag som ifrågasätter allt de vet om universum — och sig själva.",
            type: .movie,
            genre: [.scifi, .thriller],
            rating: 9.1,
            year: 2025,
            duration: "2t 18min",
            ageRating: .teen,
            thumbnailGradient: .indigo,
            heroGradient: .indigo,
            isTrending: true,
            isNew: true
        ),
        LunaContent(
            title: "Röda Djupet",
            subtitle: "Action på havets botten",
            description: "En hemlig militärbas djupt under havet håller på att kollapsa. En ensamvarg-dykare med en mörk historia är den enda som kan rädda de stranded besättningsmedlemmarna innan syret tar slut.",
            type: .movie,
            genre: [.action, .thriller],
            rating: 8.3,
            year: 2024,
            duration: "1t 56min",
            ageRating: .mature,
            thumbnailGradient: .ocean,
            isTrending: true
        ),
        LunaContent(
            title: "Tomma Rum",
            subtitle: "Psykologisk skräck",
            description: "En familj flyttar in i ett gammalt gods vid den svenska kusten. Men när natten faller börjar väggarna viska — och inte alla röster tillhör de levande.",
            type: .movie,
            genre: [.horror, .mystery],
            rating: 7.8,
            year: 2025,
            duration: "1t 45min",
            ageRating: .adult,
            thumbnailGradient: .crimson,
            isNew: true
        ),
        LunaContent(
            title: "Evighetens Pris",
            subtitle: "Drama baserat på verkliga händelser",
            description: "Den sanna historien om en ung vetenskapsman som uppfinner ett botemedel som hotar läkemedelsindustrins miljarder — och priset han betalar för att hålla sanningen vid liv.",
            type: .movie,
            genre: [.drama, .thriller],
            rating: 8.7,
            year: 2024,
            duration: "2t 05min",
            ageRating: .teen,
            thumbnailGradient: .amber
        ),
        LunaContent(
            title: "Stjärnstoft",
            subtitle: "Animerat äventyr",
            description: "En liten flicka som drömmer om stjärnorna bygger en raket av skrotdelar och flyger ut i ett magiskt universum fyllt av färgglada varelser och bortglömda galaxer.",
            type: .movie,
            genre: [.animation, .adventure, .fantasy],
            rating: 9.4,
            year: 2025,
            duration: "1t 32min",
            ageRating: .all,
            thumbnailGradient: .violet,
            isNew: true,
            isTrending: true
        ),
        LunaContent(
            title: "Neonblod",
            subtitle: "Cyberpunk noir",
            description: "I ett regnigt Neo-Stockholm 2077 söker en privatdetektiv med kyborgimplantat svar på ett mord som leder djupare in i megakorporationernas korruption.",
            type: .movie,
            genre: [.crime, .scifi, .thriller],
            rating: 8.5,
            year: 2024,
            duration: "2t 02min",
            ageRating: .mature,
            thumbnailGradient: .rose
        ),
        LunaContent(
            title: "Midvinterljus",
            subtitle: "Nordisk romantisk drama",
            description: "Under den långa nordiska natten möts två främlingar i en snöig by och inser att ödet knutit samman deras liv sedan länge.",
            type: .movie,
            genre: [.romance, .drama],
            rating: 8.0,
            year: 2025,
            duration: "1t 48min",
            ageRating: .teen,
            thumbnailGradient: .teal,
            isContinuing: true,
            continueProgress: 0.65
        ),
        LunaContent(
            title: "Betongjungeln",
            subtitle: "Urban action thriller",
            description: "En ex-polis utan framtid tvingas tillbaka in i en underjordisk värld av organiserad brottslighet för att rädda sin brors liv.",
            type: .movie,
            genre: [.action, .crime],
            rating: 7.9,
            year: 2024,
            duration: "1t 58min",
            ageRating: .mature,
            thumbnailGradient: .blue
        )
    ]

    // MARK: - Series

    static let series: [LunaContent] = [
        LunaContent(
            title: "Kroniken",
            subtitle: "Episk historisk drama",
            description: "En saga om ett kungadöme på randen av kollaps. Intriger, allianser och krig formar ödet för fem ätter som alla gör anspråk på den urgamla tronen.",
            type: .series,
            genre: [.drama, .fantasy, .adventure],
            rating: 9.6,
            year: 2023,
            duration: "1 säsong • 10 avsnitt",
            ageRating: .mature,
            thumbnailGradient: .amber,
            heroGradient: .amber,
            isTrending: true,
            numberOfSeasons: 2,
            episodes: makeEpisodes(count: 10, style: .amber)
        ),
        LunaContent(
            title: "Signal",
            subtitle: "Nordisk krimiserie",
            description: "En kriminalinspektör i Malmö börjar ta emot radiomeddelanden från ett brott som begicks för 25 år sedan — och inser att hon kan ändra historien.",
            type: .series,
            genre: [.crime, .mystery, .thriller],
            rating: 9.2,
            year: 2024,
            duration: "2 säsonger • 16 avsnitt",
            ageRating: .mature,
            thumbnailGradient: .teal,
            isTrending: true,
            isContinuing: true,
            continueProgress: 0.4,
            numberOfSeasons: 2,
            episodes: makeEpisodes(count: 8, style: .teal)
        ),
        LunaContent(
            title: "Parallella Liv",
            subtitle: "Sci-fi drama",
            description: "En kvinna vaknar upp i ett alternativt universum där hennes man aldrig dog — men universum kräver ett pris för att låta henne stanna.",
            type: .series,
            genre: [.scifi, .drama, .romance],
            rating: 8.9,
            year: 2025,
            duration: "1 säsong • 8 avsnitt",
            ageRating: .teen,
            thumbnailGradient: .purple,
            isNew: true,
            numberOfSeasons: 1,
            episodes: makeEpisodes(count: 8, style: .purple)
        ),
        LunaContent(
            title: "Mörka Vatten",
            subtitle: "Psykologisk thriller",
            description: "En liten kuststad skrämmas när invånare börjar försvinna. Den nye polischefen gräver i stadens historia och avslöjar hemligheter som var tänkta att aldrig komma fram.",
            type: .series,
            genre: [.thriller, .mystery, .horror],
            rating: 8.6,
            year: 2024,
            duration: "3 säsonger • 24 avsnitt",
            ageRating: .mature,
            thumbnailGradient: .ocean,
            isContinuing: true,
            continueProgress: 0.25,
            numberOfSeasons: 3,
            episodes: makeEpisodes(count: 8, style: .ocean)
        ),
        LunaContent(
            title: "Komedianter",
            subtitle: "Svensk komedi",
            description: "Tre vänner från Borlänge försöker bli kända komiker i Stockholm. En humoristisk och hjärtlig serie om drömmar, vänskap och att misslyckas på bästa möjliga sätt.",
            type: .series,
            genre: [.comedy, .drama],
            rating: 8.4,
            year: 2025,
            duration: "1 säsong • 6 avsnitt",
            ageRating: .teen,
            thumbnailGradient: .emerald,
            isNew: true,
            numberOfSeasons: 1,
            episodes: makeEpisodes(count: 6, style: .emerald)
        ),
        LunaContent(
            title: "Undervärld",
            subtitle: "Gangsterdrama",
            description: "Den brutala uppgången och fallet för en kriminell organisation i 1990-talets Göteborg, berättat ur tre generationers perspektiv.",
            type: .series,
            genre: [.crime, .drama],
            rating: 9.0,
            year: 2023,
            duration: "2 säsonger • 20 avsnitt",
            ageRating: .adult,
            thumbnailGradient: .crimson,
            numberOfSeasons: 2,
            episodes: makeEpisodes(count: 10, style: .crimson)
        )
    ]

    // MARK: - Documentaries

    static let documentaries: [LunaContent] = [
        LunaContent(
            title: "Naturens Kode",
            subtitle: "Planetens hemligheter",
            description: "En visuellt bedövande resa genom jordens mest extrema platser och de otroliga varelser som lärt sig överleva mot alla odds.",
            type: .documentary,
            genre: [.documentary],
            rating: 9.3,
            year: 2025,
            duration: "1t 25min",
            ageRating: .all,
            thumbnailGradient: .emerald,
            isNew: true
        ),
        LunaContent(
            title: "Algoritmens Hjärta",
            subtitle: "Tech-dokumentär",
            description: "Hur artificiell intelligens omformar samhället i en takt som mänskligheten aldrig sett tidigare — och de männen och kvinnorna som bestämmer reglerna.",
            type: .documentary,
            genre: [.documentary],
            rating: 8.8,
            year: 2024,
            duration: "1t 48min",
            ageRating: .all,
            thumbnailGradient: .blue
        )
    ]

    // MARK: - Categories

    static var categories: [ContentCategory] {
        [
            ContentCategory(
                title: "Fortsätt titta",
                contents: allContent.filter(\.isContinuing),
                style: .continueWatching
            ),
            ContentCategory(
                title: "Trending nu",
                subtitle: "Mest sedda just nu",
                contents: allContent.filter(\.isTrending),
                style: .top10
            ),
            ContentCategory(
                title: "Nytt på Lunaflix",
                contents: allContent.filter(\.isNew),
                style: .featured
            ),
            ContentCategory(
                title: "Serier vi älskar",
                contents: series,
                style: .standard
            ),
            ContentCategory(
                title: "Årets bästa filmer",
                contents: movies,
                style: .wideCard
            ),
            ContentCategory(
                title: "Dokumentärer",
                contents: documentaries,
                style: .standard
            )
        ].filter { !$0.contents.isEmpty }
    }

    static var heroContent: [LunaContent] {
        [movies[0], series[0], movies[4], series[2], movies[5]]
    }

    // MARK: - Helpers

    private static func makeEpisodes(count: Int, style: ThumbnailStyle) -> [Episode] {
        let titles = [
            "Piloten", "Skuggor", "Avslöjandet", "Återkomsten", "Gränsen",
            "Förlusten", "Sanningen", "Försoningen", "Kulmen", "Finalen"
        ]
        return (1...count).map { n in
            Episode(
                title: titles[(n - 1) % titles.count],
                episodeNumber: n,
                duration: "\(Int.random(in: 38...58)) min",
                description: "Avsnitt \(n) — En ny vändning förändrar allt.",
                thumbnailStyle: style,
                progress: n == 3 ? 0.5 : 0
            )
        }
    }
}
