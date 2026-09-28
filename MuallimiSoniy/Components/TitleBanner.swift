import SwiftUI

/// A tappable heading element set in the surah frame — the SwiftUI port of the
/// web `TitleBanner` (`SurahBanner.tsx`). Book pages 34–35 use it for the
/// kalima names, so each name stands in its own frame like a surah name.
///
/// Tapping plays only this heading's own audio. While it is the active element
/// the whole band lights up green (web `surah-banner-playing`) instead of a
/// pill showing inside the frame.
struct TitleBanner: View {
    let element: Element
    let isActive: Bool
    let onTap: (Element) -> Void

    /// Reader page/text palette — `.paper` (today's exact look) outside the reader.
    @Environment(\.readingTheme) private var readingTheme
    /// VoiceOver strings from the "Aa" sheet.
    @Environment(\.readingAdjustments) private var adjustments
    /// Settings → Accessibility → Reduce Motion — skips the highlight spring.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button { onTap(element) } label: {
            Text(element.arabic)
                .font(arabicFont(16))  // text-[…,0.98rem] bold
                .foregroundStyle(isActive ? Color.white : readingTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .surahHeaderFrame(isActive: isActive, compact: true)  // my-0.5
        }
        .buttonStyle(.plain)
        .environment(\.layoutDirection, .rightToLeft)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.62), value: isActive)
        .accessibilityLabel(element.accessibilityLabelText)
        .accessibilityHint(adjustments.playHint)
        .accessibilityAddTraits(
            isActive ? [.isHeader, .startsMediaSession, .isSelected] : [.isHeader, .startsMediaSession]
        )
        .accessibilityValue(isActive ? adjustments.activeValueLabel : "")
        .id(element.id)
    }
}

#if DEBUG
#Preview("TitleBanner") {
    let kalima = Element(
        id: "k1_head", type: .jumla, arabic: "كَلِمَةُ طَيِّبَةٌ",
        uzbek: "", audioUrl: nil, start: 0, end: 0, x: 0, y: 0, width: 0, height: 0
    )
    return VStack(spacing: 0) {
        TitleBanner(element: kalima, isActive: false, onTap: { _ in })
        TitleBanner(element: kalima, isActive: true, onTap: { _ in })
    }
    .padding(24)
    .frame(width: 360)
    .background(AppColor.background)
}
#endif
