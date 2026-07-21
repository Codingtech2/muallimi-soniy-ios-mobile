import Foundation
import SwiftUI
import OSLog

/// Owns the user's `AppSettings`, persisted as JSON in `UserDefaults`.
///
/// Mirrors the web `SettingsProvider` rules 1:1:
/// - Default appearance is **light**; a missing or unrecognised persisted theme
///   degrades to light (never dark, never a crash).
/// - `repeatCount` is **session-only**: changes apply during a run, but every
///   launch resets it to 1 (matches "Ilova qayta ochilganda 1× ga qaytadi").
/// - `locale` defaults to Uzbek-Latin, `fontSize` to medium.
@MainActor
@Observable
final class SettingsStore {
    /// The live settings. Read from views; mutate only via the `set*` methods.
    private(set) var settings: AppSettings

    /// SwiftUI appearance derived from `theme` (`nil` == follow the system).
    /// Handy for the integrator to feed into `.preferredColorScheme(_:)`.
    var preferredColorScheme: ColorScheme? {
        switch settings.theme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }

    /// Global Arabic type multiplier for the current font-size preference
    /// (small 0.875 / medium 1.0 / large 1.125). Fed to `\.arabicFontScale`.
    var arabicScale: CGFloat { settings.fontSize.arabicScale }

    private let userDefaults: UserDefaults
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy",
        category: "SettingsStore"
    )

    /// UserDefaults key holding the JSON-encoded `AppSettings`.
    private static let storageKey = "ms.settings"
    /// Repeat-count bounds (mirror the web −/+ stepper clamps).
    private static let repeatRange = 1...10
    /// Playback-speed bounds (AVAudioPlayer handles 0.5×–2× cleanly).
    private static let speedRange = 0.5...2.0
    /// Volume bounds.
    private static let volumeRange = 0.0...1.0

    init(userDefaults: UserDefaults = .standard, fallback: AppSettings = .default) {
        self.userDefaults = userDefaults
        var loaded = Self.loadPersisted(from: userDefaults, fallback: fallback)
        // Session-only: repeatCount never carries across launches — always 1×.
        loaded.repeatCount = Self.repeatRange.lowerBound
        settings = loaded
    }

    // MARK: - Setters (each persists immediately)

    func setLocale(_ locale: AppLocale) {
        settings.locale = locale
        persist()
    }

    func setTheme(_ theme: AppTheme) {
        settings.theme = theme
        persist()
    }

    func setFontSize(_ fontSize: FontSize) {
        settings.fontSize = fontSize
        persist()
    }

    /// Clamps to 1…10 before storing (session-only — resets to 1 next launch).
    func setRepeatCount(_ count: Int) {
        settings.repeatCount = min(
            Self.repeatRange.upperBound,
            max(Self.repeatRange.lowerBound, count)
        )
        persist()
    }

    func setLoopMode(_ isOn: Bool) {
        settings.loopMode = isOn
        persist()
    }

    /// Clamps to 0.5…2.0 before storing. Persisted across launches (unlike
    /// `repeatCount`, speed is *not* reset on relaunch).
    func setSpeed(_ speed: Double) {
        settings.speed = min(
            Self.speedRange.upperBound,
            max(Self.speedRange.lowerBound, speed)
        )
        persist()
    }

    /// Clamps to 0…1 before storing. Persisted across launches.
    func setVolume(_ volume: Double) {
        settings.volume = min(
            Self.volumeRange.upperBound,
            max(Self.volumeRange.lowerBound, volume)
        )
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults.set(data, forKey: Self.storageKey)
        } catch {
            logger.error("Failed to persist settings: \(String(describing: error))")
        }
    }

    /// Loads persisted settings leniently: any missing or unrecognised field
    /// (e.g. a theme this build doesn't know) falls back to `fallback`, so an
    /// unknown theme resolves to light rather than discarding the whole load.
    private static func loadPersisted(
        from defaults: UserDefaults,
        fallback: AppSettings
    ) -> AppSettings {
        guard let data = defaults.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode(StoredSettings.self, from: data)
        else {
            return fallback
        }
        return AppSettings(
            repeatCount: stored.repeatCount ?? fallback.repeatCount,
            speed: stored.speed ?? fallback.speed,
            volume: stored.volume ?? fallback.volume,
            locale: stored.locale.flatMap(AppLocale.init(rawValue:)) ?? fallback.locale,
            theme: stored.theme.flatMap(AppTheme.init(rawValue:)) ?? fallback.theme,
            fontSize: stored.fontSize.flatMap(FontSize.init(rawValue:)) ?? fallback.fontSize,
            loopMode: stored.loopMode ?? fallback.loopMode,
            sequentialMode: stored.sequentialMode ?? fallback.sequentialMode
        )
    }
}

/// All-optional mirror of `AppSettings` for tolerant decoding of persisted JSON:
/// a field this build can't parse becomes `nil` and falls back to the default.
private nonisolated struct StoredSettings: Decodable {
    var repeatCount: Int?
    var speed: Double?
    var volume: Double?
    var locale: String?
    var theme: String?
    var fontSize: String?
    var loopMode: Bool?
    var sequentialMode: Bool?
}
