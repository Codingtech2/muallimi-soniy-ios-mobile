import CoreGraphics

/// The web numbers the Mushaf text is built from (`globals.css` `.mushaf-*`,
/// `MushafPage.tsx`), plus the iOS-only line-spacing reading option.
nonisolated enum MushafTextMetrics {
    /// `font-size: clamp(1.05rem, 5.4cqi, 1.6rem)` with 1rem = 16 pt, where
    /// `cqi` is 1% of the page card's content width.
    static let minFontSize: CGFloat = 16.8
    static let maxFontSize: CGFloat = 25.6
    static let fontSizePerWidth: CGFloat = 0.054
    /// `.mushaf-text { line-height: 2.3 }` — room for the harakat.
    static let lineHeight: CGFloat = 2.3
    /// `.mushaf-num { font-size: 1.15em }`.
    static let numberScale: CGFloat = 1.15
    /// `.mushaf-ayah` `px-1`: highlight padding on both sides of every line
    /// fragment of an ayah (`box-decoration-break: clone`). It takes up room in
    /// the line, as inline padding does in the browser.
    static let pillPadding: CGFloat = 4
    /// `rounded-md`.
    static let pillCornerRadius: CGFloat = 6
    /// Highlight glow, web `box-shadow: 0 4px 14px var(--color-primary-glow)`.
    static let glowRadius: CGFloat = 7
    static let glowOffsetY: CGFloat = 4
    /// The "strong highlight" option darkens the pill like `ArabicElementView`.
    static let strongHighlightBrightness: Double = -0.12
    /// Hifz "hide text" blur, same as `hifzHiddenText` (× the verse scale).
    static let hiddenBlurRadius: CGFloat = 7
    /// Margin the canvas draws into around the text column, so a pill's glow
    /// on the first or last line (or a mark reaching above a line) isn't cut
    /// off at the column edge. `MushafFlowLayout` grows the canvas by it.
    static let canvasOutset: CGFloat = 24
    /// iOS reading option: each step of the line-spacing slider (1.0…2.0) adds
    /// this many font sizes to a line, so 2.0 opens the text up by 0.8 em
    /// instead of doubling an already tall 2.3 em line.
    static let extraLineHeightPerSpacing: CGFloat = 0.8

    /// The paragraph font size for a text column `width` points wide.
    static func fontSize(forWidth width: CGFloat, verseFontScale: CGFloat) -> CGFloat {
        min(max(width * fontSizePerWidth, minFontSize), maxFontSize) * verseFontScale
    }
}

/// What `MushafShapedText` measured once at `referenceSize` — plain numbers
/// only, so the layout can be redone for any width anywhere (a hit-test
/// `Shape` included, which SwiftUI may evaluate off the main thread).
nonisolated struct MushafMeasurements: Sendable, Hashable {
    /// Point size the text is shaped at. CoreText advances grow linearly with
    /// the point size (iOS has no hinting), so one shaping serves every width
    /// and every text-size setting: the layout just scales these numbers.
    static let referenceSize: CGFloat = 100

    /// One unbreakable run: a word, or an ayah's last word glued to its `۩` and
    /// number (so a number never wraps away from its ayah).
    nonisolated struct Unit: Sendable, Hashable {
        /// Index of the `MushafFlowItem` this run belongs to.
        let item: Int
        let width: CGFloat
        /// Carries the ayah-number medallion, which is set larger than the text.
        let hasNumber: Bool
    }

    /// Every run of the paragraph, in reading order.
    let units: [Unit]
    /// One space of the text font — the gap between two runs before justifying.
    let spaceWidth: CGFloat
    let bodyAscent: CGFloat
    let bodyDescent: CGFloat
    /// Of the number font, already at `numberScale` × the reference size.
    let numberAscent: CGFloat
    let numberDescent: CGFloat
}

/// The inputs of a layout that come from the reader rather than the text.
nonisolated struct MushafGeometryStyle: Sendable, Hashable {
    let verseFontScale: CGFloat
    let lineSpacingScale: CGFloat
    let alignment: MushafFlowAlignment
}

/// The Mushaf paragraph laid out at one width: lines, where every run sits,
/// and each ayah's highlight pill and tap rect on each of its lines.
///
/// A pure function of (measurements, style, width) — the layout container,
/// the canvas and every hit-test shape each rebuild it for the same width and
/// get the same answer, so nothing has to be measured, stored and fed back
/// (`PageHostView`'s layout-stability contract).
///
/// Mirrors the browser: greedy line breaking; justified lines share their
/// leftover width equally between the gaps; the last line is centred
/// (`text-align-last: center`); a line holding one run starts at the right
/// edge, like an unjustifiable line in CSS; a line's height follows the CSS
/// inline box rules, so a line with a medallion (1.15× text) is a bit taller.
nonisolated struct MushafTextGeometry: Sendable {
    nonisolated struct Line: Sendable {
        let units: Range<Int>
        let top: CGFloat
        let height: CGFloat
        let baseline: CGFloat
        var bottom: CGFloat { top + height }
    }

    /// The part of one ayah that sits on one line.
    nonisolated struct Fragment: Sendable {
        let item: Int
        /// The green highlight: the glyphs ± `pillPadding`, as tall as the
        /// text font's ascent + descent (the CSS inline content area).
        let pill: CGRect
        /// The tap target: the pill widened to meet its neighbours on the line,
        /// as tall as the whole line, so the line has no dead gaps.
        let hit: CGRect
    }

    /// Font size ÷ `referenceSize` — multiplies every measured number.
    let scale: CGFloat
    let lines: [Line]
    /// Left edge of every run.
    let unitX: [CGFloat]
    let fragments: [Fragment]

    var height: CGFloat { lines.last?.bottom ?? 0 }

    init(measurements: MushafMeasurements, style: MushafGeometryStyle, width: CGFloat) {
        let fontSize = MushafTextMetrics.fontSize(forWidth: width, verseFontScale: style.verseFontScale)
        let scale = fontSize / MushafMeasurements.referenceSize
        let runs = Runs(measurements: measurements, scale: scale)
        let ranges = runs.breakLines(width: width)

        var unitX = [CGFloat](repeating: 0, count: measurements.units.count)
        var lines: [Line] = []
        var top: CGFloat = 0
        for (index, range) in ranges.enumerated() {
            let isLast = index == ranges.count - 1
            runs.place(range, isLast: isLast, alignment: style.alignment, width: width, into: &unitX)
            let line = Self.line(range, top: top, measurements: measurements, fontSize: fontSize, style: style)
            lines.append(line)
            top = line.bottom
        }

        self.scale = scale
        self.lines = lines
        self.unitX = unitX
        self.fragments = Self.makeFragments(lines: lines, runs: runs, unitX: unitX, width: width)
    }

    /// The fragments of one ayah, top line first.
    func fragments(of item: Int) -> [Fragment] {
        fragments.filter { $0.item == item }
    }

    /// One ayah's whole tap area (all its hit rects together); its top and
    /// bottom are those of the ayah's first and last line. `.zero` for an ayah
    /// with no text.
    func band(of item: Int) -> CGRect {
        Self.union(fragments(of: item).map(\.hit))
    }

    private static func union(_ rects: [CGRect]) -> CGRect {
        guard let first = rects.first else { return .zero }
        return rects.dropFirst().reduce(first) { $0.union($1) }
    }

    // MARK: - Lines

    /// Height and baseline of one line, the way CSS sizes a line box: the text
    /// font's ascent + descent centred in `lineHeight` em, and — when the line
    /// has a medallion — the same for the 1.15× number font, whichever box
    /// reaches further. The reading option's extra space goes half above,
    /// half below.
    private static func line(
        _ range: Range<Int>,
        top: CGFloat,
        measurements: MushafMeasurements,
        fontSize: CGFloat,
        style: MushafGeometryStyle
    ) -> Line {
        let scale = fontSize / MushafMeasurements.referenceSize
        let ascent = measurements.bodyAscent * scale
        let descent = measurements.bodyDescent * scale
        let halfLeading = (MushafTextMetrics.lineHeight * fontSize - ascent - descent) / 2
        var above = ascent + halfLeading
        var below = descent + halfLeading

        if measurements.units[range].contains(where: \.hasNumber) {
            let numberAscent = measurements.numberAscent * scale
            let numberDescent = measurements.numberDescent * scale
            let numberLine = MushafTextMetrics.lineHeight * fontSize * MushafTextMetrics.numberScale
            let numberLeading = (numberLine - numberAscent - numberDescent) / 2
            above = max(above, numberAscent + numberLeading)
            below = max(below, numberDescent + numberLeading)
        }

        let spacingSteps = max(style.lineSpacingScale - 1, 0)
        let extra = spacingSteps * MushafTextMetrics.extraLineHeightPerSpacing * fontSize
        above += extra / 2
        below += extra / 2
        return Line(units: range, top: top, height: above + below, baseline: top + above)
    }

    // MARK: - Fragments

    /// Groups each line's runs by ayah into fragments, then widens the tap
    /// rects so they tile the line: neighbours meet halfway between their
    /// pills, and the outermost ones reach the column edges.
    private static func makeFragments(lines: [Line], runs: Runs, unitX: [CGFloat], width: CGFloat) -> [Fragment] {
        var result: [Fragment] = []
        for line in lines {
            let pills = linePills(line, runs: runs, unitX: unitX)
            for (index, pill) in pills.enumerated() {
                // Fragments run right to left: index 0 is the rightmost.
                let right = index == 0
                    ? max(width, pill.rect.maxX)
                    : (pill.rect.maxX + pills[index - 1].rect.minX) / 2
                let left = index == pills.count - 1
                    ? min(0, pill.rect.minX)
                    : (pill.rect.minX + pills[index + 1].rect.maxX) / 2
                let hit = CGRect(x: left, y: line.top, width: right - left, height: line.height)
                result.append(Fragment(item: pill.item, pill: pill.rect, hit: hit))
            }
        }
        return result
    }

    /// The highlight pill of every ayah on one line, right to left.
    private static func linePills(_ line: Line, runs: Runs, unitX: [CGFloat]) -> [(item: Int, rect: CGRect)] {
        let pad = MushafTextMetrics.pillPadding
        let top = max(line.baseline - runs.ascent, line.top)
        let bottom = min(line.baseline + runs.descent, line.bottom)
        var pills: [(item: Int, rect: CGRect)] = []
        var start = line.units.lowerBound
        while start < line.units.upperBound {
            let item = runs.item(start)
            var end = start
            while end + 1 < line.units.upperBound, runs.item(end + 1) == item {
                end += 1
            }
            // In right-to-left order the fragment's first run is its rightmost.
            let minX = unitX[end] - pad
            let maxX = unitX[start] + runs.widths[start] + pad
            pills.append((item, CGRect(x: minX, y: top, width: maxX - minX, height: bottom - top)))
            start = end + 1
        }
        return pills
    }
}

/// The runs at their real size, with the two line-level operations: breaking
/// into lines and placing one line's runs.
private nonisolated struct Runs {
    let measurements: MushafMeasurements
    let widths: [CGFloat]
    let space: CGFloat
    let ascent: CGFloat
    let descent: CGFloat

    /// Breaking tolerance, so a run that fits exactly isn't pushed down by
    /// floating-point noise.
    private static let tolerance: CGFloat = 0.01

    init(measurements: MushafMeasurements, scale: CGFloat) {
        self.measurements = measurements
        widths = measurements.units.map { $0.width * scale }
        space = measurements.spaceWidth * scale
        ascent = measurements.bodyAscent * scale
        descent = measurements.bodyDescent * scale
    }

    func item(_ index: Int) -> Int { measurements.units[index].item }

    /// Whether run `index` opens a new ayah fragment on a line that already
    /// holds the run before it.
    private func startsNewItem(_ index: Int) -> Bool {
        item(index) != item(index - 1)
    }

    /// Greedy breaking: a run moves to the next line when the line, with the
    /// pill padding of each ayah fragment on it, would overflow `width`.
    func breakLines(width: CGFloat) -> [Range<Int>] {
        let pad = MushafTextMetrics.pillPadding
        var ranges: [Range<Int>] = []
        var start = 0
        var used: CGFloat = 0
        for index in widths.indices {
            if index == start {
                used = widths[index] + 2 * pad
                continue
            }
            let added = space + widths[index] + (startsNewItem(index) ? 2 * pad : 0)
            if used + added > width + Self.tolerance {
                ranges.append(start..<index)
                start = index
                used = widths[index] + 2 * pad
            } else {
                used += added
            }
        }
        if start < widths.count {
            ranges.append(start..<widths.count)
        }
        return ranges
    }

    /// Natural width of a line: runs, one space between runs, and the pill
    /// padding on both sides of each ayah fragment.
    private func naturalWidth(_ range: Range<Int>) -> CGFloat {
        let fragments = range.filter { $0 == range.lowerBound || startsNewItem($0) }.count
        let runs = range.reduce(0) { $0 + widths[$1] }
        return runs + CGFloat(range.count - 1) * space + CGFloat(fragments) * 2 * MushafTextMetrics.pillPadding
    }

    /// Writes the left edge of each run of one line into `unitX`, placing the
    /// first run at the right edge (right-to-left text).
    func place(
        _ range: Range<Int>,
        isLast: Bool,
        alignment: MushafFlowAlignment,
        width: CGFloat,
        into unitX: inout [CGFloat]
    ) {
        let pad = MushafTextMetrics.pillPadding
        let leftover = width - naturalWidth(range)
        let justify = alignment == .justified && !isLast
        // Justified lines grow every gap equally; one run alone stays at the
        // start (right) edge; centred lines split the leftover on both sides.
        let stretch = justify && range.count > 1 ? max(leftover, 0) / CGFloat(range.count - 1) : 0
        let rightInset = justify ? 0 : max(leftover, 0) / 2

        var cursor = width - rightInset
        for index in range {
            if index == range.lowerBound || startsNewItem(index) {
                cursor -= pad
            }
            cursor -= widths[index]
            unitX[index] = cursor
            let isLastRun = index == range.upperBound - 1
            if isLastRun || item(index + 1) != item(index) {
                cursor -= pad
            }
            if !isLastRun {
                cursor -= space + stretch
            }
        }
    }
}
