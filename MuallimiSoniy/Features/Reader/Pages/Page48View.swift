import SwiftUI

/// Bespoke 1:1 renderer for book page 48 — Sano (الثَّنَاءُ) and Tashahhud
/// (التَّشَهُّدُ). No audio: every element is tappable and only shows the shared
/// green active-highlight (the lesson has no audio track, so nothing plays).
///
/// Each section opens with a big tappable title pill, split from its body by a
/// tight dotted `DottedSep` (web `my-1`). Clause rows follow the web `Row`
/// grouping exactly: a line holding several short clauses flows side-by-side via
/// `WordRow`; a line holding one long clause wraps internally via
/// `TappableTextLabel`. Both render at the same 18 pt bold body face, so the two
/// paths look identical. Per the project rule, an inactive clause is never dimmed.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page48`.
struct Page48View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        // Web outer: `flex flex-col items-center gap-0.5` → 2 pt.
        VStack(spacing: 2) {
            sano(c)
            tashahhud(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    /// الثَّنَاءُ — title + one long clause (`s1`, wraps) + a two-clause line.
    @ViewBuilder
    private func sano(_ c: PageContent) -> some View {
        titleRow(c, "s_title")
        DottedSep()
        clause(c, ["s1"], .gap1_5)
        clause(c, ["s2", "s3"], .gap2)
        DottedSep()
    }

    /// التَّشَهُّدُ — title + a three-clause line, then four single-clause lines.
    @ViewBuilder
    private func tashahhud(_ c: PageContent) -> some View {
        titleRow(c, "t_title")
        DottedSep()
        clause(c, ["t1", "t2", "t3"], .gap1_5)
        clause(c, ["t4"], .gap1_5)
        clause(c, ["t5"], .gap1_5)
        clause(c, ["t6"], .gap1_5)
        clause(c, ["t7"], .gap1_5)
    }

    // MARK: - Rows

    /// A big tappable section title (web `Row size="lg"`): a single `lg`
    /// `ArabicElementView`, centred by `WordRow`.
    private func titleRow(_ c: PageContent, _ suffix: String) -> some View {
        WordRow(elements: c.els([suffix]), size: .lg, spacing: .gap3,
                activeId: activeId, onTap: onTap)
    }

    /// One clause line (web `Row size="sm"`). A single clause wraps internally as
    /// a centred sentence pill; several clauses flow side-by-side and wrap as a
    /// row. Same 18 pt bold body face either way.
    @ViewBuilder
    private func clause(_ c: PageContent, _ suffixes: [String], _ gap: RowSpacing) -> some View {
        let els = c.els(suffixes)
        if els.count == 1, let only = els.first {
            TappableTextLabel(
                element: only, font: arabicFont(18),
                inactiveColor: AppColor.textMain, horizontalPadding: 6,
                activeId: activeId, onTap: onTap
            )
        } else {
            WordRow(elements: els, size: .sm, spacing: gap,
                    activeId: activeId, onTap: onTap)
        }
    }
}

// MARK: - Page-local divider

/// A tight full-width dotted rule — the web page-48/49 `Sep`
/// (`border-b-2 border-dotted border-white/10 my-1`). Distinct from the shared
/// `SectionDivider`, which uses the roomier `my-2`.
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
