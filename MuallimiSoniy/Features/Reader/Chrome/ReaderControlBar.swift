import SwiftUI

/// The reader's one bottom control bar — replaces the two stacked bars
/// (`ReaderPageIndicator` + `AudioControls`) that together ate up to 19.5% of
/// the screen.
///
/// It is attached with `.safeAreaInset(edge: .bottom)`, which is structural
/// rather than cosmetic: as a safe-area inset the pager keeps its full height
/// and every per-page scroll view inherits a matching bottom content inset for
/// free, so the last verse can always be scrolled clear of the bar instead of
/// being sheared by a square edge.
///
/// Layout, left to right (chrome stays LTR even though the content is RTL):
/// `‹ page | ⏮ ▶︎ ⏭ | ⟲ | page ›`. Everything is always present at a fixed
/// height — a page without audio renders the transport and loop *disabled*
/// rather than removing them, because removing them would change the bar's
/// height between pages and slide the page chevrons out from under the user's
/// thumb mid-swipe.
///
/// Every colour comes from `\.readingTheme`, never `AppColor` or a system
/// material: three of the four reading backgrounds are fixed palettes, so a
/// material (which follows the *system* appearance) put e.g. night-under-light
/// at ≈2.27:1 contrast.
struct ReaderControlBar: View {
    @Environment(AudioController.self) private var audio
    @Environment(\.layoutMetrics) private var layoutMetrics
    @Environment(\.readingTheme) private var readingTheme
    /// Lets the glyphs grow with Dynamic Type *inside* their fixed circles.
    /// The circles themselves stay put: at 402pt of phone width the row of
    /// buttons already leaves only ~38pt of slack, so scaling the hit targets
    /// would overflow the bar long before it helped anyone.
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    /// `false` when the page carries no audio at all in the data.
    let hasAudio: Bool
    let canGoPrevPage: Bool
    let canGoNextPage: Bool
    let loopOn: Bool

    let prevPageLabel: String
    let nextPageLabel: String
    let prevElementLabel: String
    let nextElementLabel: String
    let playLabel: String
    let pauseLabel: String
    let loopLabel: String

    let onPrevPage: () -> Void
    let onNextPage: () -> Void
    let onPrevElement: () -> Void
    let onNextElement: () -> Void
    let onPlayPause: () -> Void
    let onToggleLoop: () -> Void

    // MARK: - Tokens

    private var barHeight: CGFloat { layoutMetrics.controlBarHeight }
    private var primaryDiameter: CGFloat { layoutMetrics.controlBarPrimaryDiameter }
    private var secondaryDiameter: CGFloat { layoutMetrics.controlBarSecondaryDiameter }
    private var transportSpacing: CGFloat { layoutMetrics.isRegular ? 13 : 10 }
    private var groupSpacing: CGFloat { layoutMetrics.isRegular ? 16 : 12 }
    private var sideMargin: CGFloat { layoutMetrics.isRegular ? 32 : 16 }
    private var progressHeight: CGFloat { layoutMetrics.isRegular ? 4 : 3 }
    private var loopCornerRadius: CGFloat { layoutMetrics.isRegular ? 14 : 12 }

    /// Base glyph sizes, grown by Dynamic Type but capped at a share of their
    /// circle so a glyph can never spill past the button that carries it.
    private var primaryGlyphSize: CGFloat {
        min((layoutMetrics.isRegular ? 31 : 24) * typeScale, primaryDiameter * Self.glyphFillRatio)
    }

    private var secondaryGlyphSize: CGFloat {
        min((layoutMetrics.isRegular ? 26 : 20) * typeScale, secondaryDiameter * Self.glyphFillRatio)
    }

    private static let glyphFillRatio: CGFloat = 0.62
    private static let disabledOpacity: CGFloat = 0.38
    private static let hairline: CGFloat = 0.5
    private static let loopFillOpacity: CGFloat = 0.20

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            pageButton("chevron.backward", label: prevPageLabel, enabled: canGoPrevPage, action: onPrevPage)
            Spacer(minLength: groupSpacing)
            transportGroup
            Spacer(minLength: groupSpacing)
            loopButton
            Spacer(minLength: groupSpacing)
            pageButton("chevron.forward", label: nextPageLabel, enabled: canGoNextPage, action: onNextPage)
        }
        .padding(.horizontal, sideMargin)
        .frame(height: barHeight)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) { topEdge }
        // Opaque page fill, full bleed, extending behind the home indicator —
        // only the *content* above is inset by the bottom safe area.
        .background(readingTheme.pageFill.ignoresSafeArea(edges: .bottom))
    }

    /// Hairline separator plus, flush on top of it, the non-interactive audio
    /// progress line. Segments run 1–3 seconds, so there is nothing to scrub —
    /// this is a read-out, not a control.
    private var topEdge: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(readingTheme.divider)
                .frame(height: Self.hairline)
            if audio.duration > 0 {
                progressLine
            }
            Spacer(minLength: 0)
        }
        .accessibilityHidden(true)
    }

    private var progressLine: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(readingTheme.textSecondary)
                .frame(width: geo.size.width * playbackFraction)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: progressHeight)
    }

    private var playbackFraction: CGFloat {
        guard audio.duration > 0, audio.currentTime.isFinite else { return 0 }
        return min(max(CGFloat(audio.currentTime / audio.duration), 0), 1)
    }

    // MARK: - Groups

    private var transportGroup: some View {
        HStack(spacing: transportSpacing) {
            skipButton("backward.end.fill", label: prevElementLabel, action: onPrevElement)
            playPauseButton
            skipButton("forward.end.fill", label: nextElementLabel, action: onNextElement)
        }
        .disabled(!hasAudio)
        .opacity(hasAudio ? 1 : Self.disabledOpacity)
    }

    private var playPauseButton: some View {
        Button(action: onPlayPause) {
            Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: primaryGlyphSize, weight: .semibold))
                // The page fill reads as white on paper / sepia / gray and as
                // near-black on night, so the glyph always inverts against the
                // accent circle instead of washing out on the light-green
                // night accent.
                .foregroundStyle(readingTheme.pageFill)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: primaryDiameter, height: primaryDiameter)
                .background(readingTheme.textSecondary, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(audio.isPlaying ? pauseLabel : playLabel)
    }

    private var loopButton: some View {
        Button(action: onToggleLoop) {
            Image(systemName: "repeat")
                .font(.system(size: secondaryGlyphSize, weight: .medium))
                .foregroundStyle(loopOn ? readingTheme.textSecondary : readingTheme.textMuted)
                .frame(width: secondaryDiameter, height: secondaryDiameter)
                .background(loopShape.fill(loopOn ? readingTheme.textSecondary.opacity(Self.loopFillOpacity) : .clear))
                .contentShape(loopShape)
        }
        .buttonStyle(.plain)
        .disabled(!hasAudio)
        .opacity(hasAudio ? 1 : Self.disabledOpacity)
        .accessibilityLabel(loopLabel)
        .accessibilityAddTraits(loopOn ? .isSelected : [])
    }

    private var loopShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: loopCornerRadius, style: .continuous)
    }

    // MARK: - Buttons

    private func skipButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: secondaryGlyphSize, weight: .medium))
                .foregroundStyle(readingTheme.textSecondary)
                .frame(width: secondaryDiameter, height: secondaryDiameter)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func pageButton(
        _ symbol: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: secondaryGlyphSize, weight: .semibold))
                .foregroundStyle(readingTheme.textMain)
                .frame(width: secondaryDiameter, height: secondaryDiameter)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : Self.disabledOpacity)
        .accessibilityLabel(label)
    }
}

#if DEBUG
#Preview("ReaderControlBar") {
    VStack(spacing: 0) {
        Color.clear
        ReaderControlBar(
            hasAudio: true,
            canGoPrevPage: true,
            canGoNextPage: true,
            loopOn: true,
            prevPageLabel: "Oldingi sahifa",
            nextPageLabel: "Keyingi sahifa",
            prevElementLabel: "Oldingi element",
            nextElementLabel: "Keyingi element",
            playLabel: "Ijro",
            pauseLabel: "Toʻxtatish",
            loopLabel: "Takror",
            onPrevPage: {},
            onNextPage: {},
            onPrevElement: {},
            onNextElement: {},
            onPlayPause: {},
            onToggleLoop: {}
        )
    }
    .background(ReadingBackground.sepia.pageFill)
    .environment(AudioController())
    .environment(\.readingTheme, .sepia)
}
#endif
