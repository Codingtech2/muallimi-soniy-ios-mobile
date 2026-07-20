import SwiftUI

/// Bespoke 1:1 renderer for book page 35 — Tamjid kalimasi, the definition of
/// iman, and Iman-i mujmal / mufassal. Green headings (`GreenHead`) sit above
/// centred jumla bodies rendered with the shared `Verse` primitive, split into
/// four sections by dotted `SectionDivider` rules (web `Sep`).
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page35`
/// (page-local `Sep` / `Head` / `Body`).
struct Page35View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0.5` → 2 pt.
        VStack(spacing: 2) {
            tamjid(c)
            SectionDivider()
            definition(c)
            SectionDivider()
            block(c, head: "mujmal_head", body: "mujmal_body", size: .md)
            SectionDivider()
            block(c, head: "mufassal_head", body: "mufassal_body", size: .sm)
        }
        .frame(maxWidth: .infinity)
    }

    /// TAMJID — heading + four clauses (the 4th larger) + the "mā shāʾa-llāh" line.
    @ViewBuilder
    private func tamjid(_ c: PageContent) -> some View {
        head(c, "tamjid_head")
        body(c, "tamjid_p1", .md)
        body(c, "tamjid_p2", .md)
        body(c, "tamjid_p3", .md)
        body(c, "tamjid_p4", .lg)
        body(c, "mashallah", .md)
    }

    /// The definition of iman + the trailing salawat.
    @ViewBuilder
    private func definition(_ c: PageContent) -> some View {
        body(c, "iman_def", .sm)
        body(c, "salawat", .sm)
    }

    /// A heading + single body block (mujmal / mufassal).
    @ViewBuilder
    private func block(_ c: PageContent, head id: String, body bodyId: String, size: VerseSize) -> some View {
        head(c, id)
        body(c, bodyId, size)
    }

    // MARK: - Leaf builders

    @ViewBuilder
    private func head(_ c: PageContent, _ id: String) -> some View {
        if let h = c.el(id) {
            GreenHead(element: h, activeId: activeId, onTap: onTap)
        }
    }

    @ViewBuilder
    private func body(_ c: PageContent, _ id: String, _ size: VerseSize) -> some View {
        if let b = c.el(id) {
            Verse(element: b, size: size, isActive: activeId == b.id, onTap: onTap)
        }
    }
}

// MARK: - Page-local sub-views

/// A centred, tappable green section heading (web `Head`) — bold Arabic in
/// `textSecondary` with the primitive green-pill highlight when active.
private struct GreenHead: View {
    let element: Element
    let activeId: String?
    let onTap: (Element) -> Void

    private var isActive: Bool { activeId == element.id }

    var body: some View {
        Button { onTap(element) } label: {
            Text(element.arabic)
                .font(arabicFont(15))   // text-[…,0.95rem] bold
                .foregroundStyle(isActive ? Color.white : AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)   // px-2.5
                .padding(.vertical, 2)      // py-0.5
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? AppColor.primary : Color.clear)
                )
                .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .environment(\.layoutDirection, .rightToLeft)
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
    }
}
