import SwiftUI

/// Wraps a single page's rendered content in the reader's light card surface —
/// the native analogue of the web page card (rounded, hairline border). The fill
/// is kept **near-opaque on purpose** (`AppColor.glass`) so the Arabic text stays
/// high-contrast — the reading content must never sit behind heavy translucent
/// glass, even as the surrounding chrome bars go frosted. The dispatcher decides
/// *what* renders; this view owns the chrome.
struct PageHostView: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    /// `rounded-[28px]` card radius (matches the app's card language).
    private let cornerRadius: CGFloat = 28

    var body: some View {
        PageDispatcher.view(for: page, activeId: activeId, onTap: onTap)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(16)
            .background(
                AppColor.glass,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppColor.divider, lineWidth: 1)
            )
            // Soft lift so the readable page card floats above the glass chrome.
            // The fill stays near-opaque, so text contrast is unaffected.
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}
