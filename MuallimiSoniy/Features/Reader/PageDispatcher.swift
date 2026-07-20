import SwiftUI

/// Routes a `BookPage` to its renderer by book page number. Bespoke per-page
/// renderers (M6–M9) are added here as `case`s; the `default` is the permanent
/// `GenericPageView` fallback, so every page always renders and stays tappable.
///
/// Kept as a single clean `switch` on purpose — new pages plug in as new cases
/// without touching the reader, the pager or the host card.
enum PageDispatcher {
    @ViewBuilder
    static func view(
        for page: BookPage,
        activeId: String?,
        onTap: @escaping (Element) -> Void
    ) -> some View {
        switch page.pageNumber {
        case 3: Page3View(page: page, activeId: activeId, onTap: onTap)
        case 4: Page4View(page: page, activeId: activeId, onTap: onTap)
        case 5: Page5View(page: page, activeId: activeId, onTap: onTap)
        case 6: Page6View(page: page, activeId: activeId, onTap: onTap)
        case 7: Page7View(page: page, activeId: activeId, onTap: onTap)
        case 8: Page8View(page: page, activeId: activeId, onTap: onTap)
        case 9: Page9View(page: page, activeId: activeId, onTap: onTap)
        case 10: Page10View(page: page, activeId: activeId, onTap: onTap)
        case 11: Page11View(page: page, activeId: activeId, onTap: onTap)
        case 12: Page12View(page: page, activeId: activeId, onTap: onTap)
        case 13: Page13View(page: page, activeId: activeId, onTap: onTap)
        case 14: Page14View(page: page, activeId: activeId, onTap: onTap)
        case 15: Page15View(page: page, activeId: activeId, onTap: onTap)
        case 16: Page16View(page: page, activeId: activeId, onTap: onTap)
        default:
            GenericPageView(page: page, activeId: activeId, onTap: onTap)
        }
    }
}
