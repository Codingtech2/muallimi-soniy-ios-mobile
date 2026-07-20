import SwiftUI

/// Bespoke 1:1 renderer for book page 49 — the two Ibrahimiyya salawat (صَلِّ and
/// بَارِكْ variants) under the title الصَّلَوَاتُ, then the post-prayer refuge
/// du'a under الدُّعَاءُ. No audio: every element is tappable and only shows the
/// shared green active-highlight.
///
/// Titles are big tappable pills; clause lines follow the web `Row` grouping —
/// paired short clauses flow side-by-side via `WordRow`, lone clauses wrap
/// internally via `TappableTextLabel`. Sections are split by the tight dotted
/// `DottedSep` (web `my-1`). Per the project rule, an inactive clause is never
/// dimmed.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page49`.
struct Page49View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0.5` → 2 pt.
        VStack(spacing: 2) {
            salawat(c)
            dua(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    /// الصَّلَوَاتُ — title then the two salawat blocks (each: two paired lines +
    /// a closing `إِنَّكَ حَمِيدٌ مَجِيدٌ`).
    @ViewBuilder
    private func salawat(_ c: PageContent) -> some View {
        titleRow(c, "title_salawat")
        DottedSep()
        block(c, prefix: "s1")
        DottedSep()
        block(c, prefix: "s2")
        DottedSep()
    }

    /// الدُّعَاءُ — title then the four-clause refuge du'a (opening clause wraps,
    /// then a two-clause line, then a closing clause).
    @ViewBuilder
    private func dua(_ c: PageContent) -> some View {
        titleRow(c, "title_dua")
        DottedSep()
        clause(c, ["d_p1"])
        clause(c, ["d_p2", "d_p3"])
        clause(c, ["d_p4"])
    }

    /// One salawat block: `{prefix}_p1+p2`, `{prefix}_p3+p4`, then `{prefix}_p5`.
    @ViewBuilder
    private func block(_ c: PageContent, prefix: String) -> some View {
        clause(c, ["\(prefix)_p1", "\(prefix)_p2"])
        clause(c, ["\(prefix)_p3", "\(prefix)_p4"])
        clause(c, ["\(prefix)_p5"])
    }

    // MARK: - Rows

    /// A big tappable section title (web `Row size="lg"`), centred by `WordRow`.
    private func titleRow(_ c: PageContent, _ suffix: String) -> some View {
        WordRow(elements: c.els([suffix]), size: .lg, spacing: .gap3,
                activeId: activeId, onTap: onTap)
    }

    /// One clause line (web `Row size="sm" gap-1.5`). A lone clause wraps as a
    /// centred sentence pill; a pair flows side-by-side and wraps as a row.
    @ViewBuilder
    private func clause(_ c: PageContent, _ suffixes: [String]) -> some View {
        let els = c.els(suffixes)
        if els.count == 1, let only = els.first {
            TappableTextLabel(
                element: only, font: arabicFont(18),
                inactiveColor: AppColor.textMain, horizontalPadding: 6,
                activeId: activeId, onTap: onTap
            )
        } else {
            WordRow(elements: els, size: .sm, spacing: .gap1_5,
                    activeId: activeId, onTap: onTap)
        }
    }
}

// MARK: - Page-local divider

/// A tight full-width dotted rule — the web page-48/49 `Sep`
/// (`border-b-2 border-dotted border-white/10 my-1`).
private struct DottedSep: View {
    var body: some View {
        SepLine()
            .stroke(AppColor.divider,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 4]))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)   // my-1
    }
}

/// A single horizontal line across the middle of its rect, stroked as dots.
private struct SepLine: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
