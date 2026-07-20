import SwiftUI

/// Horizontally-paged container over every `BookPage` — the native port of the
/// web `HorizontalPager` (Embla). Each page snaps full-width and scrolls its own
/// content vertically, so a short page never inherits a tall page's scroll extent
/// (the bug the web fixed by making each slide its own scroller).
///
/// Uses the iOS 17 scroll APIs: `.scrollTargetBehavior(.paging)` for page snap
/// and a `scrollPosition(id:)` binding mapped to the current index. If nested
/// scrolling ever proves unreliable, this is the single view to swap for a
/// `TabView(.page, indexDisplayMode: .never)`.
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

    var body: some View {
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
