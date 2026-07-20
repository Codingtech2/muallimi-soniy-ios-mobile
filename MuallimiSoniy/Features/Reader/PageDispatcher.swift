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
        case 0: Page0View(page: page, activeId: activeId, onTap: onTap)
        case 1: Page1View(page: page, activeId: activeId, onTap: onTap)
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
        case 17: Page17View(page: page, activeId: activeId, onTap: onTap)
        case 18: Page18View(page: page, activeId: activeId, onTap: onTap)
        case 19: Page19View(page: page, activeId: activeId, onTap: onTap)
        case 20: Page20View(page: page, activeId: activeId, onTap: onTap)
        case 21: Page21View(page: page, activeId: activeId, onTap: onTap)
        case 22: Page22View(page: page, activeId: activeId, onTap: onTap)
        case 23: Page23View(page: page, activeId: activeId, onTap: onTap)
        case 24: Page24View(page: page, activeId: activeId, onTap: onTap)
        case 25: Page25View(page: page, activeId: activeId, onTap: onTap)
        case 26: Page26View(page: page, activeId: activeId, onTap: onTap)
        case 27: Page27View(page: page, activeId: activeId, onTap: onTap)
        case 28: Page28View(page: page, activeId: activeId, onTap: onTap)
        case 29: Page29View(page: page, activeId: activeId, onTap: onTap)
        case 30: Page30View(page: page, activeId: activeId, onTap: onTap)
        case 31: Page31View(page: page, activeId: activeId, onTap: onTap)
        case 32: Page32View(page: page, activeId: activeId, onTap: onTap)
        case 33: Page33View(page: page, activeId: activeId, onTap: onTap)
        case 34: Page34View(page: page, activeId: activeId, onTap: onTap)
        case 35: Page35View(page: page, activeId: activeId, onTap: onTap)
        case 36: Page36View(page: page, activeId: activeId, onTap: onTap)
        case 37: Page37View(page: page, activeId: activeId, onTap: onTap)
        case 38: Page38View(page: page, activeId: activeId, onTap: onTap)
        case 39: Page39View(page: page, activeId: activeId, onTap: onTap)
        case 40: Page40View(page: page, activeId: activeId, onTap: onTap)
        case 41: Page41View(page: page, activeId: activeId, onTap: onTap)
        case 42: Page42View(page: page, activeId: activeId, onTap: onTap)
        case 43: Page43View(page: page, activeId: activeId, onTap: onTap)
        case 44: Page44View(page: page, activeId: activeId, onTap: onTap)
        case 45: Page45View(page: page, activeId: activeId, onTap: onTap)
        case 46: Page46View(page: page, activeId: activeId, onTap: onTap)
        case 47: Page47View(page: page, activeId: activeId, onTap: onTap)
        case 48: Page48View(page: page, activeId: activeId, onTap: onTap)
        case 49: Page49View(page: page, activeId: activeId, onTap: onTap)
        case 50: Page50View(page: page, activeId: activeId, onTap: onTap)
        default:
            GenericPageView(page: page, activeId: activeId, onTap: onTap)
        }
    }
}
