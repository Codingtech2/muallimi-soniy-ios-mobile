import SwiftUI

// The mosques screen's buttons: one green call-to-action look, the label
// styles two side-by-side buttons share, and the row that keeps them equal.

/// The panel's one full-width green button (find nearest, open Settings, retry).
struct MosquePanelButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MosqueActionLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(MosqueActionButtonStyle(prominent: true))
    }
}

/// The panel's call-to-action look: a filled green button with a white label
/// (readable in both themes), or a quiet green-tinted one. At least 50 pt
/// tall; `stretch` lets two buttons in a fixed-height row match the taller one.
struct MosqueActionLook: ViewModifier {
    let prominent: Bool
    var stretch = false

    @Environment(\.layoutMetrics) private var layoutMetrics

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16 * layoutMetrics.uiScale, style: .continuous)
        content
            .font(layoutMetrics.font(.headline, .title3.weight(.semibold)))
            .foregroundStyle(prominent ? Color.white : AppColor.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14 * layoutMetrics.uiScale)
            .padding(.vertical, 10 * layoutMetrics.uiScale)
            .frame(maxWidth: .infinity, minHeight: 50 * layoutMetrics.uiScale, maxHeight: stretch ? .infinity : nil)
            .background(prominent ? AppColor.primaryButton : AppColor.primary.opacity(0.15), in: shape)
            .contentShape(shape)
    }
}

/// `MosqueActionLook` plus a short settle while pressed (dim only under
/// Reduce Motion) and a faded look while disabled.
struct MosqueActionButtonStyle: ButtonStyle {
    let prominent: Bool
    var stretch = false

    func makeBody(configuration: Configuration) -> some View {
        MosquePressable(isPressed: configuration.isPressed) {
            configuration.label.modifier(MosqueActionLook(prominent: prominent, stretch: stretch))
        }
    }
}

/// Icon and title on one line when they fit; else the title alone on one
/// line; else the title wrapped — so a narrow half-width button never ends
/// up with a lone word under its icon.
struct MosqueActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
            Text(title)
                .lineLimit(1)
            Text(title)
        }
    }
}

/// A button label in one of the looks two side-by-side buttons share, so
/// they always match: both with their icon, both without, both a step
/// smaller, or both wrapped. `automatic` lets a full-width button decide
/// alone (`MosqueActionLabel`).
struct MosqueButtonLabel: View {
    enum Style {
        case icon
        case plain
        /// One line, a text style smaller (about 0.88 of the size) — a
        /// shrink `ViewThatFits` can measure, unlike `minimumScaleFactor`.
        case compact
        /// Last resort: shrinks a little, then wraps.
        case wrapped
        case automatic
    }

    let title: String
    let systemImage: String
    let style: Style

    @Environment(\.layoutMetrics) private var layoutMetrics

    private static let shrink: CGFloat = 0.85

    var body: some View {
        switch style {
        case .icon:
            Label(title, systemImage: systemImage)
                .lineLimit(1)
        case .plain:
            Text(title)
                .lineLimit(1)
        case .compact:
            Text(title)
                .lineLimit(1)
                .font(layoutMetrics.font(.subheadline.weight(.semibold), .body.weight(.semibold)))
        case .wrapped:
            Text(title)
                .lineLimit(2)
                .minimumScaleFactor(Self.shrink)
        case .automatic:
            MosqueActionLabel(title: title, systemImage: systemImage)
        }
    }
}

/// Buttons side by side at one equal width. Its ideal width is the widest
/// label times the count, so `ViewThatFits` only picks a row in which every
/// label really fits its half (a plain HStack would add the two widths up).
struct MosqueEqualWidthRow: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let gaps = spacing * CGFloat(subviews.count - 1)
        guard let width = proposal.width else {
            let ideal = subviews.map { $0.sizeThatFits(.unspecified) }
            let widest = ideal.map(\.width).max() ?? 0
            return CGSize(width: widest * CGFloat(subviews.count) + gaps, height: ideal.map(\.height).max() ?? 0)
        }
        let each = max((width - gaps) / CGFloat(subviews.count), 0)
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: each, height: proposal.height)).height }
        return CGSize(width: width, height: heights.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let gaps = spacing * CGFloat(subviews.count - 1)
        let each = max((bounds.width - gaps) / CGFloat(subviews.count), 0)
        var left = bounds.minX
        for subview in subviews {
            subview.place(
                at: CGPoint(x: left, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: each, height: bounds.height)
            )
            left += each + spacing
        }
    }
}

/// Plain rows (nearest list, search results): dim while pressed.
struct MosqueRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// A real `View`, so the press effect can read Reduce Motion and enabled state.
private struct MosquePressable<Content: View>: View {
    let isPressed: Bool
    @ViewBuilder let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(isEnabled ? (isPressed ? 0.85 : 1) : 0.55)
            .animation(reduceMotion ? nil : .spring(duration: 0.2, bounce: 0), value: isPressed)
    }
}
