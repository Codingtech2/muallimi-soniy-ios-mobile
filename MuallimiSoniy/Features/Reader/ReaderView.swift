import SwiftUI
import Foundation
import UIKit

/// Where the reader should open. Mirrors the web lesson-page entry contract: a
/// lesson id + 0-based `lessonPageIndex` (the `?page=` query param), or a direct
/// 0-based global page index across the whole book.
enum ReaderEntry: Equatable, Hashable, Sendable {
    case lesson(id: String, pageIndex: Int)
    case global(index: Int)
}

/// The reader screen — the native port of the web lesson page's "one big book"
/// model. Loads every `BookPage` in reading order, hosts a horizontally-paged
/// container, and drives per-element highlight plus segment audio.
///
/// Chrome (header, page indicator, audio bar, TOC) lands in M4 Stage 2; this
/// stage wires the content, tap-to-play, page-change and sequential playback.
struct ReaderView: View {
    @Environment(ContentStore.self) private var store
    @Environment(AudioController.self) private var audio
    @Environment(AudioDownloadManager.self) private var downloadManager
    @Environment(ProgressStore.self) private var progress
    @Environment(SettingsStore.self) private var preferences

    /// Where to open. Resolved to `currentPageIndex` on first appear.
    let entry: ReaderEntry

    /// Logical current page (0-based global index) — the single source of truth
    /// for which page's elements are live. The pager's scroll position follows it.
    @State private var currentPageIndex = 0
    /// The one highlighted element across the whole book (`nil` = none).
    @State private var activeElementId: String?
    /// One-shot guard so the start page is resolved only on the first appear.
    @State private var didResolveStart = false
    /// Persistent cursor for sequential playback (a reference, like the web ref).
    @State private var sequential = SequentialCursor()
    /// Whether the table-of-contents sheet is presented.
    @State private var tocOpen = false
    /// Whether the reading-options ("Aa") sheet is presented.
    @State private var readingOptionsOpen = false
    /// Loop toggle state, kept in sync with the audio engine.
    @State private var loopMode = false
    /// Drives the "audio not downloaded" alert. Shared by the tap and
    /// play/pause handlers so at most one alert is ever on screen — setting
    /// this to `true` while it is already `true` is a no-op for SwiftUI.
    @State private var showAudioNotDownloadedAlert = false

    /// UI / content locale for titles + labels — follows the user's setting, so
    /// switching language live-updates the header, TOC and page labels.
    private var locale: AppLocale { preferences.settings.locale }

    /// The reader's live page/text palette (paper/sepia/gray/night), injected
    /// into `\.readingTheme` for `PageHostView` + the reading primitives.
    /// Only the reader reads this — Home/Contents/Settings stay on `AppColor`.
    private var readingTheme: ReadingBackground { preferences.settings.readingBackground }

    /// The reader's live rendering + accessibility context (line spacing,
    /// bold text, strong highlight, localized VoiceOver strings), injected
    /// into `\.readingAdjustments` for the reading primitives.
    private var readingAdjustments: ReadingAdjustments {
        ReadingAdjustments(
            lineSpacingScale: preferences.settings.lineSpacingScale,
            boldText: preferences.settings.boldText,
            strongHighlight: preferences.settings.strongHighlight,
            playHint: store.t("a11y_play_hint", locale),
            activeValueLabel: store.t("play", locale)
        )
    }

    private var pages: [BookPage] { store.allBookPages }
    private var currentPage: BookPage? {
        pages.indices.contains(currentPageIndex) ? pages[currentPageIndex] : nil
    }

    /// Whether the current page has any audio in the data (lesson track or a
    /// per-element chunk). Mirrors the web `hasAudio` gate for showing the bar —
    /// independent of whether the media pack is downloaded yet (M5).
    private var hasAudio: Bool {
        guard let page = currentPage else { return false }
        return page.lesson.audioUrl != nil || page.elements.contains { $0.audioUrl != nil }
    }

    var body: some View {
        Group {
            if pages.isEmpty {
                ContentUnavailableView(
                    store.t("book_not_found", locale),
                    systemImage: "book.closed",
                    description: Text(store.t("content_not_loaded", locale))
                )
            } else {
                readerContent
            }
        }
        // Attached *before* the environment writes below so the bar inherits
        // the same `\.readingTheme` the pages use — a `.safeAreaInset` view is
        // a sibling of the content, not a descendant, so a later modifier is
        // the only way both see the same value.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !pages.isEmpty {
                controlBar
            }
        }
        .background(readingTheme.pageFill.ignoresSafeArea())
        .environment(\.readingTheme, readingTheme)
        .environment(\.readingAdjustments, readingAdjustments)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
        // The bar sits above a *horizontal* pager, so its automatic scroll-edge
        // tracking never sees the per-page vertical scrolling: it decides it is
        // always at the top, stays transparent, and page text shows through it.
        // Pin the background visible and paint it with the page fill so each
        // reading background keeps its own colour. Occlusion at the top edge is
        // unrecoverable — the reader cannot scroll a clipped ḥaraka back into
        // view — so the bar stays opaque at every scroll offset by design.
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(readingTheme.pageFill, for: .navigationBar)
        .modifier(
            ReaderNavigationTitle(
                title: currentPage?.lesson.title.text(locale) ?? "",
                counter: "\(currentPageIndex + 1)/\(pages.count)",
                titleColor: readingTheme.textMain,
                counterColor: readingTheme.textMuted
            )
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    readingOptionsOpen = true
                } label: {
                    Image(systemName: "textformat")
                        .imageScale(.large)
                }
                .accessibilityLabel(store.t("reading_options", locale))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    tocOpen = true
                } label: {
                    Image(systemName: "list.bullet")
                        .imageScale(.large)
                }
                .accessibilityLabel(store.t("lessons", locale))
            }
        }
        .sheet(isPresented: $tocOpen) {
            TocSheet(
                outline: store.outline,
                currentLessonId: currentPage?.lessonId ?? "",
                currentGlobalPage: currentPageIndex + 1,
                totalPages: pages.count,
                contentsLabel: store.t("contents", locale),
                pageLabel: store.t("page", locale),
                pageOfFormat: store.t("page_of", locale),
                jumpToPageLabel: store.t("jump_to_page", locale),
                closeLabel: store.t("close", locale),
                locale: locale,
                onSelectGlobalPage: { goToPage($0 - 1) }
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $readingOptionsOpen) {
            ReadingOptionsSheet()
                .presentationDetents([.medium, .large])
        }
        .alert(
            store.t("audio_not_downloaded", locale),
            isPresented: $showAudioNotDownloadedAlert
        ) {
            Button(store.t("download_now", locale)) {
                Task { await downloadManager.ensureReady() }
            }
            Button(store.t("cancel", locale), role: .cancel) {}
        } message: {
            Text(store.t("audio_not_downloaded_desc", locale))
        }
        .onAppear {
            resolveStartIfNeeded()
            configureAudioDefaults()
            wireRemoteCommands()
            recordProgress()
            applyKeepScreenAwake()
        }
        .onChange(of: currentPageIndex) {
            recordProgress()
        }
        .onChange(of: preferences.settings.speed) {
            audio.setSpeed(preferences.settings.speed)
        }
        .onChange(of: preferences.settings.volume) {
            audio.setVolume(preferences.settings.volume)
        }
        .onChange(of: preferences.settings.keepScreenAwake) {
            applyKeepScreenAwake()
        }
        .onDisappear {
            cancelSequential()
            audio.onRemoteNext = nil
            audio.onRemotePrev = nil
            audio.stop()
            AudioSession.shared.deactivate()
            // Always release the idle-timer lock on the way out, even if the
            // setting was left on — the reader must never pin the screen
            // awake once the user has left it.
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    /// The pager, measured once. This `GeometryReader` sits inside the
    /// navigation stack's content *and* inside the bottom `.safeAreaInset`, so
    /// the size it reports is already post-nav-bar and post-control-bar — the
    /// single number every page cell is sized from.
    private var readerContent: some View {
        GeometryReader { geo in
            HorizontalBookPager(
                pages: pages,
                viewport: geo.size,
                currentIndex: $currentPageIndex,
                activeElementId: activeElementId,
                onElementTap: handleElementTap,
                onPageSettled: { _ in pageDidChange() }
            )
        }
    }

    /// The one bottom bar. Page stepping, element transport and loop live here
    /// together; the 52-page scrubber it replaces demanded ±2.2pt of drag
    /// precision per page, and precise jumps now live in the TOC sheet instead.
    private var controlBar: some View {
        ReaderControlBar(
            hasAudio: hasAudio,
            canGoPrevPage: currentPageIndex > 0,
            canGoNextPage: currentPageIndex < pages.count - 1,
            loopOn: loopMode,
            prevPageLabel: store.t("prev_page", locale),
            nextPageLabel: store.t("next_page", locale),
            prevElementLabel: store.t("prev_element", locale),
            nextElementLabel: store.t("next_element", locale),
            playLabel: store.t("play", locale),
            pauseLabel: store.t("pause", locale),
            loopLabel: store.t("loop", locale),
            onPrevPage: { goToPage(currentPageIndex - 1) },
            onNextPage: { goToPage(currentPageIndex + 1) },
            onPrevElement: handlePrevElement,
            onNextElement: handleNextElement,
            onPlayPause: handlePlayPause,
            onToggleLoop: toggleLoop
        )
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}

/// The reader's navigation title. iOS 26 gained a real two-part inline title,
/// so the page counter goes into `navigationSubtitle` there; below that it is
/// one `Text` run appended to the lesson name, which keeps the bar at its
/// system 44pt height. The chapter name is deliberately gone — it grew the bar
/// to 54pt and rendered a literal duplicate on the surah pages, where the
/// lesson title and the chapter title are the same string.
private struct ReaderNavigationTitle: ViewModifier {
    let title: String
    let counter: String
    let titleColor: Color
    let counterColor: Color

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .navigationTitle(title)
                .navigationSubtitle(counter)
        } else {
            content.toolbar {
                ToolbarItem(placement: .principal) {
                    (
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(titleColor)
                        + Text(" · \(counter)")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(counterColor)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                }
            }
        }
    }
}

/// Action + lifecycle helpers, split from the main declaration purely to keep
/// each declaration's body under SwiftLint's `type_body_length` — `private`
/// still grants full access to `ReaderView`'s stored properties from any
/// extension in this same file, so this is a mechanical split, not a
/// behavior change.
private extension ReaderView {

    // MARK: - Start resolution

    /// Jumps to the requested start page on first appear (no animation), mirroring
    /// the web init effect (`page=` match → lesson-first fallback → 0).
    private func resolveStartIfNeeded() {
        guard !didResolveStart, !pages.isEmpty else { return }
        didResolveStart = true
        let target = startIndex(for: entry)
        guard target != currentPageIndex else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { currentPageIndex = target }
    }

    private func startIndex(for entry: ReaderEntry) -> Int {
        switch entry {
        case let .lesson(id, pageIndex):
            if let match = pages.firstIndex(where: { $0.lessonId == id && $0.lessonPageIndex == pageIndex }) {
                return match
            }
            if let lessonStart = pages.firstIndex(where: { $0.lessonId == id }) {
                return lessonStart
            }
            return 0
        case let .global(index):
            return min(max(index, 0), pages.count - 1)
        }
    }

    // MARK: - Progress

    /// Persists the current page as "last viewed" and, when it is the final page
    /// of its lesson (the next page belongs to a different lesson or there is
    /// none), marks that lesson complete. Mirrors the web save effect.
    private func recordProgress() {
        guard let page = currentPage else { return }
        progress.setLastViewed(
            chapterId: page.chapter.id,
            lessonId: page.lessonId,
            globalIndex: page.globalIndex
        )
        let next = pages.indices.contains(currentPageIndex + 1) ? pages[currentPageIndex + 1] : nil
        if next?.lessonId != page.lessonId {
            progress.markLessonComplete(page.lessonId)
        }
    }

    // MARK: - Element tap

    /// Highlights the tapped element and plays its segment. The highlight always
    /// switches to the tapped element — even when audio is unavailable (the media
    /// pack may not be downloaded yet) the tap still lands (web parity). When the
    /// element does carry an audio path but the file isn't installed yet, this
    /// offers the download instead of silently playing nothing.
    private func handleElementTap(_ element: Element) {
        cancelSequential()
        activeElementId = element.id
        guard element.start != element.end else { return }
        guard let url = audioURL(for: element) else { return }
        guard MediaLocator.exists(url) else {
            offerDownloadIfMissing()
            return
        }
        if let page = currentPage {
            audio.setNowPlaying(
                title: element.arabic,
                artist: element.uzbek,
                album: page.lesson.title.text(locale)
            )
        }
        Task { await audio.playSegment(url: url, start: element.start, end: element.end) }
    }

    /// Per-element audio: the element's own chunk, falling back to the lesson's
    /// full-length track (mirrors `el.audioUrl || lesson.audioUrl`).
    private func audioURL(for element: Element) -> URL? {
        MediaLocator.url(for: element) ?? currentPage.flatMap { MediaLocator.url(for: $0.lesson) }
    }

    /// Surfaces the "audio not downloaded" alert when playback would otherwise
    /// silently fail because the offline pack isn't installed yet. Never fires
    /// once the pack is marked ready — an individual file missing from an
    /// already-verified pack shouldn't happen, and there's no useful action to
    /// offer for it, so that edge case just keeps today's silent behaviour.
    private func offerDownloadIfMissing() {
        guard !downloadManager.isReady else { return }
        showAudioNotDownloadedAlert = true
    }

    // MARK: - Page change

    /// Page changed (user swipe): stop audio and clear the highlight. The index
    /// itself is owned by the pager's binding, so we don't set it here.
    private func pageDidChange() {
        cancelSequential()
        activeElementId = nil
        audio.stop()
    }

    // MARK: - Chrome actions

    /// Programmatic jump (page indicator / TOC). Mirrors the web `handlePageChange`:
    /// stops audio, clears the highlight, then moves the pager to `index`. The
    /// jump is instant (no animation) so it stays reliable across long distances
    /// in the lazy pager. The pager's own settle callback does not fire for a
    /// programmatic move, so the cleanup happens here.
    private func goToPage(_ index: Int) {
        let target = min(max(index, 0), pages.count - 1)
        guard target != currentPageIndex else { return }
        cancelSequential()
        activeElementId = nil
        audio.stop()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { currentPageIndex = target }
    }

    /// Central play / pause intent, mirroring the web `onPlayPause`:
    /// pause if playing → resume a paused sequence → replay the active element →
    /// otherwise start sequential playback of the page. Offers the download
    /// alert instead of playing nothing when the active element's file isn't
    /// installed yet (see `offerDownloadIfMissing`).
    private func handlePlayPause() {
        if audio.isPlaying { audio.pause(); return }
        if sequential.active, activeElementId != nil { audio.resume(); return }
        if let page = currentPage, let id = activeElementId,
           let element = page.elements.first(where: { $0.id == id }),
           element.start < element.end {
            guard let url = MediaLocator.url(for: element) ?? MediaLocator.url(for: page.lesson) else {
                return
            }
            guard MediaLocator.exists(url) else {
                offerDownloadIfMissing()
                return
            }
            audio.setNowPlaying(
                title: element.arabic,
                artist: element.uzbek,
                album: page.lesson.title.text(locale)
            )
            Task { await audio.playSegment(url: url, start: element.start, end: element.end) }
            return
        }
        startSequentialPlay()
    }

    /// Toggles loop mode and pushes it to the audio engine.
    private func toggleLoop() {
        loopMode.toggle()
        audio.setLoopMode(loopMode)
    }

    /// Mirrors the "keep screen awake" reading option onto the idle timer.
    /// Called on appear and live via `onChange` (the reading-options sheet
    /// can flip the setting while the reader is already on screen), so the
    /// lock engages/releases immediately rather than only on next visit.
    /// `onDisappear` always forces this back to `false` regardless of the
    /// setting — see the note there.
    private func applyKeepScreenAwake() {
        UIApplication.shared.isIdleTimerDisabled = preferences.settings.keepScreenAwake
    }

    /// Applies the engine defaults once the reader appears: repeat count + loop +
    /// speed + volume from the user's settings (repeatCount resets to 1 each
    /// launch; speed/volume persist). Speed/volume also re-apply live via
    /// `onChange` so the settings screen updates playback immediately.
    private func configureAudioDefaults() {
        audio.setRepeatCount(preferences.settings.repeatCount)
        audio.setSpeed(preferences.settings.speed)
        audio.setVolume(preferences.settings.volume)
        loopMode = preferences.settings.loopMode
        audio.setLoopMode(loopMode)
    }

    // MARK: - Sequential playback (mirror `startSequentialPlay`)

    /// Plays every element on the current page that has audio, in order, chaining
    /// via `AudioController.onSegmentComplete`. Wired for the M4 Stage 2 play
    /// button. Captures only reference types + bindings (never the view struct),
    /// so the stored callback stays valid across renders.
    private func startSequentialPlay() {
        cancelSequential()
        guard let page = currentPage else { return }
        let fallback = MediaLocator.url(for: page.lesson)
        let playable = page.elements.filter {
            (MediaLocator.url(for: $0) != nil || fallback != nil) && $0.start != $0.end
        }
        guard !playable.isEmpty else { return }

        sequential.elements = playable
        sequential.index = 0
        sequential.active = true

        let cursor = sequential
        let controller = audio
        let activeBinding = $activeElementId
        // Album is the lesson title of the page being played (constant across the
        // sequence); captured by value so the stored closure needs no view struct.
        let album = page.lesson.title.text(locale)

        func play(_ index: Int) {
            guard cursor.active else { return }
            guard index < cursor.elements.count else {
                cursor.active = false
                controller.onSegmentComplete = nil
                activeBinding.wrappedValue = nil
                return
            }
            cursor.index = index
            let element = cursor.elements[index]
            activeBinding.wrappedValue = element.id
            let url = MediaLocator.url(for: element) ?? fallback
            if let url {
                controller.setNowPlaying(title: element.arabic, artist: element.uzbek, album: album)
                Task { await controller.playSegment(url: url, start: element.start, end: element.end) }
            }
        }

        controller.onSegmentComplete = {
            guard cursor.active else { return }
            play(cursor.index + 1)
        }
        play(0)
    }

    /// Stops any in-flight sequence and detaches the completion handler (also
    /// breaks the controller's self-reference through the stored closure).
    private func cancelSequential() {
        sequential.active = false
        audio.onSegmentComplete = nil
    }

    // MARK: - Remote commands (lock screen / Control Centre)

    /// Wires the Now Playing next/previous track buttons to per-element navigation.
    /// Captures only stable references (environment stores + state bindings), never
    /// the view struct, so the long-lived handlers read live page/element state and
    /// the audio controller never retains itself through them (`[weak audioRef]`).
    private func wireRemoteCommands() {
        let store = self.store
        let preferences = self.preferences
        let sequential = self.sequential
        let pageBinding = $currentPageIndex
        let activeBinding = $activeElementId
        let audioRef = self.audio

        let navigate: (Int) -> Void = { [weak audioRef] offset in
            guard let audioRef else { return }
            let pages = store.allBookPages
            let index = pageBinding.wrappedValue
            guard pages.indices.contains(index) else { return }
            let page = pages[index]
            guard let active = activeBinding.wrappedValue,
                  let position = page.elements.firstIndex(where: { $0.id == active }) else { return }
            let target = position + offset
            guard page.elements.indices.contains(target) else { return }
            let element = page.elements[target]
            // Cancel any in-flight sequence, then select + play the neighbour.
            sequential.active = false
            audioRef.onSegmentComplete = nil
            activeBinding.wrappedValue = element.id
            guard element.start != element.end,
                  let url = MediaLocator.url(for: element) ?? MediaLocator.url(for: page.lesson)
            else { return }
            audioRef.setNowPlaying(
                title: element.arabic,
                artist: element.uzbek,
                album: page.lesson.title.text(preferences.settings.locale)
            )
            Task { await audioRef.playSegment(url: url, start: element.start, end: element.end) }
        }

        audio.onRemoteNext = { navigate(1) }
        audio.onRemotePrev = { navigate(-1) }
    }

    // MARK: - Per-element prev / next (wired for M4 Stage 2 chrome)

    private func handlePrevElement() {
        guard let page = currentPage, let active = activeElementId,
              let index = page.elements.firstIndex(where: { $0.id == active }), index > 0 else { return }
        handleElementTap(page.elements[index - 1])
    }

    private func handleNextElement() {
        guard let page = currentPage, let active = activeElementId,
              let index = page.elements.firstIndex(where: { $0.id == active }),
              index < page.elements.count - 1 else { return }
        handleElementTap(page.elements[index + 1])
    }
}

/// Persistent cursor for sequential playback — the reference-type analogue of the
/// web `sequentialRef`, so the segment-complete callback reads a live index
/// without capturing the `ReaderView` struct.
@MainActor
final class SequentialCursor {
    var active = false
    var index = 0
    var elements: [Element] = []
}

#if DEBUG
#Preview("ReaderView") {
    ReaderView(entry: .global(index: 3))
        .environment(ContentStore())
        .environment(AudioController())
        .environment(AudioDownloadManager())
        .environment(ProgressStore())
        .environment(SettingsStore())
        .tint(.green)
}
#endif
