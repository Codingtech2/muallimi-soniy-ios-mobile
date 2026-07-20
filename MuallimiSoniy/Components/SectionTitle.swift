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

    init(_ text: String, subtitle: String? = nil) {
        self.text = text
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(spacing: 2) {  // mt-0.5 between title and subtitle
            Text(text)
                .font(arabicFont(20))  // text-xl
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))  // text-xs
                    .foregroundStyle(AppColor.textMuted)
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
