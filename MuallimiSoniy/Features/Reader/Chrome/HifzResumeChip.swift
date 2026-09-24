import SwiftUI
import UIKit
import OSLog

/// Where a hifz session stood when the user broke it off by accident (a
/// swipe, a tap on another element, a jump) — enough to start the very same
/// plan again from the listen it stopped on.
struct HifzResumeOffer: Identifiable {
    let id = UUID()
    let plan: HifzPlan
    let cursor: HifzCursor
    let unit: HifzUnit

    /// Captures where `hifz` is right now, or `nil` when no session is running.
    init?(interrupting hifz: HifzController) {
        guard hifz.isActive, let plan = hifz.plan, let cursor = hifz.cursor, let unit = hifz.currentUnit else {
            return nil
        }
        // A resumed session goes on with the sleep time it had left, rather
        // than starting the timer over.
        var resumePlan = plan
        if let deadline = hifz.sleepDeadline {
            resumePlan.sleepAfter = HifzTiming.sleepTimeLeft(until: deadline, now: Date())
        }
        self.plan = resumePlan
        self.cursor = cursor
        self.unit = unit
    }
}

extension View {
    /// Floats a short-lived "resume" chip along the bottom edge while `offer`
    /// is set, then clears `offer` again once its few seconds are up.
    func hifzResumeChip(
        offer: Binding<HifzResumeOffer?>,
        title: String,
        detail: @escaping (HifzUnit) -> String,
        onResume: @escaping (HifzResumeOffer) -> Void
    ) -> some View {
        modifier(HifzResumeChipPresenter(offer: offer, title: title, detail: detail, onResume: onResume))
    }
}

/// Shows, times out and animates the chip. The overlay never changes the
/// layout under it, so the page keeps its size while the chip comes and goes.
private struct HifzResumeChipPresenter: ViewModifier {
    @Binding var offer: HifzResumeOffer?
    let title: String
    let detail: (HifzUnit) -> String
    let onResume: (HifzResumeOffer) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.layoutMetrics) private var layoutMetrics

    /// How long the chip stays up. VoiceOver users get longer: they reach it
    /// by moving through the page element by element, not at a glance.
    private static let visibleSeconds: Double = 5
    private static let voiceOverVisibleSeconds: Double = 15
    /// Gap between the chip and the bar under it.
    private static let bottomGap: CGFloat = 12
    private static let fadeSeconds: Double = 0.2

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy",
        category: "Hifz"
    )

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            ZStack {
                if let current = offer {
                    let spokenDetail = detail(current.unit)
                    HifzResumeChip(title: title, detail: spokenDetail) {
                        Self.logger.info("hifz resume unit=\(current.unit.id, privacy: .public)")
                        onResume(current)
                    }
                    .padding(.bottom, Self.bottomGap * layoutMetrics.uiScale)
                    .id(current.id)
                    // Reduce Motion: a plain fade instead of sliding up.
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .task(id: current.id) { await expire(current, spokenDetail: spokenDetail) }
                }
            }
            // Scoped to the chip alone, so nothing on the page animates with it.
            .animation(reduceMotion ? .easeInOut(duration: Self.fadeSeconds) : .snappy, value: offer?.id)
        }
    }

    /// Keeps the chip up for its time, then hides it — unless it was already
    /// used, replaced or dismissed (the task is cancelled with the chip).
    private func expire(_ current: HifzResumeOffer, spokenDetail: String) async {
        Self.logger.info("hifz resume offered unit=\(current.unit.id, privacy: .public)")
        if voiceOverEnabled {
            UIAccessibility.post(notification: .announcement, argument: "\(title), \(spokenDetail)")
        }
        let seconds = voiceOverEnabled ? Self.voiceOverVisibleSeconds : Self.visibleSeconds
        try? await Task.sleep(for: .seconds(seconds))
        guard !Task.isCancelled, offer?.id == current.id else { return }
        Self.logger.info("hifz resume offer expired")
        offer = nil
    }
}

/// The pill itself: ▶ plus "Resume", in the same inverted accent as the
/// reader's ▶ button, so it reads as "play" on every reading background.
struct HifzResumeChip: View {
    let title: String
    /// What resumes ("Ixlos · 3-oyat") — VoiceOver reads it after the title.
    let detail: String
    let onResume: () -> Void

    @Environment(\.readingTheme) private var readingTheme
    @Environment(\.layoutMetrics) private var layoutMetrics

    private static let minHeight: CGFloat = 44
    private static let horizontalPadding: CGFloat = 18
    private static let iconSpacing: CGFloat = 8
    private static let shadowOpacity: Double = 0.18
    private static let shadowRadius: CGFloat = 8
    private static let shadowOffsetY: CGFloat = 2

    var body: some View {
        Button(action: onResume) {
            HStack(spacing: Self.iconSpacing * layoutMetrics.uiScale) {
                Image(systemName: "play.fill")
                    .accessibilityHidden(true)
                Text(title)
                    .lineLimit(1)
            }
            .font(layoutMetrics.font(.subheadline.weight(.semibold), .title3.weight(.semibold)))
            .foregroundStyle(readingTheme.pageFill)
            .padding(.horizontal, Self.horizontalPadding * layoutMetrics.uiScale)
            .frame(minHeight: Self.minHeight * layoutMetrics.uiScale)
            .background(readingTheme.textSecondary, in: Capsule())
            // Floats over page text, so it needs a little lift to read as a control.
            .shadow(color: .black.opacity(Self.shadowOpacity), radius: Self.shadowRadius, y: Self.shadowOffsetY)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .accessibilityLabel(title)
        .accessibilityValue(detail)
    }
}

#if DEBUG
#Preview("HifzResumeChip") {
    VStack {
        Spacer()
        HifzResumeChip(title: "Davom ettirish", detail: "Ixlos · 3-oyat", onResume: {})
    }
    .padding()
    .background(ReadingBackground.sepia.pageFill)
    .environment(\.readingTheme, .sepia)
}
#endif
