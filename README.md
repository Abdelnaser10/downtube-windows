# DownTube for Windows

YouTube **Video (MP4)** and **MP3** downloader for Windows — native downloads with real FFmpeg merging, **no server, no Python, no yt-dlp process**. Pure Flutter/Dart desktop app.

> The Android sibling app lives at [Abdelnaser10/downtube-android](https://github.com/Abdelnaser10/downtube-android).

---

## Features

- **Get Qualities, fast** — one lightweight innertube request returns the video metadata **and** every available format (cold ≈ 0.7 s, warm ≈ 0.2 s).
- **Video: MP4 quality cards with the real file size** on each card (144p → 2160p depending on the video; sizes are measured from the CDN, not guessed).
- **MP3: four bitrate cards** — 320 / 192 / 128 / 64 kbps, converted through real FFmpeg.
- **Playlists on both pages** — Video and MP3. Batch downloads run sequentially with per-item progress; **failing videos are skipped and listed at the end**. The Video tab cards show the **measured total size of the whole playlist** per quality (real bytes summed from every entry's manifest), live-updating as entries get measured.
- **Stop keeps finished files** — cancel mid-batch without losing what already completed.
- **Real titles, unicode intact** — files are named after the actual video title (Arabic, Japanese, emoji …), Windows-safe sanitization only.
- **Files in public folders** — everything lands in `Downloads\YouTubeDownloader` (selftests/probes excluded). Visible in Explorer immediately.
- **Stale-URL self-heal** — if a CDN link expires/403s mid-download, the job silently re-requests fresh URLs once and continues.

## What it does NOT do

- No sign-in-only content (age-restricted, members-only videos).
- No live streams.
- No site resumptions/retries beyond one automatic refresh per job.

## Requirements

- Windows 10 / 11 (x64).
- **FFmpeg** (strongly recommended): enables the high-quality MP4 merge and all MP3 bitrates. The app detects it automatically, in this order:
  1. next to `downtube.exe` (`ffmpeg.exe` in the same folder),
  2. on `PATH` (`where ffmpeg`),
  3. installed via WinGet (`Gyan.FFmpeg`),
  4. bundled fallback via the `imageio_ffmpeg` package.
- Without FFmpeg the app still works using muxed (video+audio-in-one) streams when YouTube offers them — MP3 needs FFmpeg.

## Build from source

```bat
flutter pub get
flutter build windows --release
```

Output: `build\windows\x64\runner\Release\downtube.exe` — ship the **whole Release folder** (exe + DLLs + data) as one unit.

## Testing

Engine regression suite (6 tests, needs internet):

```bat
D:\flutter\bin\dart.bat test test\engine_smoke_test.dart
```

Headless selftest on the real built exe (downloads a 480p merge + a 128 kbps MP3, verifies FFmpeg mux/convert end-to-end, writes `selftest.log`, deletes its own outputs):

```bat
set DOWNTUBE_SELFTEST=1
build\windows\x64\runner\Release\downtube.exe
```

## How the engine works

| Piece | File | Role |
|---|---|---|
| Innertube client | `lib/services/innertube_manifest.dart` | Seeds a visitor id (`youtubei/v1/visitor_id`), then a single `youtubei/v1/player` POST with the **VISIONOS** device context. That response carries `videoDetails` (title/author/duration/thumbnail) and ~28 adaptive formats with **direct, signed, full-length URLs** — no `n`-challenge, no PO tokens, no JS runtime, no watch-page scrape (kept only as fallback). |
| Service | `lib/services/youtube_service.dart` | Bundle cache per video (a download right after Get Qualities costs **zero** network; media URLs are valid ~6 h), retry-on-403 with fresh URLs, **built-in ranged downloader** (own `HttpClient`, 2 MB chunks, auto-halving chunk size on 4xx, connect/stall timeouts, cancel token, partial-file cleanup), FFmpeg merge (`-c:v copy -c:a aac` style passthrough) and MP3 extraction. |
| State | `lib/providers/app_provider.dart` | UI state machine (idle → fetching → success/playlist), playlist batch loop, progress reporting, Mix-playlist fallback. |
| UI | `lib/screens/home_screen.dart` + `widgets/` | Video Download / MP3 Download tabs above shared playlist logic, quality-card and bitrate-card grids, progress bar. |
| Models | `lib/models/` | `VideoInfo`, `PlaylistInfo`, `DownloadTask`. |

Why the VISIONOS client: modern YouTube throttles/challenges the classic web/android clients (silent 403s after ~6 MB, missing sizes, SABR shenanigans). The VISIONOS `player` context still answers with plain HTTPS streams, real `clen` sizes and generous rate caps — users get full-speed downloads. This is the same mechanism yt-dlp adopted in 2026 releases.

Fallbacks, in order: fresh innertube bundle → library (`youtube_explode_dart`, pinned to a community fork) metadata/re-pick → watch-page scrape → one force-refresh retry of the whole job on failure. `PlaylistCancelled` is never retried.

## Repo layout

```
lib/services/innertube_manifest.dart   VISIONOS innertube player client + visitor id + format parsing
lib/services/youtube_service.dart      bundle cache, ranged downloader, FFmpeg, download folders, selftest hook
lib/providers/app_provider.dart        state machine + playlist batch engine
lib/screens/home_screen.dart           main UI (tabs, cards, playlist status)
lib/widgets/                           quality_card, audio_card, progress_bar
lib/models/                            video_info, playlist_info, download_task
lib/main.dart                          app entry + headless selftest hook (DOWNTUBE_SELFTEST=1)
test/engine_smoke_test.dart            6-test engine regression suite (network)
windows/ · android/ · ios/ · linux/ · macos/ · web/   platform shells (only windows/ is maintained)
```

## Known limitations / roadmap

- [ ] No resume of interrupted partial downloads (jobs restart clean).
- [ ] Subtitle/thumbnail extras not handled.
- [ ] Playlist depth is whatever YouTube returns (no cap) — very large lists take a while.
