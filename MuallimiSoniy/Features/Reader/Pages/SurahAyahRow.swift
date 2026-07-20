import SwiftUI

/// One ayah token trailed by a decorative `❀` separator — the atomic unit of a
/// surah `AyahRow` (web `AyahRow`'s inner `span`: `inline-flex flex-row-reverse
/// items-center`). The flower marks each verse end; bismillah lines render as a
/// plain `WordRow` instead and therefore get no flower.
///
/// The pair is atomic: it never breaks between the glyph and its flower when the
/// containing `AyahRow` wraps.
struct AyahPair: View {
    let element: Element
    var size: ArabicSize = .sm
    let isActive: Bool
    let onTap: (Element) -> Void

    var body: some View {
        HStack(spacing: 4) {  // gap-[clamp(…,0.25rem)]
            ArabicElementView(element: element, size: size, isActive: isActive) { onTap(element) }
            AyahSeparator()   // ❀ (shared, defined in Verse.swift)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

/// A wrapping, right-to-left row of flower-separated ayahs — the SwiftUI port of
/// the web `AyahRow` (`flex w-full flex-row-reverse flex-wrap justify-center
/// gap-*`). Surah pages use it to flow several short verses onto one centred
/// line; each verse keeps its trailing `❀` via `AyahPair`. Bismillah lines use
/// `WordRow` (no flower).
///
/// Distinct from `Verse`, which appends a numbered `﴿N﴾` marker — these primer
/// pages separate verses with the `❀` ornament only, no numbers.
struct AyahRow: View {
    let elements: [Element]
    var size: ArabicSize = .sm
    var spacing: RowSpacing = .gap2
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        FlowLayout(spacing: spacing.value, lineSpacing: spacing.value) {
            ForEach(elements) { element in
                AyahPair(element: element, size: size, isActive: activeId == element.id, onTap: onTap)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
