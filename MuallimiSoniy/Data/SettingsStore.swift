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

    /// Loads persisted settings, falling back — on a fresh install or an
    /// unreadable store — to `fallback` when the caller supplies one, otherwise
    /// to the factory defaults decoded from the bundled `settings.json`
    /// (`bundledDefaultSettings()`). `repeatCount` is then forced to 1× (the
    /// session-only rule) regardless of where the base came from.
    init(userDefaults: UserDefaults = .standard, fallback: AppSettings? = nil) {
        self.userDefaults = userDefaults
        let base = fallback ?? Self.bundledDefaultSettings()
        var loaded = Self.loadPersisted(from: userDefaults, fallback: base)
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
        return merged(stored, over: fallback)
    }

    /// Factory defaults for a **fresh install**, decoded leniently from the
    /// bundled `settings.json` → `defaults` block and layered over
    /// `AppSettings.default`.
    ///
    /// Any missing field (e.g. `volume`, which the content package omits) or an
    /// unrecognised enum raw value (a `theme` this build doesn't know) keeps the
    /// compiled default — so an unknown theme resolves to **light**, and a
    /// malformed or absent file degrades to `AppSettings.default` instead of
    /// throwing. `nonisolated` + pure so the settings store and `ContentStore`
    /// share this one decode path and never diverge.
    nonisolated static func bundledDefaultSettings() -> AppSettings {
        let base = AppSettings.default
        guard let url = Bundle.main.url(forResource: "settings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode(RawDefaults.self, from: data),
              let stored = raw.defaults
        else {
            return base
        }
        return merged(stored, over: base)
    }

    /// Layers the tolerant `stored` fields over `base`, keeping `base` wherever a
    /// field is absent or holds an unrecognised enum raw value.
    private nonisolated static func merged(
        _ stored: StoredSettings,
        over base: AppSettings
    ) -> AppSettings {
        AppSettings(
            repeatCount: stored.repeatCount ?? base.repeatCount,
            speed: stored.speed ?? base.speed,
            volume: stored.volume ?? base.volume,
            locale: stored.locale.flatMap(AppLocale.init(rawValue:)) ?? base.locale,
            theme: stored.theme.flatMap(AppTheme.init(rawValue:)) ?? base.theme,
            fontSize: stored.fontSize.flatMap(FontSize.init(rawValue:)) ?? base.fontSize,
            loopMode: stored.loopMode ?? base.loopMode,
            sequentialMode: stored.sequentialMode ?? base.sequentialMode
        )
    }
}

/// Lenient wrapper around `settings.json`; only the `defaults` block is read,
/// and every field is optional so a missing key never fails the whole decode.
private nonisolated struct RawDefaults: Decodable {
    var defaults: StoredSettings?
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
