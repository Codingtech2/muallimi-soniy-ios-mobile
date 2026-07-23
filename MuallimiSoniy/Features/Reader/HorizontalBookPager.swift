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
    let onElementTap: (Element) -> Void
    /// Fired when the user settles on a new page (the binding has already moved
    /// `currentIndex`); the reader uses it to stop audio + clear the highlight.
    let onPageSettled: (Int) -> Void

    @Environment(\.layoutMetrics) private var layoutMetrics

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
            .scrollIndicators(.hidden)
            .onAppear {
                guard !didLandInitial else { return }
                didLandInitial = true
                landInitialPage(proxy)
            }
            .onChange(of: currentIndex) { oldValue, newValue in
                // A programmatic jump (deep-link resolve, TOC, page indicator)
                // moves `currentIndex` by more than one page without a user
                // scroll — force the content to follow. Adjacent (±1) changes are
                // user swipes, whose gesture already positioned the content, so we
                // leave those untouched to avoid fighting the swipe.
                if abs(newValue - oldValue) > 1 {
                    scrollToCurrent(proxy)
                }
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
    }

    // MARK: - Deterministic initial landing

    /// Lands the reader's start page on first appear. The reader resolves the
    /// start index around the same time this view appears, so we assert once now
    /// and re-assert across the push-transition / first-layout window — a single
    /// attempt can be dropped while the scroll container is still sizing. Every
    /// attempt targets `currentIndex` (protected against spurious resets by the
    /// binding's delta guard), so a re-assert can never yank the user off a page
    /// they scrolled to in the meantime.
    private func landInitialPage(_ proxy: ScrollViewProxy) {
        scrollToCurrent(proxy)
        Task { @MainActor in
            for delayMs in Self.reassertDelaysMs {
                try? await Task.sleep(for: .milliseconds(delayMs))
                scrollToCurrent(proxy)
            }
        }
    }

    /// Cumulative re-assert offsets (ms) spanning a slow navigation-push
    /// transition plus a loaded first layout; each `scrollTo` is idempotent.
    private static let reassertDelaysMs: [Int] = [90, 220, 420]

    /// Jumps the scroll view to `currentIndex` with no animation (matching the
    /// reader's instant jumps). Page 0 needs no assertion — it's the resting
    /// default and the `.scrollPosition` getter already holds it.
    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        guard pages.indices.contains(currentIndex), currentIndex != 0 else { return }
        let id = pages[currentIndex].id
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { proxy.scrollTo(id, anchor: .center) }
    }

    // MARK: - Scroll position ↔ index

    /// Two-way bridge between the paged scroll position (a `BookPage.id`) and the
    /// integer `currentIndex`. The getter keeps the scroll view pinned to the
    /// current index (so programmatic jumps work); the setter reports user swipes.
    private var scrollBinding: Binding<String?> {
        Binding<String?>(
            get: {
                guard pages.indices.contains(currentIndex) else { return pages.first?.id }
                return pages[currentIndex].id
            },
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

    /// Map of page id → index for O(1) resolution of the settled page.
    private var indexByID: [String: Int] {
        Dictionary(pages.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
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
