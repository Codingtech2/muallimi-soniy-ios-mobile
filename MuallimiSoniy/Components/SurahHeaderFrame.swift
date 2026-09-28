import SwiftUI

extension View {
    /// Sets a surah heading in a double-ruled band with a round medallion at
    /// each end — the way a printed mushaf marks where a new surah starts — so
    /// a learner sees at a glance that the text below is a different surah.
    /// The heading itself (static or tappable) is drawn unchanged inside.
    ///
    /// `isActive` turns the whole band green, for a heading that is itself the
    /// playing element (`TitleBanner`). `compact` halves the room above and
    /// below the band, for pages that stack several framed headings.
    func surahHeaderFrame(isActive: Bool = false, compact: Bool = false) -> some View {
        modifier(SurahHeaderFrame(isActive: isActive, compact: compact))
    }
}

private struct SurahHeaderFrame: ViewModifier {
    let isActive: Bool
    let compact: Bool

    @Environment(\.readingTheme) private var readingTheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, SurahHeaderLayout.sidePadding)
            .padding(.vertical, SurahHeaderLayout.innerPadding)
            .frame(maxWidth: .infinity)
            .background(band)
            .overlay(medallions)
            .padding(.vertical, compact ? SurahHeaderLayout.compactOuterMargin : SurahHeaderLayout.outerMargin)
    }

    private var accent: Color { readingTheme.textSecondary }

    /// Light tint, a bold outer rule and a thin inner rule. While active it is
    /// one solid green band with a soft glow instead (web `surah-banner-playing`).
    private var band: some View {
        let outer = RoundedRectangle(cornerRadius: SurahHeaderLayout.cornerRadius, style: .continuous)
        let inner = RoundedRectangle(
            cornerRadius: SurahHeaderLayout.cornerRadius - SurahHeaderLayout.ruleGap,
            style: .continuous
        )
        return outer
            .fill(isActive ? AppColor.primary : accent.opacity(0.07))
            .overlay(outer.strokeBorder(isActive ? AppColor.primary : accent.opacity(0.6), lineWidth: 1.5))
            .overlay(
                inner
                    .strokeBorder(isActive ? Color.clear : accent.opacity(0.35), lineWidth: 0.75)
                    .padding(SurahHeaderLayout.ruleGap)
            )
            .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 10, x: 0, y: 6)
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
    /// surah headers. On the green active band it turns white (web rosette
    /// goes white at 0.85).
    private var medallion: some View {
        let tint = isActive ? Color.white : accent
        return ZStack {
            Circle().strokeBorder(tint.opacity(isActive ? 0.85 : 0.55), lineWidth: 1)
            Circle()
                .fill(tint.opacity(isActive ? 0.3 : 0.14))
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
    /// Half of that, for pages with several framed headings (web `my-0.5`).
    static let compactOuterMargin: CGFloat = 4
    static let medallionSize: CGFloat = 22
    static let medallionInset: CGFloat = 12
}
