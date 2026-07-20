import SwiftUI

/// Bespoke 1:1 renderer for book page 33 — the Arabic letter names (28 + 1
/// letters, each a tappable glyph with its spoken name beneath) followed by the
/// Qur'anic disjoined letters (muqatta'at). Ports the web `Page33` with its
/// page-local `LetterWithName`, `HarfRow` and `ClickableMuq`.
///
/// The letter names (`اَلِف`, `بَا`, …) are page-local display literals; every
/// glyph / muqatta'a comes from `element.arabic`.
///
/// Web reference: `src/components/lesson/RenderedPage.tsx` → `function Page33`.
struct Page33View: View {
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        let c = PageContent(elements: page.elements)
        VStack(spacing: 2) {                          // web outer gap-0.5
            clickableLabel(c.el("top_title"), size: 10, weight: .regular, color: AppColor.textSecondary)
            harfSection(c)
            SectionDivider()
            muqSection(c)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Top: letter names (rows of 7 / 7 / 7 / 8)

    @ViewBuilder
    private func harfSection(_ c: PageContent) -> some View {
        harfRow(["h01", "h02", "h03", "h04", "h05", "h06", "h07"], c)
        harfRow(["h08", "h09", "h10", "h11", "h12", "h13", "h14"], c)
        harfRow(["h15", "h16", "h17", "h18", "h19", "h20", "h21"], c)
        harfRow(["h22", "h23", "h24", "h25", "h26", "h27", "h28", "h29"], c)
    }

    private func harfRow(_ suffixes: [String], _ c: PageContent) -> some View {
        HStack(spacing: 5) {                          // gap clamp max ≈ 0.4rem
            ForEach(suffixes, id: \.self) { harfCell($0, c) }
        }
        .frame(maxWidth: .infinity)                   // justify-center
        .environment(\.layoutDirection, .rightToLeft) // h01 on the right
    }

    /// Vertical letter-over-name cell (web `LetterWithName`).
    @ViewBuilder
    private func harfCell(_ suffix: String, _ c: PageContent) -> some View {
        if let e = c.el(suffix) {
            let active = activeId == e.id
            Button { onTap(e) } label: {
                VStack(spacing: 2) {                  // mt-0.5 between glyph and name
                    Text(e.arabic)
                        .font(arabicFont(16, weight: .bold))     // clamp max 1.05rem
                        .foregroundStyle(active ? .white : AppColor.textMain)
                    if let name = Self.names[suffix] {
                        Text(name)
                            .font(arabicFont(10, weight: .regular))  // clamp max 0.65rem
                            .foregroundStyle((active ? Color.white : AppColor.textMain).opacity(0.8))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 4)              // px-1
                .padding(.vertical, 2)                // py-0.5
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(active ? AppColor.primary : .clear))
                .shadow(color: active ? AppColor.primaryGlow : .clear, radius: 12, x: 0, y: 8)
                .scaleEffect(active ? 1.06 : 1)
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.3, dampingFraction: 0.62), value: active)
        }
    }

    // MARK: - Bottom: muqatta'at (rows of 4 / 4 / 6)

    @ViewBuilder
    private func muqSection(_ c: PageContent) -> some View {
        clickableLabel(c.el("m_title"), size: 14, weight: .bold, color: AppColor.textSecondary)
        clickableLabel(c.el("m_subtitle"), size: 9.5, weight: .regular, color: AppColor.textMuted)
        muqRow(["m01", "m02", "m03", "m04"], c).padding(.top, 4)   // mt-1
        muqRow(["m05", "m06", "m07", "m08"], c)
        muqRow(["m09", "m10", "m11", "m12", "m13", "m14"], c)
    }

    private func muqRow(_ suffixes: [String], _ c: PageContent) -> some View {
        HStack(spacing: 0) {                          // justify-around via spacers
            Spacer(minLength: 0)
            ForEach(c.els(suffixes)) { e in
                muqCell(e)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func muqCell(_ e: Element) -> some View {
        let active = activeId == e.id
        return Button { onTap(e) } label: {
            Text(e.arabic)
                .font(arabicFont(19, weight: .bold))  // clamp max 1.2rem
                .foregroundStyle(active ? .white : AppColor.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 6)              // px-1.5
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(active ? AppColor.primary : .clear))
                .shadow(color: active ? AppColor.primaryGlow : .clear, radius: 12, x: 0, y: 8)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: active)
    }

    // MARK: - Shared clickable caption / title

    @ViewBuilder
    private func clickableLabel(_ e: Element?, size: CGFloat, weight: Font.Weight, color: Color) -> some View {
        if let e {
            let active = activeId == e.id
            Button { onTap(e) } label: {
                Text(e.arabic)
                    .font(arabicFont(size, weight: weight))
                    .foregroundStyle(active ? .white : color)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)          // px-2
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(active ? AppColor.primary : .clear))
                    .shadow(color: active ? AppColor.primaryGlow : .clear, radius: 12, x: 0, y: 8)
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .buttonStyle(.plain)
            .animation(.spring(response: 0.3, dampingFraction: 0.62), value: active)
        }
    }

    // MARK: - Page-local letter names (Arabic spoken forms)

    private static let names: [String: String] = [
        "h01": "اَلِف", "h02": "بَا", "h03": "تَا", "h04": "ثَا",
        "h05": "جِيم", "h06": "حَا", "h07": "خَا", "h08": "دَال",
        "h09": "ذَال", "h10": "رَا", "h11": "زَا", "h12": "سِين",
        "h13": "شِين", "h14": "صَاد", "h15": "ضَاد", "h16": "طَا",
        "h17": "ظَا", "h18": "عَين", "h19": "غَين", "h20": "فَا",
        "h21": "قَاف", "h22": "كَاف", "h23": "لَام", "h24": "مِيم",
        "h25": "نُون", "h26": "وَاو", "h27": "هَا", "h28": "لَامَالِف",
        "h29": "يَا"
    ]
}
