import Foundation
import OSLog

/// The mosques feature's log (OSLog category "Mosques").
nonisolated enum MosqueLog {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy", category: "Mosques")

    /// Logs a line that can give away where the user is (coordinates, the
    /// mosques around them, distances): readable in DEBUG builds for QA,
    /// redacted in release so a collected log never carries the location.
    static func nearUser(_ message: String) {
        #if DEBUG
        logger.info("\(message, privacy: .public)")
        #else
        logger.info("\(message, privacy: .private)")
        #endif
    }

    /// "41.31110,69.27970" — five decimals (~1 m) is plenty for a log line.
    static func describe(_ point: GeoPoint) -> String {
        String(format: "%.5f,%.5f", locale: Locale(identifier: "en_US_POSIX"), point.latitude, point.longitude)
    }
}
