import SwiftUI

/// One ayah (or the isti'adha / a bismillah) inside a Mushaf paragraph.
nonisolated struct MushafFlowItem: Identifiable, Hashable, Sendable {
    let element: Element
    /// Drawn as the ornate medallion after the text, or `nil` for no number.
    let number: Int?
    /// The sajda ayah — `۩` between the text and the number.
    let sajda: Bool

    var id: String { element.id }
}

/// How the lines of a Mushaf paragraph sit.
nonisolated enum MushafFlowAlignment: Sendable, Hashable {
    /// Edge to edge, last line centred — a surah's ayat (web `.mushaf-flow`).
    case justified
    /// Every line centred — the isti'adha and bismillah lines.
    case centered
}

/// A run of ayat set like a printed mushaf — the native port of the web
/// `MushafPage` paragraph (`<p class="mushaf-text mushaf-flow">`): one right-to-
/// left paragraph, each ayah closed by its number in the UthmanicHafs medallion,
/// lines justified to both edges with the last one centred.
///
/// SwiftUI `Text` can't report where each ayah landed on iOS 17, so the
/// paragraph is laid out by hand (`MushafTextLayout.swift`) from words shaped
/// once with CoreText (`MushafTextShaping.swift`) and painted on a canvas
/// (`MushafTextCanvas.swift`). Per ayah, invisible views laid over the canvas
/// keep everything a tappable `Verse` offers: tap to play, the hifz long-press
/// menu, VoiceOver, the memorize-follow scroll anchor
/// (`MushafTextInteraction.swift`).
///
/// Size, typeface, weight, colours, hidden ayat and menus all come from the
/// reader's environment, like the other reading primitives.
struct MushafFlowText: View {
    let items: [MushafFlowItem]
    var alignment: MushafFlowAlignment = .justified
    /// Ids drawn highlighted (green pill, white text) — the active element plus
    /// any element sharing its audio take.
    let highlightedIds: Set<String>
    let onTap: (Element) -> Void

    @Environment(\.verseFontScale) private var verseFontScale
    @Environment(\.readingAdjustments) private var adjustments
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.arabicTypeface) private var arabicTypeface
    @Environment(\.hifzHiddenElementIds) private var hiddenIds

    /// Memo of the CoreText shaping (see `MushafShapingCache`). Never changes
    /// identity and never drives a re-render.
    @State private var shapingCache = MushafShapingCache()

    private var isBold: Bool { adjustments.boldText || legibilityWeight == .bold }

    var body: some View {
        let shaped = shapingCache.shapedText(for: items, typeface: arabicTypeface, bold: isBold)
        let style = MushafGeometryStyle(
            verseFontScale: verseFontScale,
            lineSpacingScale: adjustments.lineSpacingScale,
            alignment: alignment
        )
        MushafFlowLayout(measurements: shaped.measurements, style: style) {
            MushafTextCanvas(
                shaped: shaped,
                style: style,
                highlighted: itemIndices(of: highlightedIds),
                hidden: itemIndices(of: hiddenIds ?? []),
                strongHighlight: adjustments.strongHighlight,
                blurRadius: MushafTextMetrics.hiddenBlurRadius * verseFontScale
            )
            .layoutValue(key: MushafSubviewRoleKey.self, value: .canvas)

            // Anchors under the hit areas: they never take a touch, only
            // VoiceOver focus and `scrollTo`.
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                MushafAyahAnchor(
                    item: item,
                    shape: MushafItemShape(measurements: shaped.measurements, style: style, item: index, kind: .glyphs),
                    readingOrder: index,
                    itemCount: items.count,
                    isHighlighted: highlightedIds.contains(item.id),
                    onTap: onTap
                )
                .layoutValue(key: MushafSubviewRoleKey.self, value: .anchor(index))
            }
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                MushafAyahHitArea(
                    item: item,
                    shape: MushafItemShape(measurements: shaped.measurements, style: style, item: index, kind: .hit),
                    onTap: onTap
                )
                .layoutValue(key: MushafSubviewRoleKey.self, value: .hitArea(index))
            }
        }
        // The paragraph is its own VoiceOver container, so the anchors' reading
        // order (sort priority) applies among its ayat only.
        .accessibilityElement(children: .contain)
        // Every frame and rect is computed left to right; don't let a
        // right-to-left environment mirror them a second time.
        .environment(\.layoutDirection, .leftToRight)
    }

    private func itemIndices(of ids: Set<String>) -> Set<Int> {
        guard !ids.isEmpty else { return [] }
        return Set(items.indices.filter { ids.contains(items[$0].id) })
    }
}

/// What each subview of a `MushafFlowLayout` is, so the layout knows where it goes.
nonisolated enum MushafSubviewRole: Sendable, Hashable {
    /// The painted text — the whole column plus `MushafTextMetrics.canvasOutset`.
    case canvas
    /// Item `n`'s VoiceOver/scroll anchor — the full column width over its lines.
    case anchor(Int)
    /// Item `n`'s hit area — the same band as its anchor.
    case hitArea(Int)
    /// Anything untagged gets no room.
    case none
}

nonisolated struct MushafSubviewRoleKey: LayoutValueKey {
    static let defaultValue: MushafSubviewRole = .none
}

/// Sizes a Mushaf paragraph to its laid-out text and puts the canvas, anchors
/// and hit areas where `MushafTextGeometry` says. Its size depends only on the
/// proposed width and its inputs — nothing is measured and stored — so a
/// layout pass always gives the same answer (`PageHostView`'s stability
/// contract). The geometry is cheap arithmetic over pre-measured runs, so it is
/// simply recomputed wherever it's needed instead of cached.
nonisolated struct MushafFlowLayout: Layout {
    let measurements: MushafMeasurements
    let style: MushafGeometryStyle

    /// Width used when the parent doesn't offer one (ideal-size queries). A
    /// reading column always proposes a real width.
    private static let fallbackWidth: CGFloat = 320

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = Self.columnWidth(proposal.width)
        let geometry = MushafTextGeometry(measurements: measurements, style: style, width: width)
        return CGSize(width: width, height: geometry.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let geometry = MushafTextGeometry(measurements: measurements, style: style, width: bounds.width)
        for subview in subviews {
            let frame = Self.frame(of: subview[MushafSubviewRoleKey.self], geometry: geometry, bounds: bounds)
            subview.place(at: frame.origin, proposal: ProposedViewSize(frame.size))
        }
    }

    private static func columnWidth(_ proposed: CGFloat?) -> CGFloat {
        guard let proposed, proposed.isFinite else { return fallbackWidth }
        return max(proposed, 0)
    }

    private static func frame(of role: MushafSubviewRole, geometry: MushafTextGeometry, bounds: CGRect) -> CGRect {
        switch role {
        case .canvas:
            return bounds.insetBy(dx: -MushafTextMetrics.canvasOutset, dy: -MushafTextMetrics.canvasOutset)
        case .anchor(let item), .hitArea(let item):
            // Full width, so `MushafItemShape` can rebuild the geometry from it.
            let band = geometry.band(of: item)
            return CGRect(x: bounds.minX, y: bounds.minY + band.minY, width: bounds.width, height: band.height)
        case .none:
            return CGRect(origin: bounds.origin, size: .zero)
        }
    }
}
