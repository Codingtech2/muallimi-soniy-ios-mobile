# Muallimi Soniy — iOS handoff (continue on MacBook M1)

**Status: mid-build handoff (power outage on the other Mac). Everything below is committed + pushed to `main`. Pull and continue.**

Plan/dashboard artifact: https://claude.ai/code/artifact/4fa38d1c-84a5-4041-97e1-4fd653d2c6d8

## How to resume
1. `git clone https://github.com/Codingtech2/muallimi-soniy-ios-mobile.git` (repo is PUBLIC) or `git pull`.
2. Open in Xcode (or build via XcodeBuildMCP). Scheme `MuallimiSoniy`, sim **iPhone 17 Pro Max** (iOS 17 target).
3. A new Claude Code session: read this file, then finish **M5** first (below), then the remaining modules.

## Project facts
- Native SwiftUI, **1:1 with the web app** (`RenderedPage.tsx`). Deployment **iOS 17.0**, Swift 5 mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `@Observable` stores. Bundle `uz.vipads.MuallimiSoniy`, team `ZDBP5RSRZF`.
- **Xcode 16 file-system-synchronized groups**: just Write `.swift` under `MuallimiSoniy/` → auto-compiles. **NEVER hand-edit `project.pbxproj`** for new files. NEVER touch `MuallimiSoniy/Resources/`.
- Content is bundled: `Resources/book.json`, `i18n.json`, `legal.json`, `settings.json`, `audio-manifest.json`, `Fonts/*`.
- WEB SOURCE OF TRUTH (other repo, read-only): `/Users/codingtech/Documents/GitHub/muallimi_soniy` → `src/components/lesson/RenderedPage.tsx`, `src/app/globals.css`, `src/lib/audio/AudioEngine.ts`, `src/lib/data/data-provider.ts`. Content package: `public/content/`.
- Screenshot harnesses (DEBUG launch args in `MuallimiSoniyApp.swift`): `-MSPageOnly <bookPageNumber>` renders one page directly (reliable); `-MSReaderPage <globalIndex>`.

## DONE (pushed, build green)
- M1 Codable models + ContentStore (52 pages global flatten + outline).
- M2 Design system (light-default theme) + custom Arabic fonts + primitives (ArabicElementView, WordRow, Verse, SurahTitle, SectionTitle/Divider, MadComponents, PageContent).
- M3 Audio ENGINE (AVFoundation segment/repeat/loop, Now Playing, background). Adversarially reviewed vs AudioEngine.ts.
- M4 Reader (52-page pager, ReaderHeader, PageIndicator, AudioControls wired to M3, TocSheet). Home/Darslar entry.
- **ALL 52 pages (0–50) render bespoke 1:1** and are wired in `PageDispatcher.swift`.
- App icon (opaque), AccentColor green, launch screen fixed (Info.plist UILaunchScreen).
- Release **content-2.0.0** on GitHub has `audio.zip` (1757 files, 127MB, STORED). Publicly downloadable.

## M5 audio downloader — DONE + LIVE E2E TEST PASSED ✅
The reader taps already call `playSegment`, but on device `App Support/media/` is empty → all audio fails (Code 2003334207 = file not found) until the pack is downloaded. M5 does that.
- **DONE + BUILD SUCCEEDED + adversarial byte-level ZIP-spec review passed (all 7 checks):** `Offline/ZipStore.swift` (streamed STORED extractor, zip-slip guarded), `Offline/AudioManifest.swift`, `Offline/AudioDownloadManager.swift` (@MainActor @Observable: idle→checking→downloading→extracting→verifying→ready/failed, streamed SHA256 of all 1757 files, idempotent via UserDefaults "audioReadyContentVersion"=2.0.0, temp zip deleted, Task.detached heavy work). `MuallimiSoniyApp.swift` wired (`@State AudioDownloadManager` in env + `#if DEBUG` `-MSDownloadAudio` launch arg → `ensureReady()`). `MediaLocator.swift` verified correct (no change).
- Download URL (public, HTTP 200): `https://github.com/Codingtech2/muallimi-soniy-ios-mobile/releases/download/content-2.0.0/audio.zip`
- **LIVE E2E TEST PASSED (2026-07-21, iPhone 17 Pro Max sim):** download from public Release → extract → verify, app log: "Audio pack 2.0.0 installed and verified (1757 files)". 1757/1757 mp3 (125 MB) in App Support/media; independent sha256 spot-checks OK incl. spaced name "audio/02. Muqaddima.mp3"; extracted mp3 plays (afplay); ready flag "audioReadyContentVersion"="2.0.0" persisted → relaunches short-circuit. Device fix ships when M10 OfflineCard (in progress) gives the release-mode download button; final UX = M12 onboarding.

## REMAINING (after M5)
1. Font trim (~930K unused): drop `Amiri-Regular.ttf`, `NotoNaskhArabic-VariableFont_wght.ttf`, `UthmanicHafs.otf` from `Resources/Fonts/` + `DesignSystem/Fonts.swift` bundledFonts list. KEEP `NotoNaskhArabic-MuallimiSoniy.ttf` + `AmiriQuran.ttf`. (Mad verified to render with Amiri Quran.)
2. M10 Settings: 4-lang switch, theme (light default), font size, repeat stepper, legal modal, progress persistence (UserDefaults "davom eting").
3. Web-vs-iOS VISUAL QA: Playwright on live `muallimisoniy.uz`, screenshot each page, compare 1:1, refine mismatches.
4. `/code-review` (code-reviewer) + performance audit (swift-ios-performance-auditor): focus SwiftUI view-body bloat / re-renders. Keep bodies small.
5. **ONBOARDING page (FINAL, user's explicit last task)**: first-run screen — ideal explanation + ONE "Download" button that runs M5's `ensureReady()` + real-time ProgressView → then app fully offline. Persist "hasOnboarded".

## KNOWN BUGS
- **Pager deep-link**: `HorizontalBookPager` (ScrollView + LazyHStack + `.scrollPosition`) does NOT jump to a far page when the index is set in `onAppear` — stays on page 0. Breaks Darslar→lesson open + Home "Davom eting" resume. Fix: set the scroll target as `@State` from the entry BEFORE first layout (init), or ScrollViewReader `.scrollTo` in `.task`. Test far pages. (3 agent attempts failed + reverted.)

## Workflow pattern used
Multi-agent `/w` (Workflow tool): page renderers fanned out in parallel (each writes a separate `PageNView.swift`; ONE wire agent edits `PageDispatcher.swift` to avoid conflicts). Each code module: build via XcodeBuildMCP `build_sim`, screenshot-verify, commit + push. Verify tap-highlight visually (M2 proved it: green fill/scale/glow, neighbors never dimmed).
