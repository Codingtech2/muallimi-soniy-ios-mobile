import Foundation

/// Resolves relative content-audio paths (e.g. `"audio/edit/03_alifbo/x.mp3"`,
/// as stored in `Element.audioUrl` / `Lesson.audioUrl`) to on-disk file URLs
/// under Application Support, where the M5 downloader extracts the media pack.
///
/// `nonisolated` so both the reader (main actor) and the background downloader
/// can resolve paths — every operation is a pure, thread-safe `FileManager` call.
nonisolated enum MediaLocator {

    /// Subfolder of Application Support that holds the extracted media pack.
    static let mediaFolderName = "media"

    /// `<Application Support>/media` — the pack root the downloader fills and the
    /// player reads. Create it on demand with `ensureMediaDirectory()`.
    static var mediaDirectory: URL {
        applicationSupportDirectory().appending(path: mediaFolderName, directoryHint: .isDirectory)
    }

    // MARK: - Path resolution

    /// Resolves a relative pack path to its file URL under `mediaDirectory`.
    /// A leading slash is trimmed so `"/audio/x.mp3"` and `"audio/x.mp3"`
    /// resolve identically. Multi-component paths (with `/`) become subfolders.
    static func url(forRelativePath relativePath: String) -> URL {
        let trimmed = relativePath.hasPrefix("/") ? String(relativePath.dropFirst()) : relativePath
        return mediaDirectory.appending(path: trimmed)
    }

    /// File URL for an element's audio, or `nil` if the element has no audio.
    static func url(for element: Element) -> URL? {
        guard let path = element.audioUrl, !path.isEmpty else { return nil }
        return url(forRelativePath: path)
    }

    /// File URL for a lesson's full-length audio, or `nil` if it has none.
    static func url(for lesson: Lesson) -> URL? {
        guard let path = lesson.audioUrl, !path.isEmpty else { return nil }
        return url(forRelativePath: path)
    }

    // MARK: - Existence

    /// Whether a resolved media file exists on disk.
    static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    /// Whether an element's audio file is present on disk.
    static func exists(for element: Element) -> Bool {
        guard let url = url(for: element) else { return false }
        return exists(url)
    }

    // MARK: - Directory setup (downloader)

    /// Creates the media directory if needed and returns it. The downloader
    /// calls this before extracting the pack. The directory is also marked as
    /// excluded from backup (see `excludeFromBackupIfNeeded`).
    @discardableResult
    static func ensureMediaDirectory() throws -> URL {
        var directory = mediaDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        excludeFromBackupIfNeeded(&directory)
        return directory
    }

    /// Marks the media directory (and everything the pack extracts into it) as
    /// excluded from iCloud / iTunes backup. App Store guideline 2.5.1 forbids
    /// backing up re-downloadable content, and it spares the user ~127 MB of
    /// backup. Applied once — skipped when already set — and best-effort: a
    /// failure to write the flag never breaks the install.
    private static func excludeFromBackupIfNeeded(_ url: inout URL) {
        let already = (try? url.resourceValues(forKeys: [.isExcludedFromBackupKey]))?.isExcludedFromBackup
        guard already != true else { return }
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    // MARK: - Private

    /// Application Support directory for this app, created if missing. Falls back
    /// to the temporary directory should the lookup ever fail, so callers always
    /// get a usable URL.
    private static func applicationSupportDirectory() -> URL {
        do {
            return try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            return FileManager.default.temporaryDirectory
        }
    }
}
