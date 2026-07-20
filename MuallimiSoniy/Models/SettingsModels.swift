import Foundation

/// User-adjustable preferences, persisted as JSON.
///
/// Defaults mirror `settings.json` → `defaults`.
nonisolated struct AppSettings: Codable, Sendable, Equatable {
    var repeatCount: Int
    var speed: Double
    var locale: AppLocale
    var theme: AppTheme
    var fontSize: FontSize
    var loopMode: Bool
    var sequentialMode: Bool

    /// Factory defaults matching the content package (`settings.json`).
    static let `default` = AppSettings(
        repeatCount: 1,
        speed: 1,
        locale: .uzLatn,
        theme: .light,
        fontSize: .medium,
        loopMode: false,
        sequentialMode: false
    )
}
