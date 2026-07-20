import SwiftUI

/// A tappable chig'atoy narration / rule banner — a full-width, green-tinted
/// rounded card that plays its element's audio and highlights when active.
///
/// Shared by the vasl / vaqf pages whose web markup is identical:
/// `w-full rounded-lg border border-primary/15 px-2.5 py-1.5` with a centred
/// `arabic-text` paragraph (bg `rgba(76,175,80,0.04)`, active → primary fill +
/// white glyph + green glow). Call sites: page 30 `top_header` & `vasl_rule`,
/// page 31 `definition`. Renders nothing when the element is absent (unported).
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` (`Page30`, `Page31`).
struct NarrationBanner: View {
    let rule: Element?
    /// Web `text-[…rem]` for the body: 10.5 pt (top_header / definition) or
    /// 10 pt (vasl_rule).
    var fontSize: CGFloat = 10.5
    let activeId: String?
    let onTap: (Element) -> Void

    private var isActive: Bool { rule.map { activeId == $0.id } ?? false }

    var body: some View {
        if let rule {
            Button { onTap(rule) } label: { card(rule.arabic) }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
        }
    }

    private func card(_ text: String) -> some View {
        Text(text)
            .font(arabicFont(fontSize, weight: .regular))
            .foregroundStyle(isActive ? Color.white : AppColor.textMain)
            .lineSpacing(2)                       // leading-snug
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)             // px-2.5
            .padding(.vertical, 6)                // py-1.5
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)   // rounded-lg
                    .fill(isActive ? AppColor.primary : AppColor.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)   // border-primary/15
                    .strokeBorder(AppColor.primary.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 12, x: 0, y: 7)
            .environment(\.layoutDirection, .rightToLeft)
    }
}
