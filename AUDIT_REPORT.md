# Lunaflix Audit Report

**Date:** 2026-03-16
**Scope:** Full codebase audit — bug fixes, dead code removal, UX polish, architecture review

---

## Summary

The codebase was audited and refactored across 7 areas. All mock/demo data was removed. A complete video upload flow was implemented with Mux integration and recording date support. Several views were corrected and dead code removed.

---

## Changes Made

### 1. Removed: `MockData.swift`

Deleted the file containing ~200 lines of fake Swedish movies, series, and documentaries. No references remained elsewhere after removal. The app now shows real content from Mux or empty states.

---

### 2. Rewritten: `UploadManager.swift`

**Problem:** No upload flow existed. Users had no way to add videos to the library.

**Solution:** Full multi-job upload manager with a mandatory review phase:

- `UploadJobPhase` enum: `loading → review → uploading → processing → done(MuxAsset) | failed(String)`
- `load()`: extracts file URL and recording date from `PhotosPickerItem` using AVFoundation, pauses at `.review`
- `continueUpload()`: requests Mux direct-upload URL, streams the file, polls until asset is ready
- `customTitle` / `suggestedTitle` / `effectiveTitle` pattern for title editing
- Recording date stored in Mux `passthrough` field as ISO8601 JSON so it survives round-trips
- `speedString` computed from bytes/interval for upload speed display

---

### 3. Rewritten: `UploadView.swift`

**Problem:** No upload UI existed.

**Solution:** Full upload sheet with:

- `PhotosPicker` button to select one or more videos
- Per-job `UploadJobCard` switching between `ReviewCard` and `ProgressCard`
- `ReviewCard`: gradient header with Luna's live age preview, editable title TextField, date picker button, upload confirmation
- `ProgressCard`: animated ring progress, speed string, checkmark on completion
- `DatePickerSheet`: graphical `DatePicker` with live Luna age preview and "Ta bort datum" option
- No-credentials state prompting user to configure Mux

---

### 4. Fixed: `HomeView.swift`

**Problems:**
- No state for unconfigured Mux (app appeared broken with no content)
- No state for empty library

**Fixes:**
- Added `notConfiguredState` view with moon icon and navigate-to-settings button
- Added `emptyLibraryState` view for configured but empty library
- Added `.refreshable { vm.refresh() }` for pull-to-refresh

---

### 5. Fixed: `HeroCarouselView.swift`

**Problem:** Used deprecated single-closure `onChange(of:)` syntax (warns on iOS 17+, removed in iOS 18).
**Fix:** Updated to two-parameter closure `onChange(of: value) { _, newVal in ... }`.

**Problem:** Hero overlay had a "+" watchlist button that did nothing.
**Fix:** Removed the dead button entirely.

---

### 6. Fixed: `SearchView.swift`

**Problems:**
- Top padding was 58pt, pushing content too far down
- Had ContentType filter pills wired to a removed filter system
- Placeholder text referenced "filmer, serier, dokumentärer" (removed from app)
- `filterChip` function was dead code after pill removal
- `genreGrid` was conditionally included but `featuredGenres` is always empty

**Fixes:**
- Reduced top padding 58 → 16
- Removed ContentType filter pills and `typeChip` function
- Removed dead `filterChip` function
- Updated placeholder to "Sök bland Lunas klipp..."
- Removed unreachable `genreGrid` block

---

### 7. Fixed: `DownloadsView.swift` / `ProfileView.swift`

**Problem:** Excessive top padding made both views start too far down on screen.
**Fix:** Reduced header top padding (Downloads: 58 → 16, Profile: 56 → 44).

---

### 8. Fixed: `MuxViewModel.swift`

**Problem:** `MuxViewModel` class was fully dead — never referenced by any view after the `UploadManager` redesign.
**Fix:** Deleted the class. The file retains `VideoMetadata` (AVFoundation recording date extraction) and `VideoTransferItem` (Transferable for `PhotosPicker`), which are both still needed.

---

### 9. Fixed: `SearchViewModel.swift`

**Problems:**
- Had `selectedType`, `allTypes`, `selectedGenre` publisher machinery for content-type filtering (removed from app)
- `isEmptySearch` and `hasActiveFilter` had complex conditional logic based on removed filters

**Fixes:**
- Removed all type-filter properties and publisher
- `hasActiveFilter` simplified to always `false`
- `isEmptySearch` simplified to `query.isEmpty`
- `performSearch()` simplified to query-only filter
- `clearFilters()` simplified

---

### 10. Fixed: `AppState` (`LunaflixApp.swift`)

**Problem:** `AppState` had unused `isLoggedIn: Bool` and `presentedContent: LunaContent?` properties.
**Fix:** Removed both unused published properties.

---

### 11. Fixed: `ProfileViewModel.swift`

**Problems:**
- `showingSettings: Bool` published property was never read
- `stats: [(label, value)]` computed property was dead code (ProfileView builds its own stats grid)

**Fix:** Removed both.

---

### 12. Fixed: `ContentDetailView.swift` — `statsRow`

**Problem:** Stats row showed Rating ("–", always 0), Year (from Mux `createdAt`, not recording date), and Type ("Film", always). Rating and Type were meaningless for personal videos.

**Fix:** Replaced with:
- **År** — from `content.recordingDate?.year` or Mux `createdAt` year
- **Längd** — from `content.duration`
- **Lunas ålder** — `LunaAge.ageShort(at: recordingDate)`, shown only when recording date is known

---

### 13. Fixed: `ContentRowView.swift`

**Problem:** "Se alla" button in row header called `LunaHaptic.light()` then did nothing. No navigation target existed.
**Fix:** Removed the button entirely.

---

### 14. Fixed: `ContentView.swift` — splash subtitle

**Problem:** Splash screen displayed "Streaming i världsklass" — a generic Netflix-style tagline irrelevant for a private family archive.
**Fix:** Changed to "Lunas videoarkiv".

---

### 15. Fixed: `MuxSettingsView.swift` + `ContentView.swift` — upload quick link

**Problem:** The "Ladda upp video" quick link in MuxSettingsView had a `// TODO` comment and did nothing.

**Fix:**
- Added `Notification.Name.openUploadSheet` extension in `ContentView.swift`
- `ContentView` now listens for this notification with `.onReceive` and sets `showUpload = true`
- `MuxSettingsView` "Ladda upp video" button now dismisses the settings sheet, then posts the notification after 0.3s (allowing the sheet dismiss animation to complete)

---

## Issues Not Fixed (Out of Scope / Future Work)

| Issue | Reason |
|---|---|
| `PlayerView` quality/subtitle selectors are cosmetic | Requires Mux track API integration — non-trivial |
| No push notifications for upload processing | Requires APNs backend — out of scope |
| `ContentStore` refresh is manual only | Background polling would need server-sent events or websockets |
| iCloud sync for downloads | Major feature — future roadmap |

---

## Architecture Observations

**Good:**
- Clean MVVM with proper `@MainActor` isolation throughout
- `ContentStore` as shared cache avoids redundant API calls across ViewModels
- `UploadManager` correctly decouples review phase from network phase, solving the immutable `passthrough` field problem
- `OrientationManager` singleton pattern is appropriate for a global device capability

**Could improve:**
- `DownloadManager` uses `UserDefaults` for progress persistence. An embedded SQLite store (or even Core Data) would be more robust for larger libraries.
- `MuxService` has no retry logic for transient network errors. Exponential backoff on asset polling would reduce flakiness on slow connections.
- Error handling in most ViewModels silently discards errors (`catch {}`). A proper error state or toast system would improve debuggability.

---

*Audit performed autonomously by Claude Code.*
