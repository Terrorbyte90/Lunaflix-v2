# Lunaflix v2 — Modern iOS Streaming App

En komplett, modern iOS streaming-app byggd med SwiftUI. Inspirerad av Netflix, Apple TV+ och Disney+ med ett unikt mörkt "luna"-tema.

## Funktioner

### Design
- **Djupt mörkt tema** — `#080810` bakgrund med lila/cyan accenter
- **Glassmorfism** — `.ultraThinMaterial` kort och transparenta ytor
- **Hero-karusell** — automatisk bildväxling med `TabView` + paginering
- **Flytande animationer** — `.spring()`, `.easeInOut` genomgående
- **Shimmer-laddning** — Netflix-liknande skeleton-loader
- **Matchad geometri** — smooth tab-switching med `@Namespace`

### Vyer
| Vy | Beskrivning |
|---|---|
| **HomeView** | Hero-karusell + kategorirader (Standard, Wide, Top 10, Featured, Continue Watching) |
| **SearchView** | Sökfält + genre-grid + dynamiska resultatsraster |
| **ContentDetailView** | Fullständig innehållssida med avsnittslista, statistik, handlingsknapp |
| **PlayerView** | Videospelare med sökning, undertextsinst., play/pause, hoppa 10s |
| **ProfileView** | Användarprofil, prenumerationskort, inställningar |
| **DownloadsView** | Nedladdade titlar med lagringsindikatot |

## Arkitektur

```
Lunaflix/
├── App/
│   └── LunaflixApp.swift        # @main entry, AppState
├── Theme/
│   └── AppTheme.swift           # Färger, typografi, animationer, modifiers
├── Models/
│   ├── Content.swift            # LunaContent, Episode, User, Genre, ThumbnailStyle
│   └── MockData.swift           # Exempelinnehåll (filmer, serier, dokumentärer)
├── ViewModels/
│   ├── HomeViewModel.swift      # Hero-timer, kategoriladdning
│   ├── SearchViewModel.swift    # Realtidssökning + filtrering
│   └── ProfileViewModel.swift   # Användardata, inställningar
└── Views/
    ├── Main/ContentView.swift   # Tab-navigation med custom tab bar
    ├── Home/                    # HomeView, HeroCarouselView, ContentRowView
    ├── Search/SearchView.swift  # Sök + genre-filter
    ├── Detail/                  # ContentDetailView, EpisodeRow
    ├── Player/PlayerView.swift  # Videospelargränssnitt
    ├── Profile/ProfileView.swift
    ├── Downloads/DownloadsView.swift
    └── Components/              # PosterCard, WideCard, Top10Card, FeaturedCard, LunaTabBar
```

## Krav
- iOS 16.0+
- Xcode 15+
- Swift 5.9+

## Öppna projektet

```bash
open Lunaflix.xcodeproj
```

## Design-system

### Färger
| Namn | Hex | Användning |
|---|---|---|
| `lunaBackground` | `#080810` | Huvudbakgrund |
| `lunaSurface` | `#0F0F1A` | Ytbakgrund |
| `lunaCard` | `#161625` | Kortkomponenter |
| `lunaAccent` | `#7C3AED` | Primärfärg (lila) |
| `lunaAccentLight` | `#A78BFA` | Ljus accent |
| `lunaCyan` | `#06B6D4` | Sekundär accent |
| `lunaGold` | `#F59E0B` | Betyg och premium |

### Typografi (`LunaFont`)
- `hero()` — 34pt, Black, Rounded
- `title1()` — 24pt, Bold, Rounded
- `title2()` — 20pt, Bold, Rounded
- `title3()` — 17pt, Semibold, Rounded
- `body()` — 15pt, Regular, Rounded
- `caption()` — 12pt, Medium, Rounded
- `tag()` — 11pt, Bold, Rounded

### Animationer
- `Animation.lunaSpring` — response 0.4, damping 0.75
- `Animation.lunaSnappy` — response 0.3, damping 0.85
- `Animation.lunaSmooth` — easeInOut 0.35s
