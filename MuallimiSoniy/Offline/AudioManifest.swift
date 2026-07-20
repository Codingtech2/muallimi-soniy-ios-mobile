import Foundation

/// A single audio file to install, flattened out of the manifest's packs.
/// `Sendable` + `nonisolated` so the verify step can read it off the main actor.
nonisolated struct AudioFileEntry: Sendable, Equatable {
    /// Relative pack path, e.g. `"audio/edit/01_muqova/x.mp3"` — resolved against
    /// `MediaLocator.mediaDirectory`.
    let path: String
    let bytes: Int
    /// Lowercase hex SHA-256 of the file's bytes.
    let sha256: String
}

/// Codable mirror of the bundled `audio-manifest.json` — only the fields the
/// installer needs (`packs[].files[]` with `path` / `bytes` / `sha256`).
nonisolated struct AudioManifest: Decodable {
    struct Pack: Decodable {
        let files: [File]
    }
    struct File: Decodable {
        let path: String
        let bytes: Int
        let sha256: String
    }
    let packs: [Pack]
}

/// Loads the bundled manifest and flattens it into the deduped set of files to
/// install / verify (1757 entries — some files belong to two lesson packs).
nonisolated enum AudioManifestLoader {

    enum LoadError: LocalizedError {
        case missing
        var errorDescription: String? {
            switch self {
            case .missing: return "audio-manifest.json is missing from the app bundle."
            }
        }
    }

    /// Union of every pack's files, deduped by `path` (first occurrence wins),
    /// with `sha256` normalized to lowercase.
    static func load(bundle: Bundle = .main) throws -> [AudioFileEntry] {
        guard let url = bundle.url(forResource: "audio-manifest", withExtension: "json") else {
            throw LoadError.missing
        }
        let data = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(AudioManifest.self, from: data)

        var seen = Set<String>()
        var entries: [AudioFileEntry] = []
        entries.reserveCapacity(1800)
        for pack in manifest.packs {
            for file in pack.files where seen.insert(file.path).inserted {
                entries.append(AudioFileEntry(
                    path: file.path,
                    bytes: file.bytes,
                    sha256: file.sha256.lowercased()
                ))
            }
        }
        return entries
    }
}
