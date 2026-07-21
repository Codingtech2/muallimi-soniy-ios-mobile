import SwiftUI
import Foundation

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
    @Environment(ProgressStore.self) private var progress
    @Environment(SettingsStore.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutMetrics) private var layoutMetrics

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
    /// Loop toggle state, kept in sync with the audio engine.
    @State private var loopMode = false

    /// UI / content locale for titles + labels — follows the user's setting, so
    /// switching language live-updates the header, TOC and page labels.
    private var locale: AppLocale { preferences.settings.locale }
    /// Reading-column cap for the pager + chrome, centred on wide screens
    /// (mirrors the web `max-w-xl` column). Widens on iPad via `layoutMetrics`;
    /// the iPhone (compact) number stays exactly 640.
    private var readingColumnWidth: CGFloat { layoutMetrics.readingColumnWidth }

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
        .background(AppColor.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $tocOpen) {
            TocSheet(
                outline: store.outline,
                currentLessonId: currentPage?.lessonId ?? "",
                currentGlobalPage: currentPageIndex + 1,
                totalPages: pages.count,
                contentsLabel: store.t("contents", locale),
                pageLabel: store.t("page", locale),
                closeLabel: store.t("close", locale),
                locale: locale,
                onSelectGlobalPage: { goToPage($0 - 1) }
            )
            .presentationDetents([.large])
        }
        .onAppear {
            resolveStartIfNeeded()
            configureAudioDefaults()
            wireRemoteCommands()
            recordProgress()
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
        .onDisappear {
            cancelSequential()
            audio.onRemoteNext = nil
            audio.onRemotePrev = nil
            audio.stop()
            AudioSession.shared.deactivate()
        }
    }

    /// Header on top, pager filling the middle (centred reading column), and the
    /// page indicator + audio bar pinned at the bottom of that column.
    private var readerContent: some View {
        VStack(spacing: 0) {
            ReaderHeader(
                lessonTitle: currentPage?.lesson.title.text(locale) ?? "",
                chapterTitle: currentPage?.chapter.title.text(locale) ?? "",
                tocLabel: store.t("lessons", locale),
                onBack: { dismiss() },
                onOpenToc: { tocOpen = true }
            )

            VStack(spacing: 0) {
                HorizontalBookPager(
                    pages: pages,
                    currentIndex: $currentPageIndex,
                    activeElementId: activeElementId,
                    onElementTap: handleElementTap,
                    onPageSettled: { _ in pageDidChange() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if pages.count > 1 {
                    ReaderPageIndicator(
                        total: pages.count,
                        current: currentPageIndex,
                        prevLabel: store.t("prev_page", locale),
                        nextLabel: store.t("next_page", locale),
                        onSelect: goToPage
                    )
                }

                if hasAudio {
                    AudioControls(
                        loopOn: loopMode,
                        loopLabel: store.t("loop", locale),
                        playLabel: store.t("play", locale),
                        pauseLabel: store.t("pause", locale),
                        prevLabel: store.t("prev_element", locale),
                        nextLabel: store.t("next_element", locale),
                        onPlayPause: handlePlayPause,
                        onPrev: handlePrevElement,
                        onNext: handleNextElement,
                        onToggleLoop: toggleLoop
                    )
                }
            }
            .frame(maxWidth: readingColumnWidth)
            .frame(maxWidth: .infinity)
        }
    }

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
    /// pack may not be downloaded yet) the tap still lands (web parity).
    private func handleElementTap(_ element: Element) {
        cancelSequential()
        activeElementId = element.id
        guard element.start != element.end else { return }
        guard let url = audioURL(for: element) else { return }
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
    /// otherwise start sequential playback of the page.
    private func handlePlayPause() {
        if audio.isPlaying { audio.pause(); return }
        if sequential.active, activeElementId != nil { audio.resume(); return }
        if let page = currentPage, let id = activeElementId,
           let element = page.elements.first(where: { $0.id == id }),
           element.start < element.end {
            let url = MediaLocator.url(for: element) ?? MediaLocator.url(for: page.lesson)
            if let url {
                audio.setNowPlaying(
                    title: element.arabic,
                    artist: element.uzbek,
                    album: page.lesson.title.text(locale)
                )
                Task { await audio.playSegment(url: url, start: element.start, end: element.end) }
            }
            return
        }
        startSequentialPlay()
    }

    /// Toggles loop mode and pushes it to the audio engine.
    private func toggleLoop() {
        loopMode.toggle()
        audio.setLoopMode(loopMode)
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
        .environment(ProgressStore())
        .environment(SettingsStore())
        .tint(.green)
}
#endif
