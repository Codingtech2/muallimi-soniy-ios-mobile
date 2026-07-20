import SwiftUI

/// Bespoke 1:1 renderer for book page 32 — Idg'om (اِدْغَام): a tappable title
/// then six rows of two examples each. Each example shows the original phrase
/// (tappable, plays its audio) and, after a "−", the merged idg'om form as a
/// static grey hint — the web `IdgomCell`. Reading order is RTL: the first id
/// of each pair sits on the right, the second on the left (web `RowPair`,
/// `flex-row-reverse` + `dir=rtl`).
///
/// The merged-form strings are page-local display literals (NOT element data),
/// ported verbatim; the tappable original comes from `element.arabic`.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page32`
/// (page-local `IdgomCell` + `RowPair`).
struct Page32View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        VStack(spacing: 0) {                      // web outer gap-0
            title(c.el("title"))
            ForEach(Self.rows) { row in
                rowPair(row, c)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Title (اِدْغَام)

    @ViewBuilder
    private func title(_ e: Element?) -> some View {
        if let e {
            let active = activeId == e.id
            Button { onTap(e) } label: {
                Text(e.arabic)
                    .font(arabicFont(19, weight: .bold))     // clamp max 1.2rem
                    .foregroundStyle(active ? .white : AppColor.textSecondary)
                    .padding(.horizontal, 12)                // px-3
                    .padding(.vertical, 4)                   // py-1
                    .background(activeFill(active, corner: 8))
                    .shadow(color: active ? AppColor.primaryGlow : .clear, radius: 12, x: 0, y: 8)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)                              // mb-1
            .animation(.spring(response: 0.3, dampingFraction: 0.62), value: active)
        }
    }

    // MARK: - Row pair (justify-around, RTL: right id first, then left id)

    private func rowPair(_ row: IdgomRow, _ c: PageContent) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            cell(row.right, c)
            Spacer(minLength: 0)
            cell(row.left, c)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)                               // py-0.5
        .environment(\.layoutDirection, .rightToLeft)
    }

    // MARK: - One example: (original) − (merged)

    @ViewBuilder
    private func cell(_ ex: Example, _ c: PageContent) -> some View {
        if let e = c.el(ex.suffix) {
            let active = activeId == e.id
            HStack(alignment: .firstTextBaseline, spacing: 4) {   // gap-1
                Button { onTap(e) } label: {
                    Text("(\(e.arabic))")
                        .font(arabicFont(15, weight: .regular))  // clamp max 0.95rem
                        .foregroundStyle(active ? .white : AppColor.textMain)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 6)                 // px-1.5
                        .background(activeFill(active, corner: 6))
                        .shadow(color: active ? AppColor.primaryGlow : .clear, radius: 12, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                Text("−")
                    .font(.system(size: 10))                     // 0.625rem, opacity 60
                    .foregroundStyle(AppColor.textMain.opacity(0.6))
                Text("(\(ex.merged))")
                    .font(arabicFont(12, weight: .regular))      // clamp max 0.78rem, opacity 65
                    .foregroundStyle(AppColor.textMain.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .environment(\.layoutDirection, .rightToLeft)
            .animation(.spring(response: 0.3, dampingFraction: 0.62), value: active)
        }
    }

    private func activeFill(_ active: Bool, corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(active ? AppColor.primary : Color.clear)
    }

    // MARK: - Page-local data

    /// One example: the element id-suffix (tappable original) plus its merged
    /// idg'om display string (static hint, page-local literal).
    private struct Example: Hashable {
        let suffix: String
        let merged: String
    }

    /// One book row = two examples (`right` read first in RTL, then `left`).
    private struct IdgomRow: Identifiable {
        let id: Int
        let right: Example
        let left: Example
    }

    private static let rows: [IdgomRow] = [
        IdgomRow(id: 1,
                 right: Example(suffix: "e01_minmasad", merged: "مِمْ مَسَدٍ"),
                 left: Example(suffix: "e02_lannumin", merged: "لَنُّؤْمِنَ")),
        IdgomRow(id: 2,
                 right: Example(suffix: "e03_minwali", merged: "مِوَّلِيٍّ"),
                 left: Example(suffix: "e04_wamanya", merged: "وَمَيَّعْمَلْ")),
        IdgomRow(id: 3,
                 right: Example(suffix: "e05_wamanlam", merged: "وَمَلَّمْ"),
                 left: Example(suffix: "e06_minrabb", merged: "مِرَّبِّهِمْ")),
        IdgomRow(id: 4,
                 right: Example(suffix: "e07_hudamin", merged: "هُدَمْ مِنْ"),
                 left: Example(suffix: "e08_shaynkr", merged: "شَيْئَنُّكْرًا")),
        IdgomRow(id: 5,
                 right: Example(suffix: "e09_ilahwah", merged: "اِلٰهُوَّاحِدٌ"),
                 left: Example(suffix: "e10_khayyar", merged: "خَيْرَيَّرَهُ")),
        IdgomRow(id: 6,
                 right: Example(suffix: "e11_hudalmu", merged: "هُدَلِّلْمُتَّقِينَ"),
                 left: Example(suffix: "e12_ghafrah", merged: "غَفُورُرَّحِيمٌ"))
    ]
}
