import SwiftUI

/// A centred Arabic section heading with an optional Uzbek subtitle — the
/// SwiftUI port of the web `Title`.
///
/// The heading renders in the Arabic body font at `text-xl` in the green
/// `textSecondary` colour; the subtitle (typically an Uzbek transliteration such
/// as "Qadr surasi") renders small and muted below it.
struct SectionTitle: View {
    let text: String
    var subtitle: String?

    /// Reader page/text palette — defaults to `.paper` (today's exact look)
    /// outside the reader; `ReaderView` injects the live value.
    @Environment(\.readingTheme) private var readingTheme
    /// Line spacing / bold / highlight / VoiceOver strings from the "Aa" sheet.
    @Environment(\.readingAdjustments) private var adjustments
    /// System-wide Settings → Accessibility → Bold Text — treated the same as
    /// the app's own `boldText` reading option.
    @Environment(\.legibilityWeight) private var legibilityWeight

    private var effectiveBold: Bool { adjustments.boldText || legibilityWeight == .bold }

    init(_ text: String, subtitle: String? = nil) {
        self.text = text
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 2) {  // mt-0.5 between title and subtitle
            Text(text)
                .font(arabicFont(20, weight: arabicWeight(bold: effectiveBold)))  // text-xl
                .foregroundStyle(readingTheme.textSecondary)
                .multilineTextAlignment(.center)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))  // text-xs
                    .foregroundStyle(readingTheme.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)  // my-2
    }
}

#if DEBUG
#Preview("SectionTitle") {
    VStack(spacing: 16) {
        SectionTitle("مَدْلِي حَرْفْلَر", subtitle: "Madli harflar")
        SectionTitle("سُورَةُ الْقَدْر")
    }
    .padding(24)
    .background(AppColor.background)
}
#endif
