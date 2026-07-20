import Foundation

/// A thin picker over one page's elements — the SwiftUI port of the web
/// `usePageElements` helper (`el` / `els`). Bespoke per-page renderers use this
/// to pull specific elements out of `BookPage.elements` by their id suffix
/// instead of indexing the array by hand.
///
/// Element ids are `"p{pageNumber}_{suffix}"` (e.g. `"p17_intro_rule"`), so
/// matching on the trailing `"_\(suffix)"` is enough without needing the page
/// number itself.
nonisolated struct PageContent: Sendable {
    let elements: [Element]

    /// The element whose id ends with `"_\(suffix)"`, or `nil` if the page has
    /// no such element (e.g. a still-unported suffix).
    func el(_ suffix: String) -> Element? {
        elements.first { $0.id.hasSuffix("_\(suffix)") }
    }

    /// Looks up each suffix in order via `el(_:)`, dropping any that are
    /// missing — mirrors the web `els(ids)` (`.filter(Boolean)`).
    func els(_ suffixes: [String]) -> [Element] {
        suffixes.compactMap { el($0) }
    }
}
