import SwiftUI

/// Shared rules for the Home screen's calm look: rounded display type and
/// numerals, tight tracking on big titles, open tracking on small uppercase
/// labels, and precise springs with no overshoot.
enum HomeStyle {
    /// Horizontal page margin (multiplied by `LayoutMetrics.uiScale`).
    static let pagePadding: CGFloat = 20
    /// Gap between neighbouring cards (multiplied by `LayoutMetrics.uiScale`).
    static let cardGap: CGFloat = 12
    /// Tight tracking for the big rounded titles.
    static let titleTracking: CGFloat = -0.4
    /// Open tracking for small uppercase labels.
    static let labelTracking: CGFloat = 0.8
    /// The Continue progress fill on first appear, after the screen settles.
    static let fillAnimation = Animation.spring(duration: 0.9, bounce: 0).delay(0.15)
    /// Press-down response of the tappable cards.
    static let pressAnimation = Animation.spring(duration: 0.2, bounce: 0)
    static let pressedScale: CGFloat = 0.98
    static let pressedOpacity: Double = 0.88
}

extension View {
    /// Small uppercase label with open tracking (section titles, eyebrows,
    /// stat captions). The casing also reaches the Text's own accessibility
    /// label, so a label VoiceOver reads on its own gets an outer element
    /// with the original text (see `HomeSectionLabel`).
    func homeCapsLabel() -> some View {
        textCase(.uppercase).tracking(HomeStyle.labelTracking)
    }
}

/// Press response for Home's tappable cards: a slight settle with no bounce
/// (they open Qurʼan lessons) and a selection haptic on press-down. Reduce
/// Motion keeps only the dim.
struct HomeCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HomePressedLabel(label: configuration.label, isPressed: configuration.isPressed)
    }
}

/// A real `View`, so it can read the Reduce Motion setting.
private struct HomePressedLabel: View {
    let label: ButtonStyleConfiguration.Label
    let isPressed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        label
            .scaleEffect(isPressed && !reduceMotion ? HomeStyle.pressedScale : 1)
            .opacity(isPressed ? HomeStyle.pressedOpacity : 1)
            .animation(reduceMotion ? nil : HomeStyle.pressAnimation, value: isPressed)
            .sensoryFeedback(.selection, trigger: isPressed) { _, pressed in pressed }
    }
}

/// Lets iOS 26 render a cluster of sibling glass cards in one pass. Spacing 0
/// keeps neighbouring cards from melting into each other. Below iOS 26 each
/// card keeps its own material and this is a plain passthrough.
struct HomeGlassGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 0) { content }
        } else {
            content
        }
    }
}

/// Section title such as "BOBLAR": small, uppercase, open tracking.
struct HomeSectionLabel: View {
    let text: String

    @Environment(\.layoutMetrics) private var layoutMetrics

    var body: some View {
        Text(text)
            .font(layoutMetrics.font(.footnote.weight(.semibold), .headline))
            .homeCapsLabel()
            .foregroundStyle(AppColor.textMuted)
            // An outer element, so VoiceOver gets "Boblar", not "BOBLAR".
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .accessibilityAddTraits(.isHeader)
    }
}
