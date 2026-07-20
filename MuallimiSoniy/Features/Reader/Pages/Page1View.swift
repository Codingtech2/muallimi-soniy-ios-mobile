import SwiftUI

/// Bespoke 1:1 renderer for the MUQADDIMA read-along (book page 1) — a tappable
/// Bismillah at the top, a "MUQADDIMA" heading, then the nine intro prose
/// paragraphs as static, non-tappable text. Ports the web `Page1`.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page1`.
/// The prose lives outside the element structure, so it is read from the shared
/// `ContentStore.muqaddimaParagraphs` (same environment access as Page3/Page4).
/// The Bismillah uses the amber `jumla` accent when active (its element type),
/// so it carries its own button look rather than the green `ArabicElementView`.
struct Page1View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    @Environment(ContentStore.self) private var store

    var body: some View {
        let c = PageContent(elements: page.elements)
        VStack(alignment: .leading, spacing: 16) {  // gap-4
            if let bismillah = c.el("000") {
                BismillahButton(element: bismillah, isActive: activeId == bismillah.id) {
                    onTap(bismillah)
                }
                .frame(maxWidth: .infinity)  // mx-auto
            }
            Text("MUQADDIMA")
                .font(.system(size: 18, weight: .bold))  // text-lg
                .foregroundStyle(AppColor.textSecondary)
                .frame(maxWidth: .infinity)  // text-center
                .padding(.bottom, 8)         // mb-2
            ParagraphList(paragraphs: store.muqaddimaParagraphs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Bismillah

/// The tappable Bismillah. Active: amber glyph on a faint amber wash with a 2 pt
/// amber border and a soft amber glow; inactive: neutral reading text with a
/// clear border (kept at 2 pt so highlighting never shifts layout).
private struct BismillahButton: View {
    let element: Element
    let isActive: Bool
    let onTap: () -> Void

    private var amber: Color { AppColor.elJumla }

    var body: some View {
        Button(action: onTap) {
            Text(element.arabic)
                .font(arabicFont(24))  // text-2xl
                .foregroundStyle(isActive ? amber : AppColor.textMain)
                .multilineTextAlignment(.center)
                .lineSpacing(6)  // leading-relaxed
                .padding(.horizontal, 16)  // px-4
                .padding(.vertical, 8)     // py-2
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)  // rounded-lg
                        .fill(isActive ? amber.opacity(0.094) : Color.clear)  // jumla @ 0x18
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isActive ? amber : Color.clear, lineWidth: 2)
                )
                .shadow(color: isActive ? amber.opacity(0.25) : .clear,  // 0 4px 20px @ 0x40
                        radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .environment(\.layoutDirection, .rightToLeft)
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
    }
}

// MARK: - Prose

/// The stacked intro paragraphs — plain, non-tappable reading text. Extracted so
/// `Page1View.body` stays small and the paragraph list re-renders on its own.
private struct ParagraphList: View {
    let paragraphs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {  // gap-4
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, text in
                Text(text)
                    .font(.system(size: 14))  // text-sm
                    .foregroundStyle(AppColor.textMain)
                    .lineSpacing(6)           // leading-relaxed
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
