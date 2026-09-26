import SwiftUI

/// A centred surah heading flanked by `❀` ornaments — the SwiftUI port of the
/// surah-page `SurahTitle` (`❀ … ❀`). The heading renders in the Arabic body
/// font, bold, in the green `textSecondary` colour; the ornaments are small and
/// muted.
struct SurahTitle: View {
    let text: String

    /// Reader page/text palette — `.paper` (today's exact look) outside the
    /// reader, so the heading stays readable on every reading background.
    @Environment(\.readingTheme) private var readingTheme

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(spacing: 8) {  // gap-2
            ornament
            Text(text)
                .font(arabicFont(16))  // text-[…,0.98rem]
                .foregroundStyle(readingTheme.textSecondary)
                .multilineTextAlignment(.center)
            ornament
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)  // my-0.5
        .environment(\.layoutDirection, .rightToLeft)
        .surahHeaderFrame()
    }

    private var ornament: some View {
        Text("❀")
            .font(.system(size: 10))  // text-[0.625rem]
            .foregroundStyle(readingTheme.textMuted)
            .opacity(0.6)
    }
}

#if DEBUG
#Preview("SurahTitle") {
    VStack(spacing: 12) {
        SurahTitle("سُورَةُ الْفَاتِحَة")
        SurahTitle("اَوَّلُ سُورَةِ الْبَقَرَة")
    }
    .padding(24)
    .background(AppColor.background)
}
#endif
