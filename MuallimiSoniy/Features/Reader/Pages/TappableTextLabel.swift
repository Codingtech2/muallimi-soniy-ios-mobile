import SwiftUI

/// A tappable Arabic **text** label with the shared active-highlight treatment —
/// a solid primary-green pill with white glyphs when selected, otherwise clear
/// with the given inactive colour. Ports the web page-local clickable narration
/// buttons (`BlockTitle` / `ClickableSubText` on page 28, the `SectionTitle`
/// narration on page 29) which render whole sentences rather than single tokens,
/// so they can't use the token-sized `ArabicElementView`.
///
/// Sizing mirrors the web: when `fullWidth` is false the pill hugs short text and
/// fills the column only when the sentence wraps (natural `Text` behaviour);
/// `fullWidth` forces edge-to-edge for the web `w-full` titles. Per the project
/// rule, an inactive label is **never dimmed**. Renders nothing when `element` is
/// nil (an unported suffix), mirroring the web `if (!el) return null`.
struct TappableTextLabel: View {
    let element: Element?
    let font: Font
    var inactiveColor: Color = AppColor.textMuted
    /// Web `box-shadow` blur ≈ 2× this radius; only shown while active.
    var glowRadius: CGFloat = 10
    var glowY: CGFloat = 6
    /// Web `px-*` (12 == px-3, 8 == px-2).
    var horizontalPadding: CGFloat = 8
    /// Web `w-full` — force the pill to span the reading column.
    var fullWidth: Bool = false
    let activeId: String?
    let onTap: (Element) -> Void

    /// Line spacing / bold / highlight / VoiceOver strings from the "Aa" sheet.
    @Environment(\.readingAdjustments) private var adjustments
    /// Settings → Accessibility → Reduce Motion — skips the highlight spring.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let element {
            let isActive = activeId == element.id
            Button { onTap(element) } label: {
                Text(element.arabic)
                    .font(font)
                    .foregroundStyle(isActive ? Color.white : inactiveColor)
                    .multilineTextAlignment(.center)   // text-center
                    .lineSpacing(1 * adjustments.lineSpacingScale)  // leading-tight
                    .frame(maxWidth: fullWidth ? .infinity : nil)
                    .padding(.horizontal, horizontalPadding)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)   // rounded-md
                            .fill(isActive ? AppColor.primary : Color.clear)
                    )
                    .shadow(color: isActive ? AppColor.primaryGlow : .clear,
                            radius: glowRadius, x: 0, y: isActive ? glowY : 0)
            }
            .buttonStyle(.plain)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.62), value: isActive)
            .accessibilityLabel(element.accessibilityLabelText)
            .accessibilityHint(adjustments.playHint)
            .accessibilityAddTraits(isActive ? [.startsMediaSession, .isSelected] : .startsMediaSession)
            .accessibilityValue(isActive ? adjustments.activeValueLabel : "")
        }
    }
}
