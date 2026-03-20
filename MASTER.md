# MASTER.md — Lunaflix

---

## Vision

Lunaflix is a personal streaming app — a private Netflix, built for one family, to watch one person grow up. Every video is of Luna. Every thumbnail is Luna. And the app automatically calculates exactly how old she was the day each video was filmed.

The core insight is simple and irreplaceable: standard photo libraries are unstructured archives. Lunaflix turns Luna's videos into a curated, beautiful, watchable experience — with a hero carousel, category rows organized by age and year, and the emotional centerpiece of the whole app: "Luna var 1 år och 3 månader gammal" on every single clip.

The finished product is an app that feels like Apple TV+ in its polish, but is entirely personal. It connects to Mux for video hosting and HLS streaming. It lets you upload videos directly from your photo library, extracts the recording date automatically, and builds a living archive that grows with Luna. Watching it should feel like love in software form.

**Who it's for:** Ted and family — a private audience of people who want to watch Luna's story play out in beautiful, organized, streaming quality.

**What makes Lunaflix different from every other solution:**
- Purpose-built for one person's story — not a generic gallery
- Luna's age is calculated and displayed for every single video, automatically
- Netflix-grade streaming UI with hero carousel, categories, and progress tracking
- Mux-powered HLS — flawless playback quality, no local storage limits
- Swedish interface; deeply personal; zero configuration needed after setup

---

## UI/UX Standards

### Visual Language

**Color Palette (LunaPalette):**
- Background: `#080810` (near-black with a blue midnight tint) — deep, cinematic, immersive
- Surface: `#0F0F1A` — subtle elevation above background
- Card: `#161625` — all content cards
- Elevated: `#1E1E30` — modals, sheets, overlays
- Primary accent: Purple `#7C3AED` — Luna's color; royalty, magic, night sky
- Accent light: `#A78BFA` — hover states, soft highlights
- Glow: `#6D28D9` — the signature purple glow on key elements
- Cyan: `#06B6D4` — secondary accent for contrast and energy
- Gold: `#F59E0B` — ratings, premium moments
- Warm: `#F472B6` — family warmth; used sparingly for emotional moments
- Pink: `#EC4899` — secondary accent, baby-appropriate warmth
- Text hierarchy: White (primary), `#A0A0B8` (secondary), `#606080` (muted)

**Typography (LunaFont):**
- `hero()` — 34pt, Black, Rounded — the app title, hero video titles
- `title1()` — 24pt, Bold, Rounded — section headers, video detail titles
- `title2()` — 20pt, Bold, Rounded — category row titles
- `title3()` — 17pt, Semibold, Rounded — card labels, tab titles
- `body()` — 15pt, Regular, Rounded — descriptions, metadata
- `caption()` — 12pt, Medium, Rounded — age labels, timestamps
- `tag()` — 11pt, Bold, Rounded — genre tags, age rating badges
- `mono()` — Monospaced — durations, file sizes, technical values

**Spacing and animation:** lunaSpring (0.4s, 0.75 damping), lunaSnappy (0.3s, 0.85 damping), lunaSmooth (easeInOut 0.35s), lunaBounce for playful moments, lunaGentle for large transitions.

### Screen Behavior

**Home:** The hero carousel dominates. Five featured videos rotate automatically every 5 seconds, filling the full screen width with a gradient overlay and the video title + Luna's age at recording. Below it: category rows — "Recently Added," "By Year," organized wide-card rows. The navbar is transparent at the top, frosted glass after scrolling. Pull-to-refresh with a satisfying animation. Shimmer skeleton loaders while content loads — never a blank screen.

**Search:** Large search input with real-time filtering. Genre grid with 2 columns and gradient genre cards. Results in a 3-column grid of poster thumbnails. Filter chips for genre + content type — always visible, easy to clear.

**Player:** Full-screen, landscape-oriented. Controls fade out after 3 seconds of inactivity. Seek bar with buffering indication. 10-second skip buttons. Luna's age at recording is shown in the overlay. When a video ends, the next one queues automatically. Mux analytics run silently for playback quality.

**Upload:** A clear flow — pick videos from photo library (up to 10 at once), watch the system extract creation dates automatically, see a progress card per video with percentage, speed in MB/s, and a processing status from Mux. When done, a success state that's satisfying rather than clinical.

**Profile:** Cinematic header with gradient and glow blobs. Stats cards (total videos, total hours). Recent activity scroll. Settings for streaming quality, autoplay, notifications. Mux credential configuration.

### Interaction Principles

- **Glassmorphism everywhere:** `.ultraThinMaterial` with purple-tinted opacity overlays — the app feels like it's made of moonlight
- **Matched geometry transitions:** switching between home and detail is smooth, not jarring
- **Haptic feedback:** light on scroll interactions, medium on play/pause, heavy on upload complete, success on processing done
- **Shimmer loading:** Netflix-style skeleton with animated gradient — every content load state is graceful
- Custom tab bar with pill-shaped gradient background that slides with matched geometry between tabs
- Asymmetric navigation transitions: content inserts from the right, removes with opacity — feels native and polished
- Kingfisher for all image loading: 200MB disk cache, 50MB memory cache, shimmer fallback on every thumbnail

### What Premium Means for Lunaflix

Premium in Lunaflix means the app honors what it contains. These videos are irreplaceable. Luna being three months old will only exist once, and this app is the archive. The deep purple-black palette is cinematic — watching these videos should feel like settling into a theater, not scrolling a camera roll. The hero carousel should be genuinely beautiful, with gradient overlays and the video title large enough to read from across the room. Luna's age display — "Luna var 1 år och 3 månader gammal" — should feel like a label on a memory, not a database field. The upload experience should feel trustworthy and fast; you're handing over precious files and the app should communicate that it's treating them with care. Every animation, every shimmer, every glow exists to say: this content matters.

---

## Daily Improvement Loop

* Pull latest from git, verify local is fully synced before touching anything
* Read all project files, git log, and any DECISIONS.md to understand current state
* Review /agents folder and invoke relevant agents in parallel for today's tasks
* Research what competitors have shipped recently and what users are currently requesting
* Identify the 3-5 highest value tasks today: new features, UI polish, bug fixes, performance
* Create a detailed execution plan and carry it out fully and autonomously
* After each major change — build and verify it compiles
* Commit with descriptive messages after each logical unit of work
* Push to git when session is complete
* Write a short summary of what was done today to PROGRESS.md

---

## Feature Backlog

Prioritized by personal value and viewing experience:

1. **"Luna's age" milestone categories** — automatic category rows like "Luna's First Year," "Luna Turns 2," "Newborn Moments" — emotional curation without manual effort
2. **Chromecast / AirPlay support** — cast to the TV; this is fundamentally a viewing-on-the-big-screen experience
3. **Offline downloads** — DownloadManager is built but UI needs polish; downloading Luna's best clips for airplane/travel viewing is high value
4. **Video chapters / highlights** — mark favorite moments within a video with timestamps; "first laugh," "first steps"
5. **Memories view** — "On this day" section showing videos recorded exactly 1, 2, 3 years ago today
6. **Background playback** — audio continues when the screen locks; useful when playing videos while doing something else
7. **Smart collections** — auto-generated playlists: "Longest Videos," "This Month," "Holiday Season"
8. **Share clips** — select a video and share directly to Messages, WhatsApp, or save to Camera Roll
9. **Search by age** — filter videos by "Luna was between 6–12 months" — timeline-based discovery
10. **Multiple subjects** — architecture currently assumes Luna only; extensible to add another child's video archive

---

## Known Issues

| Priority | Issue | Notes |
|----------|-------|-------|
| **High** | No Chromecast/AirPlay casting | Watching on TV is a primary use case; AVKit has AirPlay support built-in but not yet enabled |
| **High** | Downloads UI needs polish | DownloadManager is functional but the UX for managing, resuming, and organizing downloads is incomplete |
| **Medium** | Demo mode fallback in PlayerViewModel | When no Mux playback ID exists, player falls back silently; should show a clear "processing" state instead |
| **Medium** | No "On this day" feature | High-value emotional feature using existing recording date data; not yet built |
| **Medium** | No share/export functionality | Users cannot share clips to Messages or other apps |
| **Medium** | Search does not filter by Luna's age | Can search by title but not by "age at recording"; a key discovery pattern |
| **Low** | MuxService pagination limited to 2000 assets | Hard ceiling; fine for personal use but should paginate properly if archive grows |
| **Low** | UserDefaults used for settings persistence | Works fine for current scale; consider migrating to AppStorage for cleaner SwiftUI integration |
| **Low** | No background playback | Audio stops when screen locks; AVAudioSession activation needed |
| **Low** | Kingfisher cache size hardcoded | 200MB disk / 50MB memory; should respect available device storage |
