# Lunaflix

A personal iOS video archive app for Luna's clips, built with SwiftUI and Mux Video.

## What it is

Lunaflix is a private family video app that stores, streams, and organizes clips of Luna (born July 2, 2023). Videos are uploaded to [Mux](https://mux.com) and streamed via HLS. Each clip displays Luna's exact age at the time of recording.

## Tech stack

| Layer | Technology |
|---|---|
| UI | SwiftUI (iOS 17+) |
| Architecture | MVVM — `ObservableObject` / `@Published` / `@MainActor` |
| Video backend | Mux Video API (direct upload + HLS streaming) |
| Local download | `AVAssetDownloadURLSession` (background HLS download) |
| Photo library | `PhotosUI` / `PhotosPickerItem` + `Transferable` |
| Metadata | AVFoundation — extract recording date from video file |
| Credentials | Keychain (`KeychainService`) |
| State sharing | `ContentStore` (in-memory shared cache) |
| Reactive | Combine — debounced search |

## Architecture

```
LunaflixApp
└── ContentView (tab router + upload FAB)
    ├── HomeView          ← HomeViewModel ← ContentStore
    ├── SearchView        ← SearchViewModel ← MuxService
    ├── DownloadsView     ← DownloadManager (AVAssetDownloadURLSession)
    └── ProfileView       ← ProfileViewModel

Sheets:
    ContentDetailView     ← presented from any tab
    UploadView            ← UploadManager (multi-job, review → upload → poll)
    MuxSettingsView       ← MuxSettingsViewModel
    PlayerView            ← AVQueuePlayer + OrientationManager
```

### Upload flow

1. User picks a video from the photo library via `PhotosPicker`
2. `UploadManager` extracts the file and recording date metadata (AVFoundation)
3. Job pauses at **Review** phase — user can edit title and recording date
4. On confirm: Mux direct-upload URL is requested, file is uploaded, Mux asset is polled until ready
5. Recording date is stored in Mux's `passthrough` field as ISO8601 JSON

### Age display

`LunaAge` computes Luna's age in a human-readable Swedish string ("2 år 3 mån", "8 månader") from her birthday (July 2, 2023) and a given date. Used in `ContentDetailView` (stats row) and `UploadView` (live preview while editing date).

## Setup

1. Clone the repo and open `Lunaflix.xcodeproj` in Xcode 15+
2. Build and run on an iOS 17+ device or simulator
3. In the app, go to **Profil → Mux-inställningar**
4. Enter your Mux **Token ID** and **Token Secret** (needs `video:read` and `video:write` scopes)
5. Tap **Spara och testa** — the app will verify the connection and show your asset count
6. Upload videos using the **↑** FAB button or via **Snabblänkar → Ladda upp video**

## Project structure

```
Lunaflix/
├── App/
│   └── LunaflixApp.swift          # Entry point, AppDelegate, OrientationManager, AppState
├── Models/
│   ├── Content.swift              # LunaContent, ContentCategory, Genre, LunaAge
│   └── MuxAsset.swift             # Codable Mux API response models
├── Services/
│   ├── MuxService.swift           # Mux REST API client
│   ├── KeychainService.swift      # Keychain read/write for API credentials
│   ├── ContentStore.swift         # Shared in-memory content cache
│   ├── DownloadManager.swift      # AVAssetDownloadURLSession HLS downloads
│   └── UploadManager.swift        # Multi-job upload orchestration
├── ViewModels/
│   ├── HomeViewModel.swift
│   ├── SearchViewModel.swift
│   ├── ProfileViewModel.swift
│   └── MuxViewModel.swift         # VideoMetadata (AVFoundation), VideoTransferItem
├── Views/
│   ├── Main/ContentView.swift     # Tab router + splash screen
│   ├── Home/                      # HomeView, HeroCarouselView, ContentRowView
│   ├── Search/SearchView.swift
│   ├── Downloads/DownloadsView.swift
│   ├── Profile/ProfileView.swift
│   ├── Detail/ContentDetailView.swift
│   ├── Upload/UploadView.swift
│   ├── Player/PlayerView.swift
│   ├── Settings/MuxSettingsView.swift
│   └── Components/                # ContentCard, LunaTabBar, AppTheme
└── Resources/                     # Assets, fonts, Info.plist
```

## Design system

### Colors
| Name | Hex | Usage |
|---|---|---|
| `lunaBackground` | `#080810` | Main background |
| `lunaSurface` | `#0F0F1A` | Surface background |
| `lunaCard` | `#161625` | Card components |
| `lunaAccent` | `#7C3AED` | Primary accent (purple) |
| `lunaAccentLight` | `#A78BFA` | Light accent |
| `lunaCyan` | `#06B6D4` | Secondary accent |

### Typography (`LunaFont`)
- `hero()` — 34pt, Black, Rounded
- `title1()` — 24pt, Bold, Rounded
- `title2()` — 20pt, Bold, Rounded
- `title3()` — 17pt, Semibold, Rounded
- `body()` — 15pt, Regular, Rounded
- `caption()` — 12pt, Medium, Rounded

### Animations
- `Animation.lunaSpring` — response 0.4, damping 0.75
- `Animation.lunaSnappy` — response 0.3, damping 0.85
- `Animation.lunaSmooth` — easeInOut 0.35s

## Requirements

- iOS 17.0+
- Xcode 15.0+
- A Mux account with Token ID + Token Secret

## Status

- [x] Mux credential setup and connection test
- [x] HLS video streaming
- [x] Video upload with review step (title + recording date)
- [x] Recording date extraction from video metadata
- [x] Luna's age display per clip
- [x] Background HLS downloads
- [x] Search by title
- [x] Offline download management
- [ ] Push notifications for processing completion
- [ ] iCloud sync for download metadata
- [ ] Shared album / invite link generation
