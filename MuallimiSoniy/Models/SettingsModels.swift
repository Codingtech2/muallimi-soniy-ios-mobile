import Foundation

/// User-adjustable preferences, persisted as JSON.
///
/// Defaults mirror `settings.json` → `defaults`.
nonisolated struct AppSettings: Codable, Sendable, Equatable {
    var repeatCount: Int
    /// Playback speed multiplier (range 0.5…2.0). Persisted across launches.
    var speed: Double
    /// Output volume (range 0…1). Persisted across launches.
    var volume: Double
    var locale: AppLocale
    var theme: AppTheme
    var loopMode: Bool
    var sequentialMode: Bool

    // MARK: Reading options (reader "Aa" sheet)

    /// Global Arabic text-size multiplier (range 0.8…2.5). Replaces the old
    /// 3-step `FontSize` enum with a continuous slider.
    var textScale: Double
    /// Reader page/card background tint (paper / sepia / gray / night).
    var readingBackground: ReadingBackground
    /// Extra spacing between reader lines (range 1.0…2.0 multiplier).
    var lineSpacingScale: Double
    /// Renders reader Arabic text at a heavier weight for low-vision users.
    var boldText: Bool
    /// Renders the active tap-highlight pill with stronger contrast.
    var strongHighlight: Bool
    /// Disables the idle timer while the reader is open.
    var keepScreenAwake: Bool

    /// Factory defaults matching the content package (`settings.json`).
    static let `default` = AppSettings(
        repeatCount: 1,
        speed: 1,
        volume: 1,
        locale: .uzLatn,
        theme: .light,
        loopMode: false,
        sequentialMode: false,
        textScale: 1.0,
        readingBackground: .paper,
        lineSpacingScale: 1.0,
        boldText: false,
        strongHighlight: false,
        keepScreenAwake: false
    )
}
