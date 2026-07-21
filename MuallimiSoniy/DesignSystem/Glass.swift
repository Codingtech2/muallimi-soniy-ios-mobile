import SwiftUI

/// Reusable "Liquid Glass" surface for the app's cards and buttons.
///
/// One call site, two renderings:
/// - **iOS 26+** uses the system `glassEffect(_:in:)` — real Liquid Glass with
///   live refraction and specular highlights.
/// - **iOS 17–25** falls back to an `.ultraThinMaterial` fill plus a hairline
///   `AppColor.divider` stroke, which reads as a clean frosted card.
///
/// The green accent stays on the *label* (callers apply `.tint` / foreground);
/// the glass is a neutral surface, matching the light-default theme.

// MARK: - Glass card

extension View {
    /// Wraps the view in a rounded-rectangle glass card. `cornerRadius` drives a
    /// `.continuous` rounded rect (Liquid Glass on iOS 26, material below).
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}

/// The availability split behind `glassCard`. Kept as a `ViewModifier` so the
/// two branches erase to a single `some View` via `@ViewBuilder`.
private struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(AppColor.divider, lineWidth: 0.5))
        }
    }
}

// MARK: - Glass button style

/// A tappable glass surface: the same Liquid-Glass-or-material background as
/// `glassCard`, plus a subtle scale-down while pressed. Use via
/// `.buttonStyle(GlassButtonStyle())` (optionally with a custom `cornerRadius`).
struct GlassButtonStyle: ButtonStyle {
    /// Corner radius of the glass pill/card behind the label. Defaults to a
    /// button-scale 16 (cards use 20).
    var cornerRadius: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.65),
                       value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
