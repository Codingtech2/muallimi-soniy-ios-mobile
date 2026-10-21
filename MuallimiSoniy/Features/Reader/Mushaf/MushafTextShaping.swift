import CoreText
import Foundation

/// One drawable piece of a run, shaped at `MushafMeasurements.referenceSize`:
/// a word, the sajda sign or an ayah-number medallion.
nonisolated struct MushafPiece {
    nonisolated enum Role {
        /// Qur'an text — drawn in the text colour (white while highlighted).
        case text
        /// `۩` — drawn in the accent green (white while highlighted).
        case sajda
        /// The medallion — the same colour as its ayah's text.
        case number
    }

    let line: CTLine
    let width: CGFloat
    let role: Role
    /// Drawn thicker than the font (`MushafShapedText.fauxBoldRadius`).
    let fauxBold: Bool
}

/// The CoreText half of the Mushaf engine: every run of a paragraph shaped
/// once, at the reference size, plus the plain numbers (`measurements`) the
/// layout half breaks lines with. Nothing here depends on the column width or
/// the highlight, so one instance serves every layout pass and every redraw.
///
/// Each word is its own `CTLine`, so CoreText shapes the Arabic within a word
/// but never stretches a gap inside one — justification only ever widens the
/// gaps between words, the way the web does with `text-align: justify`.
nonisolated struct MushafShapedText {
    /// What `MushafTextGeometry` lays out.
    let measurements: MushafMeasurements
    /// Per run, its pieces from right to left: the word, then `۩`, then the
    /// number — so on screen the medallion closes the ayah on its left.
    let pieces: [[MushafPiece]]
    /// Space between the pieces of one run (the web's no-break spaces), at the
    /// reference size.
    var innerGap: CGFloat { measurements.spaceWidth }

    /// U+06E9 ARABIC PLACE OF SAJDAH.
    private static let sajdaSign = "\u{06E9}"
    /// "Bold text" for UthmanicHafs, which ships a single weight: the canvas
    /// thickens its glyphs by this much on every side (at the reference size,
    /// so 0.022 em). Not CoreText's stroke attribute — that one ignores the
    /// context colour and strokes black.
    static let fauxBoldRadius: CGFloat = 2.2

    init(items: [MushafFlowItem], typeface: ArabicTypeface, bold: Bool) {
        let size = MushafMeasurements.referenceSize
        let body = mushafBodyCTFont(size: size, typeface: typeface, bold: bold)
        let number = mushafNumberCTFont(size: size * MushafTextMetrics.numberScale)
        // Scheherazade has a real Bold face; UthmanicHafs gets thickened. The
        // medallions never are: their fine ornament clogs up when thickened.
        let fonts = Fonts(body: body, number: number, bodyFauxBold: bold && typeface == .naskh)
        let spaceWidth = Self.width(of: Self.makeLine(" ", font: body))

        var units: [MushafMeasurements.Unit] = []
        var pieces: [[MushafPiece]] = []
        for (itemIndex, item) in items.enumerated() {
            for run in Self.runs(of: item, fonts: fonts) {
                let gaps = CGFloat(max(run.count - 1, 0)) * spaceWidth
                let width = run.reduce(gaps) { $0 + $1.width }
                let hasNumber = run.contains { $0.role == .number }
                units.append(MushafMeasurements.Unit(item: itemIndex, width: width, hasNumber: hasNumber))
                pieces.append(run)
            }
        }

        self.pieces = pieces
        measurements = MushafMeasurements(
            units: units,
            spaceWidth: spaceWidth,
            bodyAscent: CTFontGetAscent(body),
            bodyDescent: CTFontGetDescent(body),
            numberAscent: CTFontGetAscent(number),
            numberDescent: CTFontGetDescent(number)
        )
    }

    // MARK: - Runs

    private nonisolated struct Fonts {
        let body: CTFont
        let number: CTFont
        let bodyFauxBold: Bool
    }

    /// The runs of one item: one per word, the last word carrying `۩` (sajda
    /// ayah) and the medallion — web `arabic NBSP [۩ NBSP] number`.
    private static func runs(of item: MushafFlowItem, fonts: Fonts) -> [[MushafPiece]] {
        var runs = words(of: item.element.arabic).map { word in
            [piece(word, role: .text, fonts: fonts)]
        }
        var ending: [MushafPiece] = []
        if item.sajda {
            ending.append(piece(sajdaSign, role: .sajda, fonts: fonts))
        }
        if let number = item.number {
            ending.append(piece(arabicIndicDigits(number), role: .number, fonts: fonts))
        }
        if !ending.isEmpty {
            if runs.isEmpty {
                runs.append(ending)
            } else {
                runs[runs.count - 1] += ending
            }
        }
        return runs
    }

    /// The words of an ayah, split at spaces. A "word" made only of combining
    /// marks — the small pause signs (`ۚ`, `ۖ`) the text sets between two
    /// spaces — stays with the word before it, space included, so CoreText
    /// draws it over that space as the browser does and it never starts a line.
    static func words(of text: String) -> [String] {
        let tokens = text.unicodeScalars
            .split { $0.properties.isWhitespace }
            .map { String(String.UnicodeScalarView($0)) }
        var words: [String] = []
        for token in tokens {
            let marksOnly = token.unicodeScalars.allSatisfy { $0.properties.generalCategory == .nonspacingMark }
            if marksOnly, let previous = words.popLast() {
                words.append(previous + " " + token)
            } else {
                words.append(token)
            }
        }
        return words
    }

    private static func piece(_ text: String, role: MushafPiece.Role, fonts: Fonts) -> MushafPiece {
        let isNumber = role == .number
        let line = makeLine(text, font: isNumber ? fonts.number : fonts.body)
        return MushafPiece(line: line, width: width(of: line), role: role, fauxBold: !isNumber && fonts.bodyFauxBold)
    }

    // MARK: - CoreText

    /// A one-piece line. Its colour comes from the drawing context, so the
    /// same line draws in any colour (normal, highlighted, sajda green).
    private static func makeLine(_ text: String, font: CTFont) -> CTLine {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        return CTLineCreateWithAttributedString(string as CFAttributedString)
    }

    /// Advance width of a line (trailing spaces included).
    private static func width(of line: CTLine) -> CGFloat {
        CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }
}

/// Keeps the last `MushafShapedText` of one `MushafFlowText`, so the costly
/// CoreText shaping runs once per (items, typeface, weight) — not on every
/// highlight change, which re-evaluates the view. Pure memo: the same key
/// always gives the same text, so reading it during `body` changes nothing
/// SwiftUI observes.
final class MushafShapingCache {
    private struct Key: Equatable {
        let items: [MushafFlowItem]
        let typeface: ArabicTypeface
        let bold: Bool
    }

    private var key: Key?
    private var text: MushafShapedText?

    func shapedText(for items: [MushafFlowItem], typeface: ArabicTypeface, bold: Bool) -> MushafShapedText {
        let key = Key(items: items, typeface: typeface, bold: bold)
        if let text, key == self.key {
            return text
        }
        let shaped = MushafShapedText(items: items, typeface: typeface, bold: bold)
        self.key = key
        text = shaped
        return shaped
    }
}
