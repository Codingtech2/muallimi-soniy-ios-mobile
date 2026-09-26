import SwiftUI

extension View {
    /// Sets a surah heading in a double-ruled band with a round medallion at
    /// each end — the way a printed mushaf marks where a new surah starts — so
    /// a learner sees at a glance that the text below is a different surah.
    /// The heading itself (static or tappable) is drawn unchanged inside.
    func surahHeaderFrame() -> some View {
        modifier(SurahHeaderFrame())
    }
}

private struct SurahHeaderFrame: ViewModifier {
    @Environment(\.readingTheme) private var readingTheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, SurahHeaderLayout.sidePadding)
            .padding(.vertical, SurahHeaderLayout.innerPadding)
            .frame(maxWidth: .infinity)
            .background(band)
            .overlay(medallions)
            .padding(.vertical, SurahHeaderLayout.outerMargin)
    }

    private var accent: Color { readingTheme.textSecondary }

    /// Light tint, a bold outer rule and a thin inner rule.
    private var band: some View {
        let outer = RoundedRectangle(cornerRadius: SurahHeaderLayout.cornerRadius, style: .continuous)
        let inner = RoundedRectangle(
            cornerRadius: SurahHeaderLayout.cornerRadius - SurahHeaderLayout.ruleGap,
            style: .continuous
        )
        return outer
            .fill(accent.opacity(0.07))
            .overlay(outer.strokeBorder(accent.opacity(0.6), lineWidth: 1.5))
            .overlay(
                inner
                    .strokeBorder(accent.opacity(0.35), lineWidth: 0.75)
                    .padding(SurahHeaderLayout.ruleGap)
            )
            .accessibilityHidden(true)
    }

    private var medallions: some View {
        HStack(spacing: 0) {
            medallion
            Spacer(minLength: 0)
            medallion
        }
        .padding(.horizontal, SurahHeaderLayout.medallionInset)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A ring with a softly filled centre, like the roundels in a mushaf's
    /// surah headers.
    private var medallion: some View {
        ZStack {
            Circle().strokeBorder(accent.opacity(0.55), lineWidth: 1)
            Circle()
                .fill(accent.opacity(0.14))
                .padding(SurahHeaderLayout.medallionSize * 0.22)
        }
        .frame(width: SurahHeaderLayout.medallionSize, height: SurahHeaderLayout.medallionSize)
    }
}

private enum SurahHeaderLayout {
    static let cornerRadius: CGFloat = 12
    /// Space between the outer and inner rules.
    static let ruleGap: CGFloat = 3
    /// Keeps the heading clear of the medallions.
    static let sidePadding: CGFloat = 44
    static let innerPadding: CGFloat = 4
    /// Room above and below the band, so it stands apart from the ayat.
    static let outerMargin: CGFloat = 8
    static let medallionSize: CGFloat = 22
    static let medallionInset: CGFloat = 12
}
