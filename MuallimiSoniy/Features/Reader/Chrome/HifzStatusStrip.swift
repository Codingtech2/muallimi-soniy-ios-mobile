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
    /// "Faqat shu oyat" for an ayah-scope session on a real ayah, `nil` for
    /// surah/continuous and for the isti'adha or a bismillah.
    let badge: String?
    let isGap: Bool
    /// The running gap's total length, used only for the countdown bar.
    /// Meaningless while `isGap` is `false`.
    let gapSeconds: Double
    /// `false` while the gap's silence isn't actually playing (paused,
    /// interrupted, still loading) — the countdown holds still until it is.
    let isGapRunning: Bool
    /// `true` for sessions that pause between plays. The countdown row then
    /// keeps its space while a unit plays too, so the strip (and the page
    /// viewport above it) never changes height mid-session.
    let reservesCountdown: Bool
    let dots: DotsState?
    /// When the sleep timer ends the session, `nil` while it's off — shown as
    /// a small countdown at the end of the progress line.
    let sleepDeadline: Date?
    let isStalled: Bool
    /// What VoiceOver reads for the text lines — the same words, but with
    /// "until stopped" where the screen shows "∞".
    let accessibilityLabel: String
    let stopLabel: String
    let retryLabel: String

    struct DotsState {
        let done: Int
        let total: Int
    }
}

/// Localized wording for a running hifz session, shared by the status strip,
/// Now Playing (lock screen) and the reader's long-press menu, so they always
/// agree.
enum HifzLabels {
    /// "<surah name> · <ayah label>" for Now Playing / VoiceOver, e.g. "Ixlos · 3–4-oyat".
    static func nowPlayingTitle(unit: HifzUnit, store: ContentStore, locale: AppLocale) -> String {
        let surahName = store.hifzCatalog.surah(number: unit.surahNumber)?.name.text(locale) ?? ""
        let ayah = unitLabel(for: unit, store: store, locale: locale)
        return "\(surahName) · \(ayah)"
    }

    /// The unit's own label: bismillah / ta'awwudh, a single ayah, or a merged pair's range.
    static func unitLabel(for unit: HifzUnit, store: ContentStore, locale: AppLocale) -> String {
        switch unit.role {
        case .bismillah:
            return store.t("hifz_bismillah", locale)
        case .taawwudh:
            return store.t("hifz_taawwudh", locale)
        case .ayah:
            if let from = unit.ayahFrom, let toAyah = unit.ayahTo, toAyah != from {
                return String(format: store.t("hifz_ayah_range", locale), "\(from)", "\(toAyah)")
            }
            let ayah = unit.ayahFrom ?? unit.ayahTo ?? 0
            return String(format: store.t("hifz_ayah_label", locale), "\(ayah)")
        }
    }

    /// "Takror k/n" / "Sura r/R" progress text for Now Playing's artist field —
    /// only the dimensions the plan actually repeats (each ≠ 1, rounds ≠ 1) show.
    /// Baqara's excerpt counts rounds as "Qism r/R", never as a whole surah.
    /// `spoken` swaps "∞" for the words VoiceOver should say instead.
    static func progress(
        cursor: HifzCursor, plan: HifzPlan, store: ContentStore, locale: AppLocale, spoken: Bool = false
    ) -> String {
        let forever = spoken ? store.t("hifz_forever", locale) : "∞"
        var parts: [String] = []
        if plan.eachAyah != .times(1) {
            let total = repeatLabel(plan.eachAyah, forever: forever)
            parts.append(String(format: store.t("hifz_repeat_progress", locale), "\(cursor.playIndex + 1)", total))
        }
        if plan.rounds != .times(1) {
            let total = repeatLabel(plan.rounds, forever: forever)
            var key = "hifz_round_progress"
            if case .surah(let number) = plan.scope, store.hifzCatalog.surah(number: number)?.isPartial == true {
                key = "hifz_round_progress_excerpt"
            }
            parts.append(String(format: store.t(key, locale), "\(cursor.roundIndex + 1)", total))
        }
        return parts.joined(separator: " · ")
    }

    /// "Uyqu taymeri: 15 daq." — what VoiceOver says for the strip's sleep
    /// countdown, in whole minutes rounded up.
    static func sleepTimeLeft(until deadline: Date, store: ContentStore, locale: AppLocale) -> String {
        let minutes = HifzTiming.sleepMinutesLeft(until: deadline, now: Date())
        let value = String(format: store.t("hifz_sleep_minutes", locale), "\(minutes)")
        return "\(store.t("hifz_sleep_timer", locale)): \(value)"
    }

    private static func repeatLabel(_ value: HifzRepeat, forever: String) -> String {
        switch value {
        case .times(let count): return "\(count)"
        case .forever: return forever
        }
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

    /// Countdown time already used up in the current gap, not counting the
    /// stretch running right now. Reset every time a new gap begins, so the
    /// bar always starts full.
    @State private var gapElapsed: TimeInterval = 0
    /// When the current running stretch of the gap began; `nil` while the
    /// countdown is held (audio paused or not started yet).
    @State private var gapRunningSince: Date?

    private static let minHeight: CGFloat = 56
    private static let controlDiameter: CGFloat = 48
    private static let dotDiameter: CGFloat = 8
    private static let countdownHeight: CGFloat = 5

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
            // Under Reduce Motion the bar never shows, so there's nothing to reserve.
            if state.reservesCountdown, !reduceMotion {
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
        .onAppear {
            if state.isGap { restartCountdown() }
        }
        .onChange(of: state.isGap) { wasGap, isGap in
            if isGap, !wasGap {
                restartCountdown()
            }
        }
        .onChange(of: state.isGapRunning) { _, isRunning in
            if isRunning {
                if state.isGap, gapRunningSince == nil { gapRunningSince = Date() }
            } else if let since = gapRunningSince {
                gapElapsed += Date().timeIntervalSince(since)
                gapRunningSince = nil
            }
        }
    }

    private func restartCountdown() {
        gapElapsed = 0
        gapRunningSince = state.isGapRunning ? Date() : nil
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
                // In a session with pauses the gap always fills this line, so an
                // empty one still keeps its height rather than growing the strip.
                if !state.detail.isEmpty || state.reservesCountdown {
                    Text(state.detail.isEmpty ? " " : state.detail)
                        .font(layoutMetrics.font(.caption, .subheadline))
                        .foregroundStyle(readingTheme.textMuted)
                        .lineLimit(1)
                }
                if let dots = state.dots {
                    dotsView(dots)
                }
                if let deadline = state.sleepDeadline {
                    sleepCountdown(until: deadline)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityAddTraits(.updatesFrequently)
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

    /// Moon + time left ("14:32"), counting down on its own and stopping at
    /// 0:00 while the last unit plays out. VoiceOver hears it through the
    /// caller's `accessibilityLabel` instead.
    private func sleepCountdown(until deadline: Date) -> some View {
        HStack(spacing: 3 * layoutMetrics.uiScale) {
            Image(systemName: "moon.zzz.fill")
            Text(timerInterval: min(Date(), deadline)...deadline, countsDown: true, showsHours: false)
                .monospacedDigit()
        }
        .font(layoutMetrics.font(.caption, .subheadline))
        .foregroundStyle(readingTheme.textMuted)
        .lineLimit(1)
        .fixedSize()
    }

    // MARK: - Gap countdown

    /// A slim bar draining from full to empty over `gapSeconds`, holding
    /// still whenever the gap's silence is paused. Its row is always laid out
    /// (empty while a unit plays) so the strip keeps one height. Purely
    /// decorative, so it's skipped entirely under Reduce Motion (the caller
    /// doesn't lay the row out then) rather than swapped for a static
    /// equivalent.
    private var gapProgress: some View {
        Group {
            if state.isGap, state.gapSeconds > 0 {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: gapRunningSince == nil)) { context in
                    let remaining = remainingGapFraction(at: context.date)
                    GeometryReader { geo in
                        Capsule()
                            .fill(readingTheme.textSecondary.opacity(0.2))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(readingTheme.textSecondary)
                                    .frame(width: geo.size.width * remaining)
                            }
                    }
                }
            } else {
                Color.clear
            }
        }
        .frame(height: Self.countdownHeight * layoutMetrics.uiScale)
        .accessibilityHidden(true)
    }

    private func remainingGapFraction(at date: Date) -> Double {
        let running = gapRunningSince.map { max(date.timeIntervalSince($0), 0) } ?? 0
        let elapsed = gapElapsed + running
        return 1 - min(max(elapsed / state.gapSeconds, 0), 1)
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
                isGapRunning: false,
                reservesCountdown: true,
                dots: HifzStripState.DotsState(done: 2, total: 5),
                sleepDeadline: Date(timeIntervalSinceNow: 14 * 60),
                isStalled: false,
                accessibilityLabel: "Ixlos · 3-oyat, Faqat shu oyat, Takror 2/5",
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
