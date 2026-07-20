import SwiftUI

/// Wraps a single page's rendered content in the reader's light card surface —
/// the native analogue of the web page card (rounded, glass fill, hairline
/// border). The dispatcher decides *what* renders; this view owns the chrome.
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
    }
}
