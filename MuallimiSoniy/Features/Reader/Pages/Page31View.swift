import SwiftUI

/// Bespoke 1:1 renderer for book page 31 — the وقف (vaqf / stopping) topic:
/// the section title, a single large headword, a tappable chig'atoy definition
/// banner, a dotted divider, and nine vaqf examples in three three-word rows.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page31`.
struct Page31View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-2` → 8 pt.
        VStack(spacing: 8) {
            SectionTitle("وقف", subtitle: "وقف (توختاش)")
            WordRow(elements: c.els(["01"]), size: .lg, spacing: .gap3,
                    activeId: activeId, onTap: onTap)
            NarrationBanner(rule: c.el("definition"), activeId: activeId, onTap: onTap)
            SectionDivider()
            exampleRows(c)
        }
        .frame(maxWidth: .infinity)
    }

    /// Nine vaqf examples — 3 rows × 3 words (`size="md"`, `gap-2`).
    @ViewBuilder private func exampleRows(_ c: PageContent) -> some View {
        exampleRow(c, ["02", "03", "04"])
        exampleRow(c, ["05", "06", "07"])
        exampleRow(c, ["08", "09", "10"])
    }

    private func exampleRow(_ c: PageContent, _ ids: [String]) -> some View {
        WordRow(elements: c.els(ids), size: .md, spacing: .gap2,
                activeId: activeId, onTap: onTap)
    }
}
