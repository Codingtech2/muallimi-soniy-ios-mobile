import SwiftUI

/// Bespoke 1:1 renderer for book page 39 — the tail of Surah Ad-Duha (v.11,
/// after v.1-10 on page 38), then Surah Ash-Sharh (bismillah + 8 ayat), Surah
/// At-Tin (bismillah + 8 ayat), and the Surah Al-'Alaq header (bismillah only;
/// its verses are on page 40).
///
/// Ports the web `Page39`'s compact page-local `Head`/`Sep` (smaller than the
/// shared `SectionTitle`/`SectionDivider`) so three surahs' worth of elements fit
/// one viewport. Bismillah lines are plain `WordRow`s; verses use flower-
/// separated `AyahRow`s.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page39`.
struct Page39View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0` → 0 pt.
        VStack(spacing: 0) {
            ayah(c, ["duho_v11"], .gap1)            // Duho v.11 (v.1-10 on p38)
            CompactSep()
            sharhSection(c)
            CompactSep()
            tinSection(c)
            CompactSep()
            CompactHead(text: "سورة العلق", sub: "علق سوره‌سی")   // header only, body p40
            bism(c, "alaq_bism")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    /// Surah Ash-Sharh — bismillah + 8 ayat (rows 1+2 / 3+4 / 5+6+7 / 8).
    @ViewBuilder
    private func sharhSection(_ c: PageContent) -> some View {
        CompactHead(text: "سورة الشرح", sub: "شرح سوره‌سی")
        bism(c, "sharh_bism")
        ayah(c, ["sharh_v1", "sharh_v2"], .gap1)
        ayah(c, ["sharh_v3", "sharh_v4"], .gap1)
        ayah(c, ["sharh_v5", "sharh_v6", "sharh_v7"], .gap1)
        ayah(c, ["sharh_v8"], .gap1)
    }

    /// Surah At-Tin — bismillah + 8 ayat (rows 1+2 / 3+4 / 5 / 6 / 7+8).
    @ViewBuilder
    private func tinSection(_ c: PageContent) -> some View {
        CompactHead(text: "سورة التين", sub: "تین سوره‌سی")
        bism(c, "tin_bism")
        ayah(c, ["tin_v1", "tin_v2"], .gap1)
        ayah(c, ["tin_v3", "tin_v4"], .gap1)
        ayah(c, ["tin_v5"], .gap1)
        ayah(c, ["tin_v6"], .gap1)
        ayah(c, ["tin_v7", "tin_v8"], .gap1)
    }

    // MARK: - Row helpers

    /// Flower-separated verse row (web `AyahRow`, size sm).
    private func ayah(_ c: PageContent, _ ids: [String], _ spacing: RowSpacing) -> some View {
        AyahRow(elements: c.els(ids), size: .sm, spacing: spacing, activeId: activeId, onTap: onTap)
    }

    /// Plain bismillah row (web `Row`, size sm, gap-1) — no trailing flower.
    private func bism(_ c: PageContent, _ id: String) -> some View {
        WordRow(elements: c.els([id]), size: .sm, spacing: .gap1, activeId: activeId, onTap: onTap)
    }
}

// MARK: - Compact page-local chrome (web Page39 `Head` / `Sep`)

/// Compact surah heading — smaller than `SectionTitle` so three headings fit one
/// screen (web `Head`: `text-base` bold title + `0.625rem` muted Arabic sub,
/// tight leading).
private struct CompactHead: View {
    let text: String
    let sub: String

    var body: some View {
        VStack(spacing: 1) {
            Text(text)
                .font(arabicFont(16))                     // text-base, bold
                .foregroundStyle(AppColor.textSecondary)
            Text(sub)
                .font(arabicFont(10, weight: .regular))   // text-[0.625rem]
                .foregroundStyle(AppColor.textMuted)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)                                 // mt-0.5
    }
}

/// Thin dotted rule (web `Sep`: `border-b border-dotted … my-1`) — lighter than
/// `SectionDivider` (2 pt, my-2) to save vertical space.
private struct CompactSep: View {
    var body: some View {
        DottedRule()
            .stroke(AppColor.divider, style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 4]))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)                        // my-1
    }
}

/// A single horizontal line across the middle of its rect, stroked with a dash to
/// read as dots.
private struct DottedRule: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
