import SwiftUI

/// TEMPORARY (M2 verification) — a throwaway screen that pulls **real** elements
/// from the environment `ContentStore` and renders them with the ported
/// primitives (`SectionTitle`, `WordRow`, `SectionDivider`, `SurahTitle`,
/// `Verse`). It exists only so we can screenshot that the custom Arabic font,
/// RTL word wrapping, tap-to-highlight and the surah `Verse` primitive all
/// render correctly. The real reader replaces this in M4 — delete this file and
/// the Home entry point then.
///
/// Highlight rule (mirrors the web): tapping a token makes **only that token**
/// active (green fill, white glyph, scale, glow); every other token keeps its
/// normal appearance — inactive tokens are never dimmed.
struct PrimitivesPreviewView: View {
    @Environment(ContentStore.self) private var store

    /// The single active token id across the whole preview (`nil` = none).
    /// Tapping toggles: an inactive token becomes active, the active one clears.
    @State private var selectedId: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statusHeader
                letterPageCard
                surahPageCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle("Namuna")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Status header (Latin system font — documents the screenshot)

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("M2 — primitivlar namunasi (vaqtinchalik)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColor.textMuted)
            Text("Arab shrifti: \(resolvedArabicFontName)")
                .font(.caption2)
                .foregroundStyle(AppColor.textMuted)
            Text("Tanlangan: \(selectedId ?? "yoʻq")")
                .font(.caption2.monospaced())
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Letter page (book page 4 — Za / Mim / Ta), mirroring web Page4

    private var letterPageCard: some View {
        Group {
            if let page = page(4) {
                VStack(spacing: 4) {
                    // Za section (elements 01–13)
                    SectionTitle("ز", subtitle: "Za harfi (takrorlash)")
                    row(page, "p4_", ["01", "02", "03"], .xxl, .gap5)
                    row(page, "p4_", ["04", "05", "06", "07", "08", "09"], .xl, .gap2)
                    row(page, "p4_", ["10", "11", "12", "13"], .lg, .gap3)

                    SectionDivider()

                    // Mim section (elements 14–32)
                    SectionTitle("م", subtitle: "Mim harfi")
                    row(page, "p4_", ["14", "15", "16"], .xxl, .gap5)
                    row(page, "p4_", ["17", "18", "19", "20", "21", "22"], .xl, .gap2)
                    row(page, "p4_", ["23", "24", "25", "26", "27", "28"], .lg, .gap2)
                    row(page, "p4_", ["29", "30", "31", "32"], .lg, .gap3)

                    SectionDivider()

                    // Ta section (elements 33–40)
                    SectionTitle("ت", subtitle: "Ta harfi")
                    row(page, "p4_", ["33", "34", "35"], .xxl, .gap5)
                    row(page, "p4_", ["36", "37", "38", "39", "40"], .lg, .gap3)
                }
                .cardStyle()
            } else {
                missing("4-sahifa (Za / Mim / Ta) topilmadi")
            }
        }
    }

    // MARK: - Surah page (book page 45) — SurahTitle + Verse samples

    private var surahPageCard: some View {
        Group {
            if let page = page(45) {
                VStack(spacing: 2) {
                    SurahTitle("سُورَةُ قُرَيْشٍ")
                    verse(page, "p45_qu_bism")
                    verse(page, "p45_qu_a1", ayah: 1)
                    verse(page, "p45_qu_a2", ayah: 2)
                    verse(page, "p45_qu_a3", ayah: 3)
                }
                .cardStyle()
            } else {
                missing("45-sahifa (sura) topilmadi")
            }
        }
    }

    // MARK: - Element lookup & primitive helpers

    /// The flattened book page whose book label equals `number` (e.g. 4, 45).
    private func page(_ number: Int) -> BookPage? {
        store.allBookPages.first { $0.pageNumber == number }
    }

    /// Resolves local ids (`"01"`, `"qu_bism"`) against a page's prefixed element
    /// ids (`"p4_01"`), mirroring the web `usePageElements().els(...)`.
    private func elements(_ page: BookPage, prefix: String, _ ids: [String]) -> [Element] {
        let byId = Dictionary(page.elements.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byId["\(prefix)\($0)"] }
    }

    /// One RTL word row wired to the shared selection.
    @ViewBuilder
    private func row(
        _ page: BookPage,
        _ prefix: String,
        _ ids: [String],
        _ size: ArabicSize,
        _ spacing: RowSpacing
    ) -> some View {
        WordRow(
            elements: elements(page, prefix: prefix, ids),
            size: size,
            spacing: spacing,
            activeId: selectedId,
            onTap: toggle
        )
    }

    /// One surah verse (by full element id) wired to the shared selection.
    @ViewBuilder
    private func verse(_ page: BookPage, _ fullId: String, ayah: Int? = nil) -> some View {
        if let element = page.elements.first(where: { $0.id == fullId }) {
            Verse(element: element, ayah: ayah, size: .sm, activeId: selectedId, onTap: toggle)
        }
    }

    /// Toggle highlight: re-tapping the active token clears it.
    private func toggle(_ element: Element) {
        selectedId = selectedId == element.id ? nil : element.id
    }

    private func missing(_ message: String) -> some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(AppColor.textMuted)
            .frame(maxWidth: .infinity)
            .cardStyle()
    }

    /// Resolved concrete member name of the universal Arabic font, surfaced so a
    /// screenshot documents which face actually rendered.
    private var resolvedArabicFontName: String {
        FontRegistrar.resolvedName(
            family: AppFontFamily.muallimi,
            postScriptFallback: AppFontFamily.muallimiPostScript
        )
    }
}

// MARK: - Card container (mirrors the web glass card: rounded-[28px] + hairline)

private extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                AppColor.glass,
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(AppColor.divider, lineWidth: 1)
            )
    }
}

#if DEBUG
#Preview("PrimitivesPreviewView") {
    NavigationStack {
        PrimitivesPreviewView()
    }
    .environment(ContentStore())
}
#endif
