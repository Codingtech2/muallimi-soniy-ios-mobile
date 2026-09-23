import SwiftUI

/// Horizontally-paged container over every `BookPage` — the native port of the
/// web `HorizontalPager` (Embla). Each page snaps full-width and scrolls its own
/// content vertically, so a short page never inherits a tall page's scroll extent
/// (the bug the web fixed by making each slide its own scroller).
///
/// Uses the iOS 17 scroll APIs: `.scrollTargetBehavior(.paging)` for page snap
/// and a `scrollPosition(id:)` binding mapped to the current index. A far initial
/// index (a deep-link into a late lesson) is set by the reader *after* first
/// layout, so it's also asserted through a `ScrollViewProxy` — `.scrollPosition`
/// alone can drop that jump while the container is still sizing (navigation-push
/// transition / main-thread load), leaving the pager stranded on page 1.
///
/// Two more corrections layer on top of those iOS 17 APIs. A `viewport` size
/// change (rotation, iPad window / Stage Manager resize) moves every cell's
/// width without moving the scroll offset, so the pager re-snaps to
/// `currentIndex` whenever `viewport` changes. And on iOS 18+, a settled page
/// change only commits (writes `currentIndex`, fires `onPageSettled`) once
/// scrolling goes fully idle (`.onScrollPhaseChange`), not the moment the
/// most-visible page changes mid-drag — otherwise a half swipe (past the
/// midpoint, then back) commits twice and wrongly stops audio / marks a
/// lesson complete. iOS 17 keeps the original immediate-commit behavior.
///
/// On iOS 18+ the settled page is read from the scroll view's real offset, not
/// from the `scrollPosition` binding: SwiftUI does not report every move
/// through that binding (a VoiceOver three-finger swipe, a keyboard scroll, or
/// the scroll view shifting itself while an assistive technology attaches), and
/// any such move left the card on one page while `currentIndex` — and the
/// audio, highlight and counter driven by it — stayed on another.
struct HorizontalBookPager: View {
    let pages: [BookPage]
    /// The **one** source of truth for cell geometry, measured by a single
    /// `GeometryReader` in `ReaderView` that already sits below the navigation
    /// bar and above the control bar. Previously the cell took its height from
    /// `.containerRelativeFrame` (which includes the safe area) and its top
    /// inset from `.safeAreaPadding(.top)` (which does not) — two independent
    /// answers to one question, so every device resolved a different gap and
    /// the first row of ḥarakāt got clipped on some of them.
    let viewport: CGSize
    @Binding var currentIndex: Int
    let activeElementId: String?
    /// While `true` (a memorize session is following the audio), the page that
    /// holds `activeElementId` scrolls it into view whenever it changes. Off by
    /// default, so a plain tap or normal page play never moves the page.
    var autoFollowActive: Bool = false
    let onElementTap: (Element) -> Void
    /// Fired when the user settles on a new page (the binding has already moved
    /// `currentIndex`); the reader uses it to stop audio + clear the highlight.
    let onPageSettled: (Int) -> Void

    @Environment(\.layoutMetrics) private var layoutMetrics
    /// Settings → Accessibility → Reduce Motion — the follow scroll jumps
    /// straight to the active element instead of gliding.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Turns `true` when an assistive technology (VoiceOver, Voice Control,
    /// Switch Control, an accessibility inspector…) first attaches to the app.
    @Environment(\.accessibilityEnabled) private var accessibilityEnabled

    /// Reading-column cap so the card doesn't stretch edge-to-edge on iPad
    /// (mirrors the web `max-w-xl` centred column). This is the binding
    /// constraint on the visible card (nests inside `ReaderView`'s own,
    /// wider outer cap). Widens via `layoutMetrics`; the iPhone number stays
    /// exactly 560.
    private var readingColumnWidth: CGFloat { layoutMetrics.pagerCardMaxWidth }

    /// Inset from the cell edge to the card. Cells abut and are exactly one
    /// viewport wide, so the space a reader sees between two cards mid-swipe is
    /// twice this number — half the gutter on each side of the seam. The
    /// `cardSideGap` floor keeps a sane minimum if the gutter is ever tuned
    /// down.
    private var cardInset: CGFloat {
        max(layoutMetrics.cardSideGap, layoutMetrics.interPageGutter / 2)
    }

    /// One-shot guard so the initial deep-link landing runs a single time.
    @State private var didLandInitial = false

    /// iOS 18+ only: backs `.scrollPosition(id:)` directly (see `scrollBinding`)
    /// so its getter never fights the finger mid-drag. Kept in lockstep with
    /// `currentIndex` on every programmatic change; while the user is actively
    /// scrolling it instead tracks whatever page the scroll view currently
    /// reports as most visible, which may run ahead of `currentIndex` until the
    /// gesture settles (see `settleRestingPage`). Unused below iOS 18, where
    /// `legacyScrollBinding` commits immediately instead.
    @State private var trackedPageID: String?
    /// iOS 18+ only: set while the user's finger drives the scroll, consumed by
    /// the next settle — a finger swipe always commits the page it ends on.
    @State private var userScrollPending = false
    /// iOS 18+ only: the page the horizontal scroll view is resting on, read
    /// from its content offset. `nil` until the first geometry report.
    @State private var restingPage: Int?
    /// iOS 18+ only: `false` while any scroll (finger, deceleration, animation)
    /// is in flight, so a page passed on the way is never mistaken for a settle.
    @State private var scrollIsIdle = true
    /// iOS 18+ only: `true` for a short window while the pager itself moves to
    /// or re-asserts `currentIndex`. A displacement inside the window is put
    /// back instead of being committed as a page change.
    @State private var isHoldingPosition = false
    /// Identifies the latest hold window, so an older window ending can't
    /// release a newer one.
    @State private var holdGeneration = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(pages) { page in
                        pageCell(page)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: scrollBinding)
            .modifier(IdleCommitScrollPhase(
                onUserScroll: { userScrollPending = true },
                onScrollActivity: { scrollIsIdle = !$0 },
                onIdle: { settleRestingPage(proxy) },
                onRestingPointChange: { old, new in restingPointDidChange(from: old, to: new, proxy: proxy) }
            ))
            .scrollIndicators(.hidden)
            .onAppear {
                guard !didLandInitial else { return }
                didLandInitial = true
                reassertCurrentPage(proxy)
            }
            .onChange(of: currentIndex) { oldValue, newValue in
                // Keep the iOS 18+ tracking id in lockstep with every change to
                // `currentIndex`, whichever side caused it — a no-op when it was
                // `settleRestingPage` itself (already equal to it), and
                // required when it was a TOC jump / chevron tap / deep-link
                // resolve, so `scrollBinding`'s getter reflects the new page
                // instead of wherever the finger last left the scroll view.
                trackedPageID = currentPageID
                // The reader moved the page (chevron, TOC, memorize follow):
                // the scroll view still has to get there, so don't read the
                // page it is leaving as a new settle.
                if restingPage != newValue {
                    holdPosition()
                }
                // A programmatic jump (deep-link resolve, TOC, page indicator)
                // moves `currentIndex` by more than one page without a user
                // scroll — force the content to follow. Adjacent (±1) changes are
                // user swipes, whose gesture already positioned the content, so we
                // leave those untouched to avoid fighting the swipe.
                if abs(newValue - oldValue) > 1 {
                    scrollToCurrent(proxy)
                }
            }
            .onChange(of: viewport) { _, _ in
                // Rotation or an iPad window / Stage Manager resize changes every
                // cell's width out from under the scroll view, which keeps its old
                // *point* offset rather than its page index — the visible page
                // silently drifts onto a neighbour while `currentIndex` (and
                // everything driven by it: audio, transport, ⏮/⏭, progress) stays
                // put. Re-snap to the page we're already logically on, including
                // index 0, whose resting position just moved too.
                holdPosition()
                trackedPageID = currentPageID
                scrollToCurrent(proxy, includingFirst: true)
            }
            .onChange(of: accessibilityEnabled) { _, _ in
                // The scroll view can shift itself by a page while an
                // assistive technology first attaches, without any scroll
                // gesture. Hold the page the reader is on through that window.
                guard #available(iOS 18.0, *) else { return }
                trackedPageID = currentPageID
                reassertCurrentPage(proxy, includingFirst: true)
            }
        }
    }

    // MARK: - Page cell

    /// One full-viewport page: a vertical `ScrollView` of the hosted card, sized
    /// straight from `viewport`. Paging still snaps because the cell width is
    /// exactly the scroll view's visible width. The gap above and below the card
    /// is the scroll view's own content margin, so it is one number per size
    /// class rather than a per-device safe-area accident.
    private func pageCell(_ page: BookPage) -> some View {
        ScrollViewReader { verticalProxy in
            ScrollView(.vertical) {
                PageHostView(
                    page: page,
                    activeId: activeElementId,
                    onTap: onElementTap,
                    viewportHeight: viewport.height
                )
                .frame(maxWidth: readingColumnWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, cardInset)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.top, layoutMetrics.cardTopGap, for: .scrollContent)
            .contentMargins(.bottom, layoutMetrics.cardBottomGap, for: .scrollContent)
            .modifier(HardTopScrollEdge())
            .frame(width: viewport.width, height: viewport.height)
            .onChange(of: followedElementID(on: page)) { _, elementID in
                scrollIntoView(elementID, with: verticalProxy, animated: true)
            }
            .onAppear {
                // A memorize session can move to a page whose cell doesn't
                // exist yet; the new cell starts on the active element.
                scrollIntoView(followedElementID(on: page), with: verticalProxy, animated: false)
            }
        }
    }

    // MARK: - Follow the active element

    /// The element this page keeps in view: the active one, only while the
    /// reader asks to follow it and only on the page that holds it.
    private func followedElementID(on page: BookPage) -> String? {
        guard autoFollowActive, let activeElementId,
              page.elements.contains(where: { $0.id == activeElementId }) else { return nil }
        return activeElementId
    }

    /// Centres `elementID` in this page's vertical scroll view — the elements
    /// carry their id (`ArabicElementView`, `Verse`), so the proxy can find them.
    private func scrollIntoView(_ elementID: String?, with proxy: ScrollViewProxy, animated: Bool) {
        guard let elementID else { return }
        if animated, !reduceMotion {
            withAnimation(.easeInOut(duration: Self.followScrollDuration)) {
                proxy.scrollTo(elementID, anchor: .center)
            }
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { proxy.scrollTo(elementID, anchor: .center) }
        }
    }

    /// Glide time for the follow scroll, in seconds.
    private static let followScrollDuration: Double = 0.35

    // MARK: - Deterministic initial landing

    /// Asserts `currentIndex` now and again across a short window. Used for the
    /// initial landing — the reader resolves the start index around the same
    /// time this view appears, and a single attempt can be dropped while the
    /// scroll container is still sizing (push transition / first layout) — and
    /// when an assistive technology attaches. Every attempt targets
    /// `currentIndex` (protected against spurious resets by the binding's delta
    /// guard), so a re-assert can never yank the user off a page they scrolled
    /// to in the meantime.
    private func reassertCurrentPage(_ proxy: ScrollViewProxy, includingFirst: Bool = false) {
        holdPosition()
        scrollToCurrent(proxy, includingFirst: includingFirst)
        Task { @MainActor in
            for delayMs in Self.reassertDelaysMs {
                try? await Task.sleep(for: .milliseconds(delayMs))
                scrollToCurrent(proxy, includingFirst: includingFirst)
            }
        }
    }

    /// Cumulative re-assert offsets (ms) spanning a slow navigation-push
    /// transition plus a loaded first layout; each `scrollTo` is idempotent.
    private static let reassertDelaysMs: [Int] = [90, 220, 420]

    /// How long a hold window lasts (ms) — longer than the whole re-assert
    /// schedule above, and than any move the pager makes on its own.
    private static let holdDurationMs = 1_000

    /// Jumps the scroll view to `currentIndex` with no animation (matching the
    /// reader's instant jumps). Page 0 needs no assertion by default — it's the
    /// resting default and the `.scrollPosition` getter already holds it — unless
    /// `includingFirst` says the container itself just changed shape (see the
    /// `viewport` `onChange` above), in which case index 0's resting position
    /// moved too and needs the same re-assert as every other index.
    private func scrollToCurrent(_ proxy: ScrollViewProxy, includingFirst: Bool = false) {
        guard pages.indices.contains(currentIndex), includingFirst || currentIndex != 0 else { return }
        let id = pages[currentIndex].id
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { proxy.scrollTo(id, anchor: .center) }
    }

    /// iOS 18+ only: opens (or extends) a hold window — see `isHoldingPosition`.
    private func holdPosition() {
        guard #available(iOS 18.0, *) else { return }
        holdGeneration &+= 1
        let generation = holdGeneration
        isHoldingPosition = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Self.holdDurationMs))
            if holdGeneration == generation {
                isHoldingPosition = false
            }
        }
    }

    // MARK: - Scroll position ↔ index

    /// The binding actually attached to `.scrollPosition(id:)` in `body`. Below
    /// iOS 18 this *is* `legacyScrollBinding`, unchanged. From iOS 18 the scroll
    /// view instead reads/writes `trackedPageID` — a plain tracking value with no
    /// side effects — so the getter never fights the finger mid-drag and the
    /// setter never commits a page the finger hasn't actually settled on;
    /// `settleRestingPage()` does that, once `IdleCommitScrollPhase` reports
    /// the scroll view has gone fully idle. That's what stops a half swipe
    /// (past the midpoint, then back) from firing `onPageSettled` twice.
    private var scrollBinding: Binding<String?> {
        guard #available(iOS 18.0, *) else { return legacyScrollBinding }
        return Binding<String?>(
            get: { trackedPageID ?? currentPageID },
            set: { trackedPageID = $0 }
        )
    }

    /// The original iOS 17 two-way bridge between the paged scroll position (a
    /// `BookPage.id`) and the integer `currentIndex`, unchanged by the iOS 18+
    /// idle-commit fix above: the getter keeps the scroll view pinned to the
    /// current index (so programmatic jumps work); the setter commits a user
    /// swipe — and fires `onPageSettled` — the instant the most-visible page
    /// changes, even while the finger is still down.
    private var legacyScrollBinding: Binding<String?> {
        Binding<String?>(
            get: { currentPageID },
            set: { newValue in
                guard let newValue,
                      let index = indexByID[newValue],
                      index != currentIndex else { return }
                // With `.scrollTargetBehavior(.paging)` a user gesture only ever
                // settles on an adjacent page. A larger delta is a transient the
                // scroll view reports *while a programmatic jump is still applying*
                // (or a push is animating) — typically a momentary page-0 report.
                // Accepting it would snap `currentIndex` back to page 1, which is
                // exactly the deep-link bug. Ignore it; genuine far jumps move
                // `currentIndex` directly through the getter above, not here.
                guard abs(index - currentIndex) <= 1 else { return }
                currentIndex = index
                onPageSettled(index)
            }
        )
    }

    /// iOS 18+ only: reconciles the page the scroll view rests on with
    /// `currentIndex` once scrolling is idle. This is the *only* place a user
    /// swipe reaches `currentIndex` on iOS 18+, and it commits at most once per
    /// settle: a half swipe comes back to `currentIndex` and commits nothing, a
    /// fast double flick commits the page it lands on. A move the pager didn't
    /// make — a finger, or a VoiceOver / Voice Control / keyboard scroll —
    /// commits (writes `currentIndex`, fires `onPageSettled`); a displacement
    /// inside a hold window is put back instead, so the pager's own moves never
    /// report a settle.
    private func settleRestingPage(_ proxy: ScrollViewProxy) {
        let userScrolled = userScrollPending
        userScrollPending = false
        // Before the first landing the scroll view still rests on page 0 while
        // `currentIndex` may already hold a deep-linked page.
        guard didLandInitial,
              let resting = restingPage ?? trackedPageID.flatMap({ indexByID[$0] }),
              pages.indices.contains(resting) else { return }
        guard resting != currentIndex else {
            // Nothing moved, but make sure the scroll-position binding names the
            // page on screen, so SwiftUI never restores a stale one later.
            if trackedPageID != currentPageID {
                trackedPageID = currentPageID
            }
            return
        }
        if isHoldingPosition, !userScrolled {
            trackedPageID = currentPageID
            scrollToCurrent(proxy, includingFirst: true)
            return
        }
        currentIndex = resting
        onPageSettled(resting)
    }

    /// iOS 18+ only: records the page the content offset now rests on. A move
    /// while scrolling is idle had no gesture behind it, so it is settled here
    /// right away; a move during a scroll waits for `settleRestingPage` at idle.
    private func restingPointDidChange(from old: PagerRestingPoint, to new: PagerRestingPoint, proxy: ScrollViewProxy) {
        restingPage = min(max(new.page, 0), max(pages.count - 1, 0))
        // A width change is a layout change (rotation, iPad resize), not a
        // scroll; the `viewport` handler re-snaps it.
        guard old.width == new.width, scrollIsIdle else { return }
        settleRestingPage(proxy)
    }

    /// The `BookPage.id` at `currentIndex`, or the first page's id if the index is
    /// momentarily out of range (defensive; `pages` is never empty by the time
    /// this view exists — `ReaderView` gates on `pages.isEmpty` before building it).
    private var currentPageID: String? {
        guard pages.indices.contains(currentIndex) else { return pages.first?.id }
        return pages[currentIndex].id
    }

    /// Map of page id → index for O(1) resolution of the settled page.
    private var indexByID: [String: Int] {
        Dictionary(pages.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}

/// Where the horizontal pager's content offset rests: the nearest page index,
/// plus the page width it was measured against (a change there is layout, not
/// scrolling).
private struct PagerRestingPoint: Equatable {
    let page: Int
    let width: CGFloat
}

/// Turns off the iOS 26 Liquid Glass progressive blur at the scroll view's top
/// edge. Diacritics are pronunciation, so a softly blurred first row is a
/// correctness bug, not a stylistic one — `.hard` keeps the cut crisp. No-op
/// below iOS 26, where the effect doesn't exist.
private struct HardTopScrollEdge: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(.hard, for: .top)
        } else {
            content
        }
    }
}

/// Reports the horizontal pager's scroll phases and resting page on iOS 18+:
/// `onIdle` fires once the scroll view goes fully idle — finger up *and* any
/// deceleration/snap animation finished, not the moment a drag crosses the
/// halfway point — and `onRestingPointChange` whenever the content offset
/// moves to a different page. Pairs with `settleRestingPage`, so a half swipe
/// that peeks past the midpoint and returns never commits the neighbour page.
/// No-op below iOS 18, where `.onScrollPhaseChange` doesn't exist —
/// `legacyScrollBinding` commits immediately there instead, exactly as before.
private struct IdleCommitScrollPhase: ViewModifier {
    /// The user's finger is driving the scroll (dragging, or the fling it left).
    let onUserScroll: () -> Void
    /// `true` while any scroll is in flight, `false` once it is idle again.
    let onScrollActivity: (Bool) -> Void
    let onIdle: () -> Void
    let onRestingPointChange: (_ old: PagerRestingPoint, _ new: PagerRestingPoint) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .onScrollPhaseChange { _, newPhase in
                    onScrollActivity(newPhase != .idle)
                    switch newPhase {
                    case .interacting, .decelerating: onUserScroll()
                    case .idle: onIdle()
                    default: break
                    }
                }
                .onScrollGeometryChange(for: PagerRestingPoint.self) { geometry in
                    let width = geometry.containerSize.width
                    let page = width > 0 ? Int((geometry.contentOffset.x / width).rounded()) : 0
                    return PagerRestingPoint(page: page, width: width)
                } action: { old, new in
                    onRestingPointChange(old, new)
                }
        } else {
            content
        }
    }
}
