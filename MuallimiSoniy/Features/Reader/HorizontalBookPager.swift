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
    @Binding var currentIndex: Int
    let activeElementId: String?
    let onElementTap: (Element) -> Void
    /// Fired when the user settles on a new page (the binding has already moved
    /// `currentIndex`); the reader uses it to stop audio + clear the highlight.
    let onPageSettled: (Int) -> Void

    /// Reading-column cap so the card doesn't stretch edge-to-edge on iPad
    /// (mirrors the web `max-w-xl` centred column).
    private let readingColumnWidth: CGFloat = 560

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
    /// to the pager viewport so its content (not the pager) owns vertical scroll.
    @ViewBuilder
    private func pageCell(_ page: BookPage) -> some View {
        ScrollView(.vertical) {
            PageHostView(page: page, activeId: activeElementId, onTap: onElementTap)
                .frame(maxWidth: readingColumnWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .containerRelativeFrame([.horizontal, .vertical])
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
