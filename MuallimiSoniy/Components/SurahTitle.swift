import SwiftUI

/// A centred surah heading flanked by `❀` ornaments — the SwiftUI port of the
/// surah-page `SurahTitle` (`❀ … ❀`). The heading renders in the Arabic body
/// font, bold, in the green `textSecondary` colour; the ornaments are small and
/// muted.
///
/// Given a `surah`, inside the reader the framed heading is a banner that reads
/// that whole surah (`SurahBannerFrame`); without one it stays a static heading.
struct SurahTitle: View {
    let text: String
    /// The surah this heading opens, or `nil` for a heading that never plays.
    var surah: Int?
    /// The page's first surah heading: the one-time hint shows under it.
    var carriesHint = false

    init(_ text: String, surah: Int? = nil, carriesHint: Bool = false) {
        self.text = text
        self.surah = surah
        self.carriesHint = carriesHint
    }

    var body: some View {
        SurahBannerFrame(surah: surah, name: text, carriesHint: carriesHint) { isPlaying in
            SurahTitleLabel(text: text, isPlaying: isPlaying)
        }
    }
}

/// The `❀ name ❀` line inside a surah band (`SurahTitle` and the mushaf view's
/// `SurahBanner`). While its surah plays, the name and ornaments turn white on
/// the green band (web: name `#fff`, rosettes white at 0.85).
struct SurahTitleLabel: View {
    let text: String
    var isPlaying = false

    /// Reader page/text palette — `.paper` (today's exact look) outside the
    /// reader, so the heading stays readable on every reading background.
    @Environment(\.readingTheme) private var readingTheme
    @Environment(\.verseFontScale) private var verseFontScale

    var body: some View {
        HStack(spacing: 8) {  // gap-2
            ornament
            Text(text)
                .font(arabicFont(16 * verseFontScale))  // text-[…,0.98rem]
                .foregroundStyle(isPlaying ? Color.white : readingTheme.textSecondary)
                .multilineTextAlignment(.center)
            ornament
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)  // my-0.5
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var ornament: some View {
        Text("❀")
            .font(.system(size: 10 * verseFontScale))  // text-[0.625rem]
            .foregroundStyle(isPlaying ? Color.white : readingTheme.textMuted)
            .opacity(isPlaying ? 0.85 : 0.6)
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
