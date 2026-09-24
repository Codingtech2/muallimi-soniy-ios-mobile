import SwiftUI

/// The ids of the elements a hifz self-test is hiding right now, or `nil` (the
/// default) while nothing is hidden. Only `ReaderView` ever sets it, and only
/// while a session started with "hide text" is running — every other screen,
/// and the reader the rest of the time, renders exactly as before.
private struct HifzHiddenElementIdsKey: EnvironmentKey {
    static let defaultValue: Set<String>? = nil
}

extension EnvironmentValues {
    var hifzHiddenElementIds: Set<String>? {
        get { self[HifzHiddenElementIdsKey.self] }
        set { self[HifzHiddenElementIdsKey.self] = newValue }
    }
}

extension View {
    /// Blurs an element's glyphs while it is hidden for a hifz self-test.
    /// Attach once, to the element's text — not its highlight pill, so the
    /// ayah being recited still shows where it is. Passes the view through
    /// untouched whenever the element isn't hidden.
    func hifzHiddenText(_ element: Element) -> some View {
        modifier(HifzHiddenTextModifier(elementId: element.id))
    }

    /// `.contextMenu`, except that a hidden element's preview is its text,
    /// unblurred and a size larger: pressing and holding a hidden ayah is how
    /// the learner peeks at it. Anything not hidden gets the plain `.contextMenu`.
    func hifzPeekableContextMenu<MenuItems: View>(
        for element: Element,
        @ViewBuilder menuItems: () -> MenuItems
    ) -> some View {
        modifier(HifzPeekableContextMenu(element: element, menuItems: menuItems()))
    }
}

private struct HifzHiddenTextModifier: ViewModifier {
    let elementId: String

    @Environment(\.hifzHiddenElementIds) private var hiddenIds
    /// Bigger text needs a stronger blur to stay unreadable.
    @Environment(\.arabicFontScale) private var arabicFontScale

    /// Enough to make the glyphs unreadable at the reading sizes, while the
    /// word and line shapes still show where each ayah sits.
    private static let blurRadius: CGFloat = 7

    @ViewBuilder
    func body(content: Content) -> some View {
        if hiddenIds?.contains(elementId) == true {
            content.blur(radius: Self.blurRadius * arabicFontScale)
        } else {
            content
        }
    }
}

private struct HifzPeekableContextMenu<MenuItems: View>: ViewModifier {
    let element: Element
    let menuItems: MenuItems

    @Environment(\.hifzHiddenElementIds) private var hiddenIds
    // Read here and handed to the preview, which is drawn away from the page.
    @Environment(\.readingTheme) private var readingTheme
    @Environment(\.arabicFontScale) private var arabicFontScale
    @Environment(\.readingAdjustments) private var adjustments
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.layoutMetrics) private var layoutMetrics

    /// The element's width on the page, so a long ayah gets a wide preview.
    @State private var width: CGFloat = 0

    @ViewBuilder
    func body(content: Content) -> some View {
        if hiddenIds?.contains(element.id) == true {
            content
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
                .contextMenu {
                    menuItems
                } preview: {
                    peek
                }
        } else {
            content.contextMenu { menuItems }
        }
    }

    /// The hidden glyphs, readable, on the reading background. Built from the
    /// element itself: a modifier's `content` doesn't draw inside a preview.
    private var peek: some View {
        let maxWidth = layoutMetrics.isRegular ? PeekLayout.regularMaxWidth : PeekLayout.compactMaxWidth
        let bold = adjustments.boldText || legibilityWeight == .bold
        return Text(element.arabic)
            .font(arabicFont(PeekLayout.pointSize * arabicFontScale, weight: arabicWeight(bold: bold)))
            .foregroundStyle(readingTheme.textMain)
            .multilineTextAlignment(.center)
            .frame(width: min(max(width, PeekLayout.minWidth), maxWidth))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, PeekLayout.horizontalPadding)
            .padding(.vertical, PeekLayout.verticalPadding)
            .background(readingTheme.pageFill)
            .environment(\.layoutDirection, .rightToLeft)
    }
}

/// Peek preview sizing (a generic modifier can't hold static lets).
private enum PeekLayout {
    /// A size up from the page's ayah text, so a quick peek reads easily.
    static let pointSize: CGFloat = 24
    static let minWidth: CGFloat = 200
    static let compactMaxWidth: CGFloat = 340
    static let regularMaxWidth: CGFloat = 520
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 12
}
