import SwiftUI

/// Bespoke 1:1 renderer for book page 40 — Surah Al-'Alaq body (19 ayat; its
/// title + bismillah are the header on page 39), then Surah Al-Qadr (bismillah +
/// 5 ayat). Verse 19 is a sajda (prostration) verse: flagged with a green `۩`
/// mark and a small `سجده آیتی` caption via `SajdaRow`.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page40`.
struct Page40View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0.5` → 2 pt.
        VStack(spacing: 2) {
            alaqBody(c)
            SectionDivider()
            qadrSection(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    /// Al-'Alaq — 19 ayat; the final verse is a sajda (`SajdaRow`).
    @ViewBuilder
    private func alaqBody(_ c: PageContent) -> some View {
        ayah(c, ["a01", "a02"], .gap1_5)
        ayah(c, ["a03", "a04"], .gap1_5)
        ayah(c, ["a05", "a06"], .gap1_5)
        ayah(c, ["a07", "a08", "a09"], .gap1)
        ayah(c, ["a10", "a11", "a12"], .gap1)
        ayah(c, ["a13", "a14"], .gap1_5)
        ayah(c, ["a15"], .gap2)
        ayah(c, ["a16", "a17", "a18"], .gap1)
        if let a19 = c.el("a19") {
            SajdaRow(element: a19, isActive: activeId == a19.id, onTap: onTap)
        }
    }

    /// Al-Qadr — bismillah + 5 ayat (rows 1 / 2+3 / 4 / 5).
    @ViewBuilder
    private func qadrSection(_ c: PageContent) -> some View {
        SectionTitle("سورة القدر", subtitle: "قدر سوره‌سی")
        WordRow(elements: c.els(["q_bism"]), size: .sm, spacing: .gap2, activeId: activeId, onTap: onTap)
        ayah(c, ["q01"], .gap2)
        ayah(c, ["q02", "q03"], .gap1_5)
        ayah(c, ["q04"], .gap2)
        ayah(c, ["q05"], .gap2)
    }

    /// Flower-separated verse row (web `AyahRow`, size sm).
    private func ayah(_ c: PageContent, _ ids: [String], _ spacing: RowSpacing) -> some View {
        AyahRow(elements: c.els(ids), size: .sm, spacing: spacing, activeId: activeId, onTap: onTap)
    }
}

// MARK: - Sajda verse (web Page40 inline `flex-row-reverse … ۩` + caption)

/// Al-'Alaq v.19 — the flower ayah beside the sajda mark `۩`, with a small muted
/// caption underneath (web: a `flex-row-reverse items-center justify-center
/// gap-1.5` row followed by a `0.5625rem` `سجده آیتی` paragraph).
private struct SajdaRow: View {
    let element: Element
    let isActive: Bool
    let onTap: (Element) -> Void

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {   // gap-1.5
                AyahPair(element: element, size: .sm, isActive: isActive, onTap: onTap)
                Text("۩")
                    .font(arabicFont(19, weight: .regular))   // clamp max 1.2rem
                    .foregroundStyle(AppColor.primary)
                    .opacity(0.85)
            }
            .environment(\.layoutDirection, .rightToLeft)
            .frame(maxWidth: .infinity)                        // justify-center

            Text("سجده آیتی")
                .font(arabicFont(9, weight: .regular))          // text-[0.5625rem]
                .foregroundStyle(AppColor.textMuted)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .frame(maxWidth: .infinity)
    }
}
