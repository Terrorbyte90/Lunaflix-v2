# LunaFlix Multi-Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make LunaFlix's multi-video upload reliable and legible on iPhone and iPad mini.

**Architecture:** `UploadManager` owns picker-item references and schedules at most two jobs concurrently. Each job remains independently observable, retryable, cancellable, and isolated from failures. SwiftUI renders both per-file progress and weighted total byte progress.

**Tech Stack:** SwiftUI, PhotosUI, URLSession file upload, Mux Direct Upload, XCTest, Xcode iOS Simulator.

**Spec:** `docs/superpowers/specs/2026-03-19-full-modernization-design.md`

## Global Constraints

- Work only in the `LunaFlix-v2` repository.
- Keep changes on branch `Final31Aug`; do not modify `main` directly.
- Stream large files from disk; never load complete videos into memory.
- Do not commit credentials or temporary video files.

### Task 1: Queue policy and scheduler

**Files:**
- Modify: `Lunaflix/Services/UploadManager.swift`
- Modify: `LunaflixTests/MuxAssetTests.swift`

- [x] Add a pure queue policy for concurrency and weighted byte progress.
- [x] Store each `PhotosPickerItem` by job ID and launch only two jobs at once.
- [x] Retain failed jobs and original picker items so retry is real.
- [x] Keep cancellation isolated to the selected job and launch the next queued job.
- [x] Clear retained references when finished jobs are removed.

### Task 2: Upload presentation

**Files:**
- Modify: `Lunaflix/Views/Upload/UploadView.swift`
- Modify: `Lunaflix/Views/Downloads/DownloadsView.swift`

- [x] Show total weighted progress and active queue count.
- [x] Constrain content width for iPad while keeping full-width phone controls.
- [x] Render paused state explicitly and update enum-case pattern matching for current Swift.

### Task 3: Verification and delivery

- [ ] Run the full unit-test suite and app build for iPhone Air and iPad mini simulators.
- [ ] Review git diff for scope and secrets, commit logically, and push `Final31Aug`.
