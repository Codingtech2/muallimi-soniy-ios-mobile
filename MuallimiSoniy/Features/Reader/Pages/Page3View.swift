import SwiftUI

/// Bespoke 1:1 SwiftUI port of the web `Page3` (Alifbo + harakat + Ra sections).
///
/// Mirrors `RenderedPage.tsx` `Page3` top-to-bottom: five intro sentences
/// (a'uzu billah, bismillah, two rules + one example — all `jumla`), then the
/// 28-letter alphabet in four RTL rows of seven (`2xl`, `gap-1`), a `حَرَكَاتْ`
/// title, the three vowel marks (`3xl`, `gap-6`), a divider, then Ra's three
/// harakat forms (`3xl`) and its three syllables (`2xl`), all `gap-6`.
///
/// The active token's highlight comes entirely from the primitives; other
/// elements are never dimmed (project UI rule).
struct Page3View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        VStack(spacing: 4) {  // web outer `flex flex-col items-center gap-1`
            // Intro sentences — hierarchy: bismillah largest, a'uzu billah
            // medium, the two rules + example small.
            intro(c.el("auzubillah"), size: .md)
            intro(c.el("bismillah"), size: .lg)
            intro(c.el("rule1"), size: .sm)
            intro(c.el("misol"), size: .sm)
            intro(c.el("rule2"), size: .sm)

            // Alphabet — 28 letters, four RTL rows of seven.
            WordRow(elements: c.els(["01", "02", "03", "04", "05", "06", "07"]),
                    size: .xxl, spacing: .gap1, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["08", "09", "10", "11", "12", "13", "14"]),
                    size: .xxl, spacing: .gap1, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["15", "16", "17", "18", "19", "20", "21"]),
                    size: .xxl, spacing: .gap1, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["22", "23", "24", "25", "26", "27", "28"]),
                    size: .xxl, spacing: .gap1, activeId: activeId, onTap: onTap)

            SectionDivider()
            SectionTitle("حَرَكَاتْ", subtitle: "حرکتلر")

            // The three vowel marks (fatha / kasra / damma on alif).
            WordRow(elements: c.els(["29", "30", "31"]),
                    size: .xxxl, spacing: .gap6, activeId: activeId, onTap: onTap)

            SectionDivider()

            // Ra's three harakat forms, then its three closed syllables.
            WordRow(elements: c.els(["32", "33", "34"]),
                    size: .xxxl, spacing: .gap6, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["35", "36", "37"]),
                    size: .xxl, spacing: .gap6, activeId: activeId, onTap: onTap)
        }
        .frame(maxWidth: .infinity)
    }

    /// Renders one optional intro sentence (`jumla`) as a full-width tappable
    /// `Verse`; no-ops when the page lacks that element.
    @ViewBuilder
    private func intro(_ element: Element?, size: VerseSize) -> some View {
        if let element {
            Verse(
                element: element,
                size: size,
                isActive: activeId == element.id,
                onTap: onTap
            )
        }
    }
}

#if DEBUG
private struct Page3Preview: View {
    @Environment(ContentStore.self) private var store

    var body: some View {
        ScrollView {
            if let page = store.allBookPages.first(where: { $0.pageNumber == 3 }) {
                Page3View(page: page, activeId: nil, onTap: { _ in })
                    .padding(16)
            } else {
                Text("3-sahifa topilmadi").foregroundStyle(.secondary)
            }
        }
        .background(AppColor.background)
    }
}

#Preview("Page3View — p3") {
    Page3Preview().environment(ContentStore())
}
#endif
