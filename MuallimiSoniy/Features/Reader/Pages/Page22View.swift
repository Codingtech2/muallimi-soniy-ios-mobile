import SwiftUI

/// Bespoke 1:1 renderer for book page 22 — tashdid practice: 10 rows × 6 words
/// (60 elements). R1–R4 active past verbs, a divider, R5–R8 passive verbs,
/// another divider, R9–R10 Form V masdars. Every token uses `size="sm"` so the
/// six tashdid words fit on one line.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page22`.
struct Page22View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-1` → 4 pt.
        VStack(spacing: 4) {
            rows(c, 1...4)          // active past verbs
            SectionDivider()
            rows(c, 5...8)          // passive verbs
            SectionDivider()
            rows(c, 9...10)         // Form V masdars
        }
        .frame(maxWidth: .infinity)
    }

    /// One block of `size="sm" gap-1.5` rows, each row `r{n}_w1…w6`.
    @ViewBuilder
    private func rows(_ c: PageContent, _ range: ClosedRange<Int>) -> some View {
        ForEach(Array(range), id: \.self) { n in
            WordRow(
                elements: c.els((1...6).map { "r\(n)_w\($0)" }),
                size: .sm,
                spacing: .gap1_5,
                activeId: activeId,
                onTap: onTap
            )
        }
    }
}
