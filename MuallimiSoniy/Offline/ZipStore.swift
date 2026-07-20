import Foundation

/// Minimal, memory-safe ZIP reader for **STORED** (compression method 0) archives.
///
/// The audio pack (`audio.zip`, ~127 MB, 1757 entries) is built with no
/// compression, so a full inflate implementation is unnecessary — every entry's
/// bytes sit verbatim in the file and are copied straight to disk. Nothing is
/// ever buffered whole in RAM: the archive is read through a single `FileHandle`
/// (central directory + each local header + 1 MB data chunks), and each entry is
/// streamed to its destination file.
///
/// `nonisolated` so the downloader can run it on a background task without
/// touching the main actor. Any malformed offset / signature throws a clear
/// `ZipError` instead of crashing.
nonisolated enum ZipStore {

    /// Data is copied in 1 MB blocks so peak memory stays flat regardless of
    /// the archive or entry size.
    private static let copyChunkSize = 1_048_576

    /// The EOCD record lives in the last 22 + comment bytes; the comment is at
    /// most 65535, so scanning the final ~64 KB always finds it.
    private static let eocdSearchWindow = 66_000

    // MARK: - Public API

    /// Extracts every STORED file entry of `zipURL` into `destDir`, recreating
    /// the archive's folder structure. `progress` is called after each file with
    /// the fraction of file entries completed (0…1).
    ///
    /// - Throws: `ZipError` for a missing EOCD, a malformed header/offset, a
    ///   non-STORED entry (named), or truncated data.
    static func extract(zipURL: URL, to destDir: URL, progress: (Double) -> Void) throws {
        guard let handle = try? FileHandle(forReadingFrom: zipURL) else {
            throw ZipError.cannotOpen(zipURL)
        }
        defer { try? handle.close() }

        let fileSize = try handle.seekToEnd()
        let directory = try readCentralDirectory(handle: handle, fileSize: fileSize)

        let total = directory.count
        guard total > 0 else { progress(1); return }

        let baseDir = destDir.standardizedFileURL.path
        for (index, entry) in directory.enumerated() {
            try extractEntry(entry, handle: handle, destDir: destDir, baseDir: baseDir)
            progress(Double(index + 1) / Double(total))
        }
    }

    // MARK: - Central directory

    /// One STORED file entry, resolved from the central directory.
    private struct Entry {
        let name: String
        let compressedSize: UInt64
        let localHeaderOffset: UInt64
    }

    private static func readCentralDirectory(handle: FileHandle, fileSize: UInt64) throws -> [Entry] {
        // 1. Locate the End Of Central Directory record by scanning the tail.
        let windowLength = Int(min(fileSize, UInt64(eocdSearchWindow)))
        let windowStart = fileSize - UInt64(windowLength)
        let tail = [UInt8](try readExact(handle, at: windowStart, count: windowLength))

        var eocd = -1
        var i = tail.count - 22
        while i >= 0 {
            if tail[i] == 0x50, tail[i + 1] == 0x4b, tail[i + 2] == 0x05, tail[i + 3] == 0x06 {
                // Validate: the record must end exactly at EOF (comment length fits).
                let commentLength = u16(tail, i + 20)
                if i + 22 + commentLength == tail.count {
                    eocd = i
                    break
                }
            }
            i -= 1
        }
        guard eocd >= 0 else { throw ZipError.endOfCentralDirectoryNotFound }

        let entryCount = u16(tail, eocd + 10)
        let cdSize = Int(u32(tail, eocd + 12))
        let cdOffset = u32(tail, eocd + 16)
        guard cdOffset + UInt64(cdSize) <= fileSize else {
            throw ZipError.malformedCentralDirectory
        }

        // 2. Read the whole central directory (small — a few hundred KB) and parse.
        let cd = [UInt8](try readExact(handle, at: cdOffset, count: cdSize))
        var entries: [Entry] = []
        entries.reserveCapacity(entryCount)

        var p = 0
        while p + 46 <= cd.count && entries.count < entryCount {
            guard cd[p] == 0x50, cd[p + 1] == 0x4b, cd[p + 2] == 0x01, cd[p + 3] == 0x02 else {
                throw ZipError.malformedCentralDirectory
            }
            let method = u16(cd, p + 10)
            let compressedSize = u32(cd, p + 20)
            let nameLength = u16(cd, p + 28)
            let extraLength = u16(cd, p + 30)
            let commentLength = u16(cd, p + 32)
            let localOffset = u32(cd, p + 42)

            let nameStart = p + 46
            guard nameStart + nameLength <= cd.count else {
                throw ZipError.malformedCentralDirectory
            }
            let name = String(decoding: cd[nameStart ..< nameStart + nameLength], as: UTF8.self)

            // Skip directory entries (they carry no data); create dirs on demand.
            if !name.hasSuffix("/") {
                guard method == 0 else { throw ZipError.unsupportedCompression(entry: name) }
                entries.append(Entry(
                    name: name,
                    compressedSize: compressedSize,
                    localHeaderOffset: localOffset
                ))
            }
            p = nameStart + nameLength + extraLength + commentLength
        }
        return entries
    }

    // MARK: - Single entry

    private static func extractEntry(
        _ entry: Entry,
        handle: FileHandle,
        destDir: URL,
        baseDir: String
    ) throws {
        // The local header repeats the name/extra lengths, and they can differ
        // from the central-directory ones — read them from the local header.
        let local = [UInt8](try readExact(handle, at: entry.localHeaderOffset, count: 30))
        guard local[0] == 0x50, local[1] == 0x4b, local[2] == 0x03, local[3] == 0x04 else {
            throw ZipError.malformedLocalHeader(entry: entry.name)
        }
        let localNameLength = u16(local, 26)
        let localExtraLength = u16(local, 28)
        let dataOffset = entry.localHeaderOffset + 30 + UInt64(localNameLength) + UInt64(localExtraLength)

        // Resolve the destination and guard against zip-slip (`../` escapes).
        let destURL = destDir.appending(path: entry.name)
        let destPath = destURL.standardizedFileURL.path
        guard destPath == baseDir || destPath.hasPrefix(baseDir + "/") else {
            throw ZipError.unsafeEntry(entry: entry.name)
        }

        try FileManager.default.createDirectory(
            at: destURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard FileManager.default.createFile(atPath: destURL.path, contents: nil),
              let output = try? FileHandle(forWritingTo: destURL) else {
            throw ZipError.cannotWrite(entry: entry.name)
        }
        defer { try? output.close() }

        // Copy exactly `compressedSize` raw bytes in bounded chunks.
        try handle.seek(toOffset: dataOffset)
        var remaining = Int(entry.compressedSize)
        while remaining > 0 {
            let want = min(copyChunkSize, remaining)
            let chunk = try autoreleasepool { try handle.read(upToCount: want) }
            guard let chunk, !chunk.isEmpty else {
                throw ZipError.truncatedData(entry: entry.name)
            }
            try output.write(contentsOf: chunk)
            remaining -= chunk.count
        }
    }

    // MARK: - Byte helpers

    /// Reads exactly `count` bytes starting at `offset`, looping over short reads.
    private static func readExact(_ handle: FileHandle, at offset: UInt64, count: Int) throws -> Data {
        try handle.seek(toOffset: offset)
        var data = Data()
        data.reserveCapacity(count)
        var remaining = count
        while remaining > 0 {
            guard let chunk = try handle.read(upToCount: remaining), !chunk.isEmpty else { break }
            data.append(chunk)
            remaining -= chunk.count
        }
        guard data.count == count else { throw ZipError.truncated }
        return data
    }

    private static func u16(_ bytes: [UInt8], _ i: Int) -> Int {
        Int(bytes[i]) | (Int(bytes[i + 1]) << 8)
    }

    private static func u32(_ bytes: [UInt8], _ i: Int) -> UInt64 {
        UInt64(bytes[i])
            | (UInt64(bytes[i + 1]) << 8)
            | (UInt64(bytes[i + 2]) << 16)
            | (UInt64(bytes[i + 3]) << 24)
    }
}

/// Errors surfaced by `ZipStore` so the downloader can report a clear failure.
nonisolated enum ZipError: LocalizedError {
    case cannotOpen(URL)
    case endOfCentralDirectoryNotFound
    case malformedCentralDirectory
    case malformedLocalHeader(entry: String)
    case unsupportedCompression(entry: String)
    case unsafeEntry(entry: String)
    case truncated
    case truncatedData(entry: String)
    case cannotWrite(entry: String)

    var errorDescription: String? {
        switch self {
        case .cannotOpen(let url):
            return "Could not open the archive at \(url.lastPathComponent)."
        case .endOfCentralDirectoryNotFound:
            return "The archive is not a valid ZIP (no end-of-central-directory record)."
        case .malformedCentralDirectory:
            return "The archive's central directory is malformed."
        case .malformedLocalHeader(let entry):
            return "Malformed local header for \(entry)."
        case .unsupportedCompression(let entry):
            return "\(entry) is compressed; only STORED (uncompressed) entries are supported."
        case .unsafeEntry(let entry):
            return "Refusing to extract \(entry): it escapes the destination folder."
        case .truncated:
            return "The archive ended unexpectedly while reading its directory."
        case .truncatedData(let entry):
            return "The archive ended unexpectedly while reading \(entry)."
        case .cannotWrite(let entry):
            return "Could not write \(entry) to disk."
        }
    }
}
