import SwiftUI
import Foundation

/// One rendered snapshot of an active hifz (memorization) session — every
/// string already localized by the caller (`ReaderView`), so `HifzStatusStrip`
/// stays a pure function of its input, the same contract `ReaderControlBar`
/// already follows for its own labels.
struct HifzStripState {
    /// Large line: the current unit ("Ixlos · 3-oyat") while playing, or the
    /// "your turn" prompt while `isGap` is true.
    let title: String
    /// Small line: repeat/round progress while playing, or the current
    /// unit's own label while `isGap` is true (kept visible as context under
    /// the prompt).
    let detail: String
    /// "Faqat shu oyat" for an ayah-scope session, `nil` for surah/continuous.
    let badge: String?
    let isGap: Bool
    /// The running gap's total length, used only for the countdown bar.
    /// Meaningless while `isGap` is `false`.
    let gapSeconds: Double
    let dots: DotsState?
    let isStalled: Bool
    let stopLabel: String
    let retryLabel: String

    struct DotsState {
        let done: Int
        let total: Int
    }
}

/// Sits directly above `ReaderControlBar` inside the reader's bottom
/// `.safeAreaInset`, visible only while a hifz session is active. Every
/// colour comes from `\.readingTheme` — the same rule the control bar below
/// it follows, since three of the four reading backgrounds are fixed
/// palettes that a system material would render at the wrong contrast.
struct HifzStatusStrip: View {
    let state: HifzStripState
    let onStop: () -> Void
    let onRetry: () -> Void

    @Environment(\.readingTheme) private var readingTheme
    @Environment(\.layoutMetrics) private var layoutMetrics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Reset every time a new gap begins (`onChange(of: state.isGap)`) so the
    /// countdown bar in `gapProgress` always starts full.
    @State private var gapStartedAt = Date()

    private static let minHeight: CGFloat = 56
    private static let controlDiameter: CGFloat = 48
    private static let dotDiameter: CGFloat = 8

    var body: some View {
        VStack(spacing: 6 * layoutMetrics.uiScale) {
            HStack(spacing: 12 * layoutMetrics.uiScale) {
                textColumn
                Spacer(minLength: 8)
                if state.isStalled {
                    controlButton(systemImage: "arrow.clockwise", label: state.retryLabel, action: onRetry)
                }
                controlButton(systemImage: "stop.fill", label: state.stopLabel, action: onStop)
            }
            if state.isGap {
                gapProgress
            }
        }
        .padding(.horizontal, 16 * layoutMetrics.uiScale)
        .padding(.vertical, 10 * layoutMetrics.uiScale)
        .frame(minHeight: Self.minHeight * layoutMetrics.uiScale)
        .frame(maxWidth: .infinity)
        // `cardFill` is translucent glass on the paper background, and the page
        // scrolls underneath this inset — so it sits on an opaque page fill,
        // same as the control bar, or ayat would show through the strip.
        .background(readingTheme.cardFill)
        .background(readingTheme.pageFill)
        .overlay(alignment: .top) {
            Rectangle().fill(readingTheme.divider).frame(height: 0.5)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .onChange(of: state.isGap) { wasGap, isGap in
            if isGap, !wasGap {
                gapStartedAt = Date()
            }
        }
    }

    // MARK: - Text

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 3 * layoutMetrics.uiScale) {
            HStack(spacing: 8 * layoutMetrics.uiScale) {
                Text(state.title)
                    .font(layoutMetrics.font(.subheadline.weight(.bold), .title3.weight(.bold)))
                    .foregroundStyle(state.isGap ? readingTheme.textSecondary : readingTheme.textMain)
                    .lineLimit(1)
                if let badge = state.badge {
                    badgeView(badge)
                }
            }
            HStack(spacing: 8 * layoutMetrics.uiScale) {
                if !state.detail.isEmpty {
                    Text(state.detail)
                        .font(layoutMetrics.font(.caption, .subheadline))
                        .foregroundStyle(readingTheme.textMuted)
                        .lineLimit(1)
                }
                if let dots = state.dots {
                    dotsView(dots)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func badgeView(_ text: String) -> some View {
        Text(text)
            .font(layoutMetrics.font(.caption2.weight(.semibold), .caption.weight(.semibold)))
            .foregroundStyle(readingTheme.textSecondary)
            .padding(.horizontal, 8 * layoutMetrics.uiScale)
            .padding(.vertical, 3 * layoutMetrics.uiScale)
            .background(Capsule().fill(readingTheme.textSecondary.opacity(0.15)))
    }

    private func dotsView(_ dots: HifzStripState.DotsState) -> some View {
        HStack(spacing: 4 * layoutMetrics.uiScale) {
            ForEach(0..<dots.total, id: \.self) { index in
                Circle()
                    .fill(index < dots.done ? readingTheme.textSecondary : readingTheme.textSecondary.opacity(0.25))
                    .frame(
                        width: Self.dotDiameter * layoutMetrics.uiScale,
                        height: Self.dotDiameter * layoutMetrics.uiScale
                    )
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Gap countdown

    /// A slim bar draining from full to empty over `gapSeconds` — purely
    /// decorative, so it's skipped entirely under Reduce Motion rather than
    /// swapped for a static equivalent.
    @ViewBuilder
    private var gapProgress: some View {
        if !reduceMotion, state.gapSeconds > 0 {
            TimelineView(.periodic(from: gapStartedAt, by: 1.0 / 30.0)) { context in
                let elapsed = context.date.timeIntervalSince(gapStartedAt)
                let remaining = 1 - min(max(elapsed / state.gapSeconds, 0), 1)
                GeometryReader { geo in
                    Capsule()
                        .fill(readingTheme.textSecondary.opacity(0.2))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(readingTheme.textSecondary)
                                .frame(width: geo.size.width * remaining)
                        }
                }
                .frame(height: 5 * layoutMetrics.uiScale)
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - Controls

    private func controlButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18 * layoutMetrics.uiScale, weight: .semibold))
                .foregroundStyle(readingTheme.textSecondary)
                .frame(
                    width: Self.controlDiameter * layoutMetrics.uiScale,
                    height: Self.controlDiameter * layoutMetrics.uiScale
                )
                .background(Circle().fill(readingTheme.textMuted.opacity(0.15)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#if DEBUG
#Preview("HifzStatusStrip") {
    VStack(spacing: 0) {
        Color.clear
        HifzStatusStrip(
            state: HifzStripState(
                title: "Ixlos · 3-oyat",
                detail: "Takror 2/5",
                badge: "Faqat shu oyat",
                isGap: false,
                gapSeconds: 4,
                dots: HifzStripState.DotsState(done: 2, total: 5),
                isStalled: false,
                stopLabel: "Yodlashni toʻxtatish",
                retryLabel: "Ijro"
            ),
            onStop: {},
            onRetry: {}
        )
    }
    .background(ReadingBackground.night.pageFill)
    .environment(\.readingTheme, .night)
}
#endif
