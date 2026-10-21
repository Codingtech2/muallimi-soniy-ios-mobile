import SwiftUI

// The Mushaf paragraph is one canvas, so everything a tappable `Verse` used to
// carry per ayah is rebuilt here as invisible views the layout lays over it:
// a tap/long-press area and a VoiceOver + scroll anchor per ayah. Both get the
// full column width over the ayah's lines (its "band"), and shape themselves
// to the ayah's own line fragments with `MushafItemShape`.

/// The line fragments of one ayah, inside a view the layout put over the
/// ayah's band. The shape rebuilds the geometry from the band's width (the
/// column width), so it always matches the canvas — no measured state.
nonisolated struct MushafItemShape: Shape {
    nonisolated enum Kind: Sendable, Hashable {
        /// Fragments widened to meet the neighbouring ayat and as tall as the
        /// lines (`Fragment.hit`): a wrapped ayah answers taps on each of its
        /// lines, and the ayat sharing those lines never steal its taps.
        case hit
        /// The highlight pills (`Fragment.pill`) — the VoiceOver outline.
        case glyphs
    }

    let measurements: MushafMeasurements
    let style: MushafGeometryStyle
    let item: Int
    let kind: Kind

    /// The rects are computed left-to-right already; never mirror them.
    var layoutDirectionBehavior: LayoutDirectionBehavior { .fixed }

    func path(in rect: CGRect) -> Path {
        let geometry = MushafTextGeometry(measurements: measurements, style: style, width: rect.width)
        // The view starts at the top of the ayah's first line.
        let top = geometry.band(of: item).minY
        var path = Path()
        for fragment in geometry.fragments(of: item) {
            let fragmentRect = kind == .hit ? fragment.hit : fragment.pill
            path.addRect(fragmentRect.offsetBy(dx: rect.minX, dy: rect.minY - top))
        }
        return path
    }

    /// Middle of the ayah's first line fragment, in the same space as
    /// `path(in:)`. VoiceOver's double-tap-and-hold (and Voice Control's "long
    /// press") touches the element there; the band's own middle can sit on a
    /// neighbouring ayah when this one wraps, and open that ayah's menu.
    func activationPoint(in rect: CGRect) -> CGPoint {
        let geometry = MushafTextGeometry(measurements: measurements, style: style, width: rect.width)
        guard let first = geometry.fragments(of: item).first else {
            return CGPoint(x: rect.midX, y: rect.midY)
        }
        let pill = first.pill.offsetBy(dx: rect.minX, dy: rect.minY - geometry.band(of: item).minY)
        return CGPoint(x: pill.midX, y: pill.midY)
    }
}

/// Tap and long-press target of one ayah. A tap plays it (`onTap`); a long
/// press opens the reader's hifz menu, when it has actions for this ayah,
/// with the ayah's own text as the preview — never a snapshot of this clear
/// view. Hidden from VoiceOver: `MushafAyahAnchor` is the ayah's element there.
struct MushafAyahHitArea: View {
    let item: MushafFlowItem
    /// `MushafItemShape` of kind `.hit`.
    let shape: MushafItemShape
    let onTap: (Element) -> Void

    @Environment(\.ayahMenuProvider) private var menuProvider
    // Read here and handed to the preview, which is drawn away from the page.
    @Environment(\.readingTheme) private var readingTheme
    @Environment(\.verseFontScale) private var verseFontScale
    @Environment(\.arabicTypeface) private var arabicTypeface
    @Environment(\.readingAdjustments) private var adjustments
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.layoutMetrics) private var layoutMetrics

    var body: some View {
        let actions = menuProvider?(item.element) ?? []
        let target = Color.clear
            .contentShape(shape)
            // iPad pointer: the ayah lights up under it, as a `Button` would.
            .contentShape(.hoverEffect, shape)
            .hoverEffect(.highlight)
            .onTapGesture { onTap(item.element) }
        Group {
            if actions.isEmpty {
                target
            } else {
                target.contextMenu {
                    // Menu titles are Latin/Cyrillic UI text, never the Arabic.
                    ForEach(actions) { action in
                        Button(action: action.action) {
                            Label(action.title, systemImage: action.systemImage)
                        }
                    }
                    .environment(\.layoutDirection, .leftToRight)
                } preview: {
                    preview
                }
            }
        }
        .accessibilityHidden(true)
    }

    private var preview: MushafAyahPreview {
        MushafAyahPreview(
            item: item,
            readingTheme: readingTheme,
            pointSize: MushafAyahPreview.pointSize * verseFontScale,
            typeface: arabicTypeface,
            bold: adjustments.boldText || legibilityWeight == .bold,
            width: layoutMetrics.isRegular ? MushafAyahPreview.regularWidth : MushafAyahPreview.compactWidth
        )
    }
}

/// The long-press preview: the ayah in the Mushaf fonts, readable even while
/// a hifz session hides it on the page (that's how the learner peeks), on the
/// reading background — like `hifzPeekableContextMenu`'s peek.
struct MushafAyahPreview: View {
    /// A size up from the page text, so a quick peek reads easily.
    static let pointSize: CGFloat = 24
    static let compactWidth: CGFloat = 340
    static let regularWidth: CGFloat = 520
    private static let horizontalPadding: CGFloat = 16
    private static let verticalPadding: CGFloat = 12

    let item: MushafFlowItem
    let readingTheme: ReadingBackground
    let pointSize: CGFloat
    let typeface: ArabicTypeface
    let bold: Bool
    let width: CGFloat

    var body: some View {
        Text(text)
            .multilineTextAlignment(.center)
            .frame(width: width)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.vertical, Self.verticalPadding)
            .background(readingTheme.pageFill)
            .environment(\.layoutDirection, .rightToLeft)
    }

    /// Ayah, then `۩` and the medallion behind no-break spaces, as on the page.
    private var text: AttributedString {
        let bodyFont = Font(mushafBodyCTFont(size: pointSize, typeface: typeface, bold: bold))
        var result = AttributedString(item.element.arabic)
        result.font = bodyFont
        result.foregroundColor = readingTheme.textMain
        if item.sajda {
            var sajda = AttributedString("\u{00A0}\u{06E9}")
            sajda.font = bodyFont
            sajda.foregroundColor = readingTheme.textSecondary
            result += sajda
        }
        if let number = item.number {
            var medallion = AttributedString("\u{00A0}" + arabicIndicDigits(number))
            medallion.font = Font(mushafNumberCTFont(size: pointSize * MushafTextMetrics.numberScale))
            medallion.foregroundColor = readingTheme.textMain
            result += medallion
        }
        return result
    }
}

/// One ayah as VoiceOver and the scroll position see it: a clear view over the
/// ayah's band. It carries `.id(element.id)` so the pager's memorize-follow
/// (`proxy.scrollTo`) finds the ayah, and the same accessibility element a
/// tappable `Verse` has: label, play hint, media traits, "selected" + value
/// while highlighted, activate → play. The VoiceOver outline follows the
/// ayah's glyphs line by line, and the hifz long-press actions are offered
/// as VoiceOver actions too.
struct MushafAyahAnchor: View {
    let item: MushafFlowItem
    /// `MushafItemShape` of kind `.glyphs`.
    let shape: MushafItemShape
    /// Position in reading order, from the right: VoiceOver would otherwise
    /// sort the ayat sharing a line left to right, i.e. backwards.
    let readingOrder: Int
    let itemCount: Int
    let isHighlighted: Bool
    let onTap: (Element) -> Void

    @Environment(\.readingAdjustments) private var adjustments
    @Environment(\.ayahMenuProvider) private var menuProvider

    private var traits: AccessibilityTraits {
        isHighlighted ? [.isButton, .startsMediaSession, .isSelected] : [.isButton, .startsMediaSession]
    }

    var body: some View {
        let actions = menuProvider?(item.element) ?? []
        // Reads only the size the layout already gave this anchor (for the
        // activation point) — nothing flows back into the layout.
        GeometryReader { proxy in
            Color.clear
                .contentShape(.accessibility, shape)
                .accessibilityElement()
                .accessibilityLabel(item.element.accessibilityLabelText)
                .accessibilityHint(adjustments.playHint)
                .accessibilityAddTraits(traits)
                .accessibilityValue(isHighlighted ? adjustments.activeValueLabel : "")
                .accessibilityAction { onTap(item.element) }
                .accessibilityActions {
                    ForEach(actions) { action in
                        Button(action.title, action: action.action)
                    }
                }
                .accessibilityActivationPoint(shape.activationPoint(in: CGRect(origin: .zero, size: proxy.size)))
        }
        // Higher reads first, inside the paragraph's own container.
        .accessibilitySortPriority(Double(itemCount - readingOrder))
        .id(item.element.id)
    }
}
