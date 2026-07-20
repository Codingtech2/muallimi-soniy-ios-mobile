import SwiftUI

// Reusable building blocks for the mad pages (book pages 17–21). Ports of the
// web components in `src/components/lesson/RenderedPage.tsx`:
// `MadRule`, `TitleBlock`, the Page17/18 mad grid, and `YaNuqtasizRule`.
//
// Mad syllable text (`element.arabic`) already carries the mad Unicode
// (U+0670 superscript-alef fatha, U+0656 subscript-alef kasra, large U+064F
// damma) baked into `book.json`, so these views just render it with the mad
// face via `ArabicElementView(mad:)`. No substitution here.

// MARK: - MadRule (page 17 only)

/// The book-preamble banner shown ONLY on page 17: fatha/kasra are written
/// straight (vertical) and damma larger. Port of the web `MadRule`.
///
/// The 6-sentence body is verbatim from the book preamble (hardcoded in the
/// web too); the passed `rule` element drives only the tap + active highlight.
/// When `rule` is `nil` the banner renders as a non-tappable card.
struct MadRule: View {
    let rule: Element?
    let activeId: String?
    let onTap: (Element) -> Void

    private var isActive: Bool { rule.map { activeId == $0.id } ?? false }

    var body: some View {
        Group {
            if let rule {
                Button { onTap(rule) } label: { card }
                    .buttonStyle(.plain)
            } else {
                card
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            body6
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)   // px-3
        .padding(.vertical, 8)      // py-2
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColor.primary.opacity(isActive ? 0.12 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isActive ? AppColor.primary : AppColor.primary.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 12, x: 0, y: 8)
        .environment(\.layoutDirection, .rightToLeft)   // RTL, text-right
    }

    private var header: some View {
        HStack(spacing: 4) {
            Text("مد یازیلیشی قائده‌لری")
                .font(arabicFont(11, weight: .semibold))
                .foregroundStyle(AppColor.textMain)
            Text("(کتاب مقدمه‌سیدن)")
                .font(arabicFont(11, weight: .regular))
                .foregroundStyle(AppColor.textMuted)
            Spacer(minLength: 8)
            if rule != nil { MadListenPill() }
        }
    }

    private var body6: some View {
        VStack(alignment: .leading, spacing: 4) {
            paragraph("بونگاچه یازیلگان عربچه سوزلر مدسیز سوزلر ایدی. ایندی عربچه سوزلرینینگ مدلیلری کورساتیلادی.")
            paragraph("عربچه سوزلر مدلی بولگانده فتحه، کسره و ضمّه علامتلری باشقه‌چه یازیلادی:")
            VStack(alignment: .leading, spacing: 2) {
                bullet("فتحه و کسره علامتلری یانباشلاتیلمای، بلکه تیکّه یازیلادی.")
                bullet("ضمّه علامتی عادتی ضمّه‌دن کوره کتته‌راق، یوغانراق یازیلادی.")
            }
            .padding(.leading, 14)   // ps-3.5 (start == right in RTL)
            paragraph("اوقووچیلر بو اوزگاریشلرگه دقّت قیلیشلری کرک.")
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(arabicFont(11, weight: .regular))
            .foregroundStyle(AppColor.textMuted)
            .lineSpacing(3)            // leading-relaxed
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A disc-marked rule line (the two bold, must-notice rules).
    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•").foregroundStyle(AppColor.primary)
            Text(text)
                .font(arabicFont(11, weight: .semibold))
                .foregroundStyle(AppColor.textMain)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The small "listen" affordance pill (play glyph + "اشیتیش") shown on tappable
/// mad banners. Forced LTR so the play icon sits before the label.
struct MadListenPill: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "play.fill").font(.system(size: 8))
            Text("اشیتیش").font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(AppColor.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Capsule().fill(AppColor.primary.opacity(0.15)))
        .environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: - MadTitleBlock (page 17)

/// The tappable "Madliy harflar" title on page 17 — plays the intro-title
/// chunk. Port of the web `TitleBlock`. Falls back to a plain `SectionTitle`
/// when the intro-title element is absent.
struct MadTitleBlock: View {
    let introTitle: Element?
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        if let introTitle {
            let isActive = activeId == introTitle.id
            Button { onTap(introTitle) } label: {
                VStack(spacing: 2) {
                    Text(introTitle.arabic)
                        .font(madArabicFont(20))       // mad-arabic-text text-xl
                        .foregroundStyle(AppColor.textSecondary)
                    Text("مدلی حرفلر")
                        .font(arabicFont(12, weight: .regular))
                        .foregroundStyle(AppColor.textMuted)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isActive ? AppColor.primary.opacity(0.12) : .clear)
                )
                .shadow(color: isActive ? AppColor.primaryGlow : .clear, radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 8)   // my-2
            .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isActive)
        } else {
            SectionTitle("مدلي حرفلر", subtitle: "مدلی حرفلر")
        }
    }
}

// MARK: - Mad grid (pages 17 & 18)

/// Lays out mad syllables in up to 3 outer columns (RTL: right, middle, left),
/// each column a vertical stack of `MadSyllableRow`s separated by hairline
/// dividers. Port of the Page17/Page18 grid.
///
/// Each column is `[[Element]]`: one inner `[Element]` per visual row (a
/// letter's 3 mad forms — aa / ii / uu). Columns may differ in row count
/// (page 17's right `ي` column has one extra row); they align to the top.
struct MadColumnGrid: View {
    let right: [[Element]]
    let middle: [[Element]]
    let left: [[Element]]
    var size: ArabicSize = .sm
    let activeId: String?
    let onTap: (Element) -> Void

    private var columns: [[[Element]]] { [right, middle, left].filter { !$0.isEmpty } }

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, rows in
                if index > 0 { columnDivider }
                MadColumn(rows: rows, size: size, activeId: activeId, onTap: onTap)
            }
        }
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, .rightToLeft)   // right column on the right
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(AppColor.divider)
            .frame(width: 1)
            .frame(maxHeight: .infinity)   // self-stretch to tallest column
    }
}

/// One outer column: a vertical stack of mad syllable rows.
private struct MadColumn: View {
    let rows: [[Element]]
    var size: ArabicSize = .sm
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, elements in
                MadSyllableRow(elements: elements, size: size, activeId: activeId, onTap: onTap)
            }
        }
        .frame(maxWidth: .infinity)   // flex-1
    }
}

/// A single centred, non-wrapping RTL row of mad syllables — each cell an
/// `ArabicElementView(mad: true)`. Unlike `WordRow` this never wraps, matching
/// the fixed 3-per-row mad grid cells.
struct MadSyllableRow: View {
    let elements: [Element]
    var size: ArabicSize = .sm
    var spacing: CGFloat = 4
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(elements) { element in
                ArabicElementView(
                    element: element,
                    size: size,
                    mad: true,
                    isActive: activeId == element.id,
                    onTap: { onTap(element) }
                )
            }
        }
        .frame(maxWidth: .infinity)   // justify-center within the column
        .environment(\.layoutDirection, .rightToLeft)
    }
}

/// The static 3-letter header row (`ا ي و`) above page 17's grid. Uses the
/// ordinary Arabic body font (NOT the mad face) so `ي` keeps its dots.
struct MadHeaderRow: View {
    var letters: [String] = ["ا", "ي", "و"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(letters.enumerated()), id: \.offset) { _, letter in
                Text(letter)
                    .font(arabicFont(40))   // clamp max 2.5rem
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity)   // flex-1 + centre
            }
        }
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, .rightToLeft)   // ا on the right
    }
}

// MARK: - YaNuqtasizRule (page 20)

/// The "ي ، يـ = ى" banner (dot-less ya reads like ordinary ya). Static —
/// no tap. Port of the web `YaNuqtasizRule`.
struct YaNuqtasizRule: View {
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                Text("ي ، يـ").font(arabicFont(24)).foregroundStyle(AppColor.textMain)
                Text("=").font(.system(size: 18)).foregroundStyle(AppColor.textMuted)
                Text("ى").font(arabicFont(24)).foregroundStyle(AppColor.textMain)
            }
            Text("نقطه‌سیز ى هم خودّی عادی ي کبی اوقیلادی.")
                .font(arabicFont(11, weight: .regular))
                .foregroundStyle(AppColor.textMuted)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColor.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AppColor.primary.opacity(0.2), lineWidth: 1)
        )
        .padding(.vertical, 8)   // my-2
    }
}

#if DEBUG
private nonisolated func madPreviewElement(_ id: String, _ arabic: String) -> Element {
    Element(id: id, type: .bogin, arabic: arabic, uzbek: "",
            audioUrl: nil, start: 0, end: 0, x: 0, y: 0, width: 0, height: 0)
}

#Preview("Mad banners") {
    ScrollView {
        VStack(spacing: 12) {
            MadRule(
                rule: madPreviewElement("p17_intro_rule", ""),
                activeId: nil,
                onTap: { _ in }
            )
            MadHeaderRow()
            MadColumnGrid(
                right: [[madPreviewElement("r1", "بٰا"), madPreviewElement("r2", "بٖى"), madPreviewElement("r3", "بُو")]],
                middle: [[madPreviewElement("m1", "تٰا"), madPreviewElement("m2", "تٖى"), madPreviewElement("m3", "تُو")]],
                left: [[madPreviewElement("l1", "جٰا"), madPreviewElement("l2", "جٖى"), madPreviewElement("l3", "جُو")]],
                activeId: "m2",
                onTap: { _ in }
            )
            YaNuqtasizRule()
        }
        .padding(16)
    }
    .background(AppColor.background)
}
#endif
