import SwiftUI

/// Bespoke 1:1 renderer for book page 41 — Surah Al-Bayyina (98): bismillah + 8
/// ayat, one flower-separated ayah per row (web `Page41`).
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page41`.
struct Page41View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    /// One ayah per row, in book order.
    private static let ayahIds = ["a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8"]

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0.5` → 2 pt.
        VStack(spacing: 2) {
            SectionTitle("سورة البينة", subtitle: "بیّنه سوره‌سی")
            WordRow(elements: c.els(["bism"]), size: .sm, spacing: .gap2, activeId: activeId, onTap: onTap)
            ForEach(Self.ayahIds, id: \.self) { id in
                AyahRow(elements: c.els([id]), size: .sm, spacing: .gap2, activeId: activeId, onTap: onTap)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
