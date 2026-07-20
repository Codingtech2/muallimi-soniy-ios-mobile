import Foundation

/// A top-level book chapter (e.g. "Muqaddima", "Harflar").
nonisolated struct Chapter: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let title: LocalizedString
    let order: Int
    /// Emoji glyph from the content package (UI maps this to an SF Symbol).
    let icon: String
    let lessonCount: Int
}

/// A lesson inside a chapter. Some lessons have no dedicated full-length
/// audio track, so `audioUrl` is optional (JSON `null`).
nonisolated struct Lesson: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let chapterId: String
    let title: LocalizedString
    let order: Int
    let audioUrl: String?
    let pageCount: Int
}

/// A single tappable element on a page (letter, syllable, word or sentence).
///
/// `audioUrl` is optional: some elements are visual-only and the key is
/// absent in JSON. Geometry (`x`/`y`/`width`/`height`) is emitted as `0`
/// for elements that are laid out by the renderer rather than positioned.
nonisolated struct Element: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let type: ElementType
    let arabic: String
    let uzbek: String
    let audioUrl: String?
    let start: Double
    let end: Double
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}
