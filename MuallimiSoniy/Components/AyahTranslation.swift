import SwiftUI

/// What the reader hands the surah pages while translations are on: the
/// chosen translation plus its ready-made "Notes" label, so the page
/// primitives never need a `ContentStore` of their own.
nonisolated struct AyahTranslationDisplay: Equatable, Sendable {
    let lookup: AyahTranslationLookup
    /// Localized "Notes" — the button that opens a translation's footnotes.
    let notesLabel: String
}

private struct AyahTranslationDisplayKey: EnvironmentKey {
    static let defaultValue: AyahTranslationDisplay? = nil
}

extension EnvironmentValues {
    /// The translation to show under the ayat, or `nil` (the default) while
    /// translations are off. Only `ReaderView` sets it, so every other screen
    /// renders exactly as before.
    var ayahTranslation: AyahTranslationDisplay? {
        get { self[AyahTranslationDisplayKey.self] }
        set { self[AyahTranslationDisplayKey.self] = newValue }
    }
}

extension View {
    /// Puts the translation of these ayah elements under the view while the
    /// reader shows translations. Ids that aren't an ayah of the book's surahs
    /// (bismillah, duas, letters…) have no translation, and with nothing to
    /// show the view passes through untouched.
    func ayahTranslation(for elementIds: [String]) -> some View {
        modifier(AyahTranslationModifier(elementIds: elementIds))
    }
}

private struct AyahTranslationModifier: ViewModifier {
    let elementIds: [String]

    @Environment(\.ayahTranslation) private var display

    @ViewBuilder
    func body(content: Content) -> some View {
        let lines = display?.lookup.lines(for: elementIds) ?? []
        if let display, !lines.isEmpty {
            VStack(spacing: AyahTranslationLayout.gapBelowArabic) {
                content
                AyahTranslationText(lines: lines, notesLabel: display.notesLabel)
            }
        } else {
            content
        }
    }
}

/// The translation under one line of verse — one ayah, or several when the
/// page flows them onto one line: "1. …  2. …". When the source has footnotes
/// the paragraph itself is the button that opens them in place (its `[1]`
/// markers are drawn in the accent colour), so none of the source's text is
/// left out while the page stays short.
struct AyahTranslationText: View {
    let lines: [AyahTranslationLine]
    let notesLabel: String

    @Environment(\.readingTheme) private var readingTheme
    @Environment(\.arabicFontScale) private var arabicFontScale
    @Environment(\.readingAdjustments) private var adjustments
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showsNotes = false

    private var effectiveBold: Bool { adjustments.boldText || legibilityWeight == .bold }
    private var notes: [String] { lines.compactMap(\.notes).filter { !$0.isEmpty } }

    var body: some View {
        VStack(spacing: AyahTranslationLayout.notesGap) {
            if notes.isEmpty {
                paragraphText
            } else {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                        showsNotes.toggle()
                    }
                } label: {
                    paragraphText
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(notesLabel)
                .accessibilityAddTraits(showsNotes ? .isSelected : [])
                if showsNotes {
                    notesBox
                }
            }
        }
        .padding(.horizontal, AyahTranslationLayout.horizontalPadding)
        .padding(.bottom, AyahTranslationLayout.bottomPadding)
        .environment(\.layoutDirection, .leftToRight)
    }

    private var paragraphText: some View {
        Text(paragraph)
            // Base size for the runs that set none (the gaps between ayat),
            // so no line comes out taller than the rest.
            .font(.system(size: textSize))
            .multilineTextAlignment(.center)
            .lineSpacing(AyahTranslationLayout.lineSpacing * adjustments.lineSpacingScale)
            .frame(maxWidth: .infinity)
    }

    /// Ayah numbers and footnote markers in the accent green, the translation
    /// in the caption colour — all readable (4.5:1+) on every reading background.
    private var paragraph: AttributedString {
        var result = AttributedString()
        for (index, line) in lines.enumerated() {
            if index > 0 {
                result.append(AttributedString("  "))
            }
            // A no-break space keeps the number on the same line as its text.
            var number = AttributedString("\(line.ayah).\u{00A0}")
            number.font = .system(size: textSize, weight: .semibold)
            number.foregroundColor = readingTheme.textSecondary
            var text = AttributedString(line.text)
            text.font = .system(size: textSize, weight: effectiveBold ? .semibold : .regular)
            text.foregroundColor = readingTheme.textMuted
            highlightNoteMarkers(in: &text)
            result.append(number)
            result.append(text)
        }
        return result
    }

    /// Paints every `[1]`-style footnote marker like the ayah numbers, so it
    /// reads as something to tap.
    private func highlightNoteMarkers(in text: inout AttributedString) {
        var searchStart = text.startIndex
        while let range = text[searchStart...].range(of: "[") {
            guard let close = text[range.upperBound...].range(of: "]") else { break }
            let marker = range.lowerBound..<close.upperBound
            let inside = String(text[range.upperBound..<close.lowerBound].characters)
            if !inside.isEmpty, inside.allSatisfy(\.isNumber) {
                text[marker].foregroundColor = readingTheme.textSecondary
                text[marker].font = .system(size: textSize, weight: .semibold)
            }
            searchStart = close.upperBound
        }
    }

    private var notesBox: some View {
        Text(notes.joined(separator: "\n\n"))
            .font(.system(size: noteSize, weight: effectiveBold ? .semibold : .regular))
            .foregroundStyle(readingTheme.textMuted)
            .lineSpacing(AyahTranslationLayout.lineSpacing * adjustments.lineSpacingScale)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AyahTranslationLayout.notesPadding)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(readingTheme.divider, lineWidth: 1)
            )
            .transition(.opacity)
    }

    /// Scales with the reader's text-size slider (and the iPad multiplier),
    /// same as the Arabic above it.
    private var textSize: CGFloat { AyahTranslationLayout.textPointSize * arabicFontScale }
    private var noteSize: CGFloat { AyahTranslationLayout.notePointSize * arabicFontScale }
}

private enum AyahTranslationLayout {
    /// A step below the `.sm` verse text (15 pt), so the Arabic stays the lead.
    static let textPointSize: CGFloat = 13
    static let notePointSize: CGFloat = 12
    static let lineSpacing: CGFloat = 2
    static let gapBelowArabic: CGFloat = 2
    static let notesGap: CGFloat = 8
    static let horizontalPadding: CGFloat = 12
    /// Room before the next verse line, so each translation reads with its ayah.
    static let bottomPadding: CGFloat = 10
    static let notesPadding: CGFloat = 10
}
