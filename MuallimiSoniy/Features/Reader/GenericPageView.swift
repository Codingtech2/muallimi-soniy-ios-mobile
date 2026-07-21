import SwiftUI

/// The permanent fallback renderer — lays out any page's elements with the shared
/// primitives so every page (even those without a bespoke renderer yet) is
/// readable and fully tappable.
///
/// Layout: contiguous runs of the same non-`jumla` type are chunked into RTL
/// `WordRow`s; each `jumla` (sentence / ayah) renders as a full-width `Verse`.
/// The active element is highlighted; others are never dimmed (project UI rule).
struct GenericPageView: View {
    @Environment(ContentStore.self) private var content
    @Environment(SettingsStore.self) private var settings
    let page: BookPage
    let activeId: String?
    let onTap: (Element) -> Void

    var body: some View {
        VStack(spacing: 10) {
            if rows.isEmpty {
                Text(content.t("page_no_elements", settings.settings.locale))
                    .font(.callout)
                    .foregroundStyle(AppColor.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ForEach(rows) { row in
                    switch row.kind {
                    case let .verse(element):
                        Verse(
                            element: element,
                            size: .md,
                            isActive: activeId == element.id,
                            onTap: onTap
                        )
                    case let .words(elements, size, spacing):
                        WordRow(
                            elements: elements,
                            size: size,
                            spacing: spacing,
                            activeId: activeId,
                            onTap: onTap
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Row model

    private var rows: [GenericRow] {
        GenericPageView.buildRows(page.elements)
    }

    /// Groups elements into renderable rows: each `jumla` → one verse; each
    /// contiguous same-type non-`jumla` run → chunked word rows.
    private static func buildRows(_ elements: [Element]) -> [GenericRow] {
        var rows: [GenericRow] = []
        var buffer: [Element] = []
        var bufferType: ElementType?

        func flush() {
            guard let type = bufferType, !buffer.isEmpty else {
                buffer = []
                bufferType = nil
                return
            }
            let style = rowStyle(for: type)
            for group in chunk(buffer, into: style.perRow) {
                let id = "words_\(group.first?.id ?? "row")"
                rows.append(GenericRow(id: id, kind: .words(group, style.size, style.spacing)))
            }
            buffer = []
            bufferType = nil
        }

        for element in elements {
            if element.type == .jumla {
                flush()
                rows.append(GenericRow(id: "verse_\(element.id)", kind: .verse(element)))
            } else {
                if let current = bufferType, current != element.type { flush() }
                bufferType = element.type
                buffer.append(element)
            }
        }
        flush()
        return rows
    }

    /// Size / spacing / row-length per element type for the fallback grid.
    private static func rowStyle(for type: ElementType) -> RowStyle {
        switch type {
        case .harf: return RowStyle(size: .xl, spacing: .gap2, perRow: 6)
        case .bogin: return RowStyle(size: .lg, spacing: .gap2, perRow: 6)
        case .soz: return RowStyle(size: .lg, spacing: .gap2, perRow: 4)
        case .jumla: return RowStyle(size: .md, spacing: .gap2, perRow: 1)  // jumla renders as a verse
        }
    }
}

/// Per-element-type layout for a generic word row: token size, gap and how many
/// tokens fit before wrapping onto a new chunked row.
private struct RowStyle {
    let size: ArabicSize
    let spacing: RowSpacing
    let perRow: Int
}

/// A renderable row in the generic fallback: either a full-width verse or a chunk
/// of tappable tokens with their size + spacing.
private struct GenericRow: Identifiable {
    let id: String
    let kind: Kind

    enum Kind {
        case verse(Element)
        case words([Element], ArabicSize, RowSpacing)
    }
}

/// Splits `array` into consecutive groups of at most `size` (≥ 1). Empty input
/// yields no groups, so callers never produce an empty row.
private func chunk<T>(_ array: [T], into size: Int) -> [[T]] {
    guard size > 1 else { return array.map { [$0] } }
    return stride(from: 0, to: array.count, by: size).map {
        Array(array[$0 ..< min($0 + size, array.count)])
    }
}

#if DEBUG
private struct GenericPagePreview: View {
    @Environment(ContentStore.self) private var store

    var body: some View {
        ScrollView {
            if let page = store.allBookPages.first(where: { $0.pageNumber == 4 }) {
                GenericPageView(page: page, activeId: nil, onTap: { _ in })
                    .padding(16)
            } else {
                Text("4-sahifa topilmadi").foregroundStyle(.secondary)
            }
        }
        .background(AppColor.background)
    }
}

#Preview("GenericPageView — p4") {
    GenericPagePreview().environment(ContentStore()).environment(SettingsStore())
}
#endif
