import Foundation

/// Root of `book.json` — the whole content package in one value.
///
/// `lessons` is keyed by chapter id, `pageMap` by lesson id, and `pages`
/// by page-number **string** (e.g. "0", "3") exactly as stored in JSON.
nonisolated struct Book: Codable, Sendable {
    let chapters: [Chapter]
    let lessons: [String: [Lesson]]
    let pageMap: [String: [Int]]
    let pages: [String: [Element]]
    let extras: BookExtras
}

/// Miscellaneous prose that lives outside the page/element structure.
nonisolated struct BookExtras: Codable, Sendable {
    let muqaddimaParagraphs: [String]
}
