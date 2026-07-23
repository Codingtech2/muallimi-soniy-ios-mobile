import SwiftUI

/// Wraps a single page's rendered content in the reader's light card surface —
/// the native analogue of the web page card (rounded, hairline border). The fill
/// is kept **near-opaque on purpose** (`readingTheme.cardFill`) so the Arabic
/// text stays high-contrast — the reading content must never sit behind heavy
/// translucent glass, even as the surrounding chrome bars go frosted. The
/// dispatcher decides *what* renders; this view owns the chrome.
///
/// **Layout stability contract.** Every number this view uses is either a
/// constant or an input handed down from above (`viewportHeight`, measured
/// once by `ReaderView` *outside* the scroll view). Nothing measured inside
/// the card is fed back into the card's own layout, and this view holds no
/// `@State` at all. Its height is therefore a pure function of
/// `(page, card width, size class, viewportHeight)` — identical on every layout
/// pass — so a scroll view containing it has a content height that cannot
/// change mid-bounce.
struct PageHostView: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void
    /// Height of the pager viewport this card sits in, measured by the reader
    /// above the scroll view. On iPad it floors the card's height so the card
    /// spans the whole reading area the way a page in a physical book does.
    /// `0` (the default, used by the DEBUG single-page host) disables the
    /// floor and the card hugs its content.
    var viewportHeight: CGFloat = 0

    /// The reader's live page/text palette — defaults to `.paper` (today's
    /// exact look) outside the reader; `ReaderView` injects the live value.
    @Environment(\.readingTheme) private var readingTheme
    /// iPad vs iPhone padding scale.
    @Environment(\.layoutMetrics) private var layoutMetrics

    /// `rounded-[28px]` card radius (matches the app's card language).
    private let cornerRadius: CGFloat = 28

    /// Inner margin of the card. A constant per size class, deliberately:
    /// deriving it from the rendered content's measured height created a
    /// measure → pad → re-measure path, and a scroll bounce perturbs geometry
    /// on every frame, which turned that path into visible jitter at the
    /// card's top edge. The iPhone number is exactly today's shipped 16.
    private var cardPadding: CGFloat { layoutMetrics.isRegular ? 32 : 16 }

    /// iPad only: the card fills the whole reading area (the viewport minus
    /// the gaps above and below it), so a short lesson reads as a book page
    /// with whitespace at the bottom rather than as a small floating box on a
    /// big screen. `nil` on iPhone — the phone card hugs its content exactly
    /// as it always has.
    private var minCardHeight: CGFloat? {
        guard layoutMetrics.isRegular, viewportHeight > 0 else { return nil }
        return viewportHeight - layoutMetrics.cardTopGap - layoutMetrics.cardBottomGap
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        PageDispatcher.view(for: page, activeId: activeId, onTap: onTap)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(cardPadding)
            // Applied before `.background`, so the fill / border / shadow grow
            // with the floor. Content stays top-aligned: this is a pager, and a
            // first line that moves between swipes forces the reader to
            // re-acquire their eye position on every page turn.
            .frame(minHeight: minCardHeight, alignment: .top)
            .background(readingTheme.cardFill, in: shape)
            .overlay(shape.strokeBorder(readingTheme.divider, lineWidth: 1))
            // Soft lift so the readable page card floats above the page fill.
            // Skipped on the night background, where a black shadow over a
            // near-black page is invisible yet still costs one offscreen
            // rasterization per pager cell.
            .modifier(CardShadow(enabled: readingTheme != .night))
    }
}

/// Applies the card lift only when it can actually be seen. Written as a
/// modifier so the two branches erase to one `some View` and the `.shadow`
/// modifier is genuinely absent (not just transparent) on the night theme.
private struct CardShadow: ViewModifier {
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content.shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
        } else {
            content
        }
    }
}
