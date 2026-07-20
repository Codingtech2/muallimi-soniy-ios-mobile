import SwiftUI

/// Bespoke 1:1 SwiftUI port of the web `Page4` (Za / Mim / Ta practice — 4.jpg).
///
/// Mirrors `RenderedPage.tsx` `Page4` exactly: three letter sections separated
/// by dotted dividers. Each section leads with a harakat header row (`2xl`,
/// `gap-5`), then flows into syllable/word rows at progressively smaller sizes.
///
/// The active token's highlight comes entirely from the primitives; other
/// elements are never dimmed (project UI rule).
struct Page4View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        VStack(spacing: 4) {  // web outer `flex flex-col items-center gap-1`
            // Za section (13 items).
            WordRow(elements: c.els(["01", "02", "03"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["04", "05", "06", "07", "08", "09"]),
                    size: .xl, spacing: .gap2, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["10", "11", "12", "13"]),
                    size: .lg, spacing: .gap3, activeId: activeId, onTap: onTap)

            SectionDivider()

            // Mim section (19 items).
            WordRow(elements: c.els(["14", "15", "16"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["17", "18", "19", "20", "21", "22"]),
                    size: .xl, spacing: .gap2, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["23", "24", "25", "26", "27", "28"]),
                    size: .lg, spacing: .gap2, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["29", "30", "31", "32"]),
                    size: .lg, spacing: .gap3, activeId: activeId, onTap: onTap)

            SectionDivider()

            // Ta section (8 items).
            WordRow(elements: c.els(["33", "34", "35"]),
                    size: .xxl, spacing: .gap5, activeId: activeId, onTap: onTap)
            WordRow(elements: c.els(["36", "37", "38", "39", "40"]),
                    size: .lg, spacing: .gap3, activeId: activeId, onTap: onTap)
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
private struct Page4Preview: View {
    @Environment(ContentStore.self) private var store

    var body: some View {
        ScrollView {
            if let page = store.allBookPages.first(where: { $0.pageNumber == 4 }) {
                Page4View(page: page, activeId: nil, onTap: { _ in })
                    .padding(16)
            } else {
                Text("4-sahifa topilmadi").foregroundStyle(.secondary)
            }
        }
        .background(AppColor.background)
    }
}

#Preview("Page4View — p4") {
    Page4Preview().environment(ContentStore())
}
#endif
