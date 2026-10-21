import SwiftUI
import CoreText

/// Paints one Mushaf paragraph: the green pills under highlighted ayat first,
/// then the glyphs of every run, with the ayat hidden for a hifz self-test on a
/// blurred layer of their own (their pill stays crisp, so the learner still
/// sees which ayah is being recited).
///
/// Drawing only. Taps, the long-press menu, VoiceOver and the scroll anchors
/// are separate views laid over it (`MushafTextInteraction.swift`). The canvas
/// rebuilds the same `MushafTextGeometry` from its own width that the layout
/// placed those views with, so the two always agree.
struct MushafTextCanvas: View {
    let shaped: MushafShapedText
    let style: MushafGeometryStyle
    /// Item indices drawn with the green pill and white text.
    let highlighted: Set<Int>
    /// Item indices blurred for a hifz "hide text" session.
    let hidden: Set<Int>
    let strongHighlight: Bool
    let blurRadius: CGFloat

    @Environment(\.readingTheme) private var readingTheme
    /// Read so a light/dark switch re-renders the canvas with re-resolved colours.
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let width = size.width - 2 * MushafTextMetrics.canvasOutset
        guard width > 0 else { return }
        let geometry = MushafTextGeometry(measurements: shaped.measurements, style: style, width: width)
        context.translateBy(x: MushafTextMetrics.canvasOutset, y: MushafTextMetrics.canvasOutset)
        drawPills(in: context, geometry: geometry)

        let palette = Palette(readingTheme: readingTheme, environment: context.environment)
        let hidden = hidden
        drawGlyphs(in: context, geometry: geometry, palette: palette) { !hidden.contains($0) }
        guard !hidden.isEmpty else { return }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: blurRadius))
            drawGlyphs(in: layer, geometry: geometry, palette: palette) { hidden.contains($0) }
        }
    }

    // MARK: - Highlight

    /// One rounded pill per line fragment of every highlighted ayah, over a
    /// soft green glow (web `bg-primary rounded-md` + `box-shadow`).
    private func drawPills(in context: GraphicsContext, geometry: MushafTextGeometry) {
        let radius = MushafTextMetrics.pillCornerRadius
        let corner = CGSize(width: radius, height: radius)
        var path = Path()
        for fragment in geometry.fragments where highlighted.contains(fragment.item) {
            path.addRoundedRect(in: fragment.pill, cornerSize: corner, style: .continuous)
        }
        guard !path.isEmpty else { return }
        context.drawLayer { glow in
            glow.addFilter(.shadow(
                color: AppColor.primaryGlow,
                radius: MushafTextMetrics.glowRadius,
                x: 0,
                y: MushafTextMetrics.glowOffsetY,
                options: .shadowOnly
            ))
            glow.fill(path, with: .color(AppColor.primary))
        }
        context.drawLayer { pill in
            if strongHighlight {
                pill.addFilter(.brightness(MushafTextMetrics.strongHighlightBrightness))
            }
            pill.fill(path, with: .color(AppColor.primary))
        }
    }

    // MARK: - Glyphs

    /// Draws the runs whose item passes `include`, each piece at its place on
    /// its line's baseline, scaled from the reference size it was shaped at.
    private func drawGlyphs(
        in context: GraphicsContext,
        geometry: MushafTextGeometry,
        palette: Palette,
        include: (Int) -> Bool
    ) {
        let units = shaped.measurements.units
        let gap = shaped.innerGap * geometry.scale
        context.withCGContext { cgContext in
            cgContext.textMatrix = .identity
            for line in geometry.lines {
                for index in line.units where include(units[index].item) {
                    let isHighlighted = highlighted.contains(units[index].item)
                    var right = geometry.unitX[index] + units[index].width * geometry.scale
                    for piece in shaped.pieces[index] {
                        let left = right - piece.width * geometry.scale
                        let color = palette.color(for: piece.role, highlighted: isHighlighted)
                        let origin = CGPoint(x: left, y: line.baseline)
                        draw(piece, at: origin, scale: geometry.scale, color: color, in: cgContext)
                        right = left - gap
                    }
                }
            }
        }
    }

    private func draw(
        _ piece: MushafPiece,
        at origin: CGPoint,
        scale: CGFloat,
        color: CGColor,
        in cgContext: CGContext
    ) {
        cgContext.saveGState()
        // The canvas is y-down while CoreText lays glyphs out y-up. Flip the
        // whole coordinate space, not just the text matrix: CoreText places
        // each glyph (the vertical steps of joined letters, the harakat) in
        // user space, so a text-matrix-only flip turns those offsets upside down.
        cgContext.translateBy(x: origin.x, y: origin.y)
        cgContext.scaleBy(x: scale, y: -scale)
        // The lines take their colour from the context.
        cgContext.setFillColor(color)
        let offsets = piece.fauxBold ? Self.fauxBoldOffsets : [.zero]
        for offset in offsets {
            cgContext.textPosition = offset
            CTLineDraw(piece.line, cgContext)
        }
        cgContext.restoreGState()
    }

    /// "Bold text" for UthmanicHafs, which has a single weight: the glyphs
    /// are filled again around a small circle (in reference-size units, so it
    /// grows with the text), which thickens every stroke evenly. Not a glyph
    /// outline stroke: the canvas's context doesn't scale a stroke width with
    /// the text the way a plain bitmap context does, so its weight can't be
    /// relied on.
    private static let fauxBoldOffsets: [CGPoint] = {
        let radius = MushafShapedText.fauxBoldRadius
        let diagonal = radius / CGFloat(2).squareRoot()
        return [
            .zero,
            CGPoint(x: radius, y: 0), CGPoint(x: -radius, y: 0),
            CGPoint(x: 0, y: radius), CGPoint(x: 0, y: -radius),
            CGPoint(x: diagonal, y: diagonal), CGPoint(x: -diagonal, y: diagonal),
            CGPoint(x: diagonal, y: -diagonal), CGPoint(x: -diagonal, y: -diagonal)
        ]
    }()
}

/// The three glyph colours, resolved once per draw for the canvas's appearance.
private struct Palette {
    let text: CGColor
    let highlightedText: CGColor
    let sajda: CGColor

    init(readingTheme: ReadingBackground, environment: EnvironmentValues) {
        text = readingTheme.textMain.resolve(in: environment).cgColor
        highlightedText = Color.white.resolve(in: environment).cgColor
        // The theme's green for text, not the fill green: `primary` gives a
        // glyph only ~3:1 on the paper, sepia and gray backgrounds.
        sajda = readingTheme.textSecondary.resolve(in: environment).cgColor
    }

    /// Web: highlighted ayah text is white; `۩` is accent green otherwise; the
    /// medallion takes its ayah's text colour.
    func color(for role: MushafPiece.Role, highlighted: Bool) -> CGColor {
        if highlighted {
            return highlightedText
        }
        return role == .sajda ? sajda : text
    }
}
