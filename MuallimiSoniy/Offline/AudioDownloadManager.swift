import Foundation
import CryptoKit
import OSLog
import Observation

/// Downloads, installs and verifies the audio pack, exposing observable progress
/// for onboarding UI. One-shot per content version: once installed and verified,
/// `isReady` stays true across launches and `ensureReady()` returns immediately.
///
/// Memory-safe throughout: the ~127 MB zip streams to a temp file (URLSession),
/// is unpacked with `ZipStore` (1 MB chunks), and each file's SHA-256 is hashed
/// streamed — nothing is ever loaded whole into RAM. The heavy extract / verify
/// work runs on detached background tasks; only `phase` updates hop to the main
/// actor.
@MainActor
@Observable
final class AudioDownloadManager {

    /// Where the pipeline currently is. `downloading`/`extracting`/`verifying`
    /// carry a 0…1 fraction for that stage; `failed` carries a user message.
    enum Phase: Equatable {
        case idle
        case checking
        case downloading(Double)
        case extracting(Double)
        case verifying(Double)
        case ready
        case failed(String)
    }

    // MARK: - Observable state

    private(set) var phase: Phase = .idle

    // MARK: - Constants

    /// Content version this build ships; persisted once the pack is verified so
    /// later launches skip the whole pipeline.
    static let contentVersion = "2.0.0"

    private static let readyDefaultsKey = "audioReadyContentVersion"
    private static let packURL = URL(string:
        "https://github.com/Codingtech2/muallimi-soniy-ios-mobile/releases/download/content-2.0.0/audio.zip"
    )!
    /// A file guaranteed present in a good install — a cheap on-disk sanity check.
    private static let sanityRelativePath = "audio/01. muqova.mp3"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy",
        category: "AudioDownloadManager"
    )

    // MARK: - Derived state

    /// True when the verified pack for `contentVersion` is present on disk.
    var isReady: Bool {
        guard UserDefaults.standard.string(forKey: Self.readyDefaultsKey) == Self.contentVersion else {
            return false
        }
        let sanity = MediaLocator.url(forRelativePath: Self.sanityRelativePath)
        return FileManager.default.fileExists(atPath: sanity.path)
    }

    /// Overall 0…1 progress across all stages (download 70 %, extract 15 %,
    /// verify 15 %) — convenient for a single progress bar.
    var progressFraction: Double {
        switch phase {
        case .idle, .checking: return 0
        case .downloading(let f): return 0.70 * f
        case .extracting(let f): return 0.70 + 0.15 * f
        case .verifying(let f): return 0.85 + 0.15 * f
        case .ready: return 1
        case .failed: return 0
        }
    }

    // MARK: - Public API

    /// Installs the pack if it isn't already present + verified. Idempotent and
    /// safe to call on every launch — returns fast when `isReady`.
    func ensureReady() async {
        if isReady {
            phase = .ready
            return
        }
        let tempZip = Self.temporaryZipURL()
        do {
            phase = .checking
            let entries = try AudioManifestLoader.load()

            phase = .downloading(0)
            try await download(from: Self.packURL, to: tempZip)

            phase = .extracting(0)
            let mediaDir = try MediaLocator.ensureMediaDirectory()
            try await extract(zip: tempZip, into: mediaDir)
            try? FileManager.default.removeItem(at: tempZip)

            phase = .verifying(0)
            try await verify(entries: entries, mediaDir: mediaDir)

            UserDefaults.standard.set(Self.contentVersion, forKey: Self.readyDefaultsKey)
            phase = .ready
            logger.info("Audio pack \(Self.contentVersion, privacy: .public) installed and verified (\(entries.count) files).")
        } catch is CancellationError {
            try? FileManager.default.removeItem(at: tempZip)
            phase = .idle
        } catch {
            try? FileManager.default.removeItem(at: tempZip)
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            logger.error("ensureReady failed: \(message, privacy: .public)")
            phase = .failed(message)
        }
    }

    /// Clears the ready flag and deletes the installed media so the next
    /// `ensureReady()` re-downloads from scratch.
    func reset() {
        UserDefaults.standard.removeObject(forKey: Self.readyDefaultsKey)
        try? FileManager.default.removeItem(at: MediaLocator.mediaDirectory)
        phase = .idle
    }

    // MARK: - Download

    private func download(from url: URL, to destination: URL) async throws {
        try? FileManager.default.removeItem(at: destination)
        let delegate = DownloadProgressDelegate { [weak self] fraction in
            Task { @MainActor in
                guard let self, case .downloading = self.phase else { return }
                self.phase = .downloading(fraction)
            }
        }
        let (tempURL, response) = try await URLSession.shared.download(from: url, delegate: delegate)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            try? FileManager.default.removeItem(at: tempURL)
            throw AudioDownloadError.httpStatus(http.statusCode)
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        phase = .downloading(1)
    }

    // MARK: - Extract (off the main actor)

    private func extract(zip: URL, into dir: URL) async throws {
        let stream = AsyncThrowingStream<Double, Error> { continuation in
            Task.detached(priority: .userInitiated) {
                do {
                    var lastYield = 0.0
                    try ZipStore.extract(zipURL: zip, to: dir) { fraction in
                        if fraction - lastYield >= 0.01 || fraction >= 1 {
                            lastYield = fraction
                            continuation.yield(fraction)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
        for try await fraction in stream {
            phase = .extracting(fraction)
        }
    }

    // MARK: - Verify (off the main actor)

    private func verify(entries: [AudioFileEntry], mediaDir: URL) async throws {
        let stream = AsyncThrowingStream<Double, Error> { continuation in
            Task.detached(priority: .userInitiated) {
                let total = entries.count
                guard total > 0 else { continuation.finish(); return }

                var failures = 0
                var firstBad: String?
                var lastYield = 0.0
                for (index, entry) in entries.enumerated() {
                    let fileURL = mediaDir.appending(path: entry.path)
                    if !Self.verifyFile(at: fileURL, expectedSHA256: entry.sha256) {
                        failures += 1
                        if firstBad == nil { firstBad = entry.path }
                    }
                    let fraction = Double(index + 1) / Double(total)
                    if fraction - lastYield >= 0.01 || index + 1 == total {
                        lastYield = fraction
                        continuation.yield(fraction)
                    }
                }
                if failures > 0 {
                    continuation.finish(throwing: AudioDownloadError.verificationFailed(
                        failed: failures, total: total, firstBad: firstBad
                    ))
                } else {
                    continuation.finish()
                }
            }
        }
        for try await fraction in stream {
            phase = .verifying(fraction)
        }
    }

    /// Streamed SHA-256 of the file at `url`, compared to `expectedSHA256`
    /// (lowercase hex). Reads in 1 MB chunks — never loads the whole file.
    nonisolated static func verifyFile(at url: URL, expectedSHA256: String) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }

        var hasher = SHA256()
        let chunkSize = 1_048_576
        while true {
            let chunk: Data?
            do {
                chunk = try autoreleasepool { try handle.read(upToCount: chunkSize) }
            } catch {
                return false
            }
            guard let chunk, !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        let hex = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return hex == expectedSHA256
    }

    // MARK: - Helpers

    private static func temporaryZipURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "audio-pack-\(UUID().uuidString).zip")
    }
}

/// Errors surfaced by the download / install pipeline.
nonisolated enum AudioDownloadError: LocalizedError {
    case httpStatus(Int)
    case verificationFailed(failed: Int, total: Int, firstBad: String?)

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code):
            return "Audio pack download failed (HTTP \(code))."
        case .verificationFailed(let failed, let total, let firstBad):
            let example = firstBad.map { " First: \($0)." } ?? ""
            return "\(failed) of \(total) audio files failed verification.\(example)"
        }
    }
}

/// Per-task download delegate that reports byte progress. The async
/// `URLSession.download(from:delegate:)` manages the downloaded file itself, so
/// this only forwards `didWriteData`. `nonisolated` + `@unchecked Sendable`:
/// callbacks arrive on URLSession's serial delegate queue and the only mutable
/// state is guarded by a lock.
private nonisolated final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Double) -> Void
    private let lock = NSLock()
    private var lastReported = -1.0

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = min(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 1)
        // Throttle to ~0.5 % steps so we don't flood the main actor.
        lock.lock()
        let report = fraction - lastReported >= 0.005 || fraction >= 1
        if report { lastReported = fraction }
        lock.unlock()
        if report { onProgress(fraction) }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // No-op: the async download variant moves the file and returns its URL.
    }
}
