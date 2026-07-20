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
        default:
            GenericPageView(page: page, activeId: activeId, onTap: onTap)
        }
    }
}
