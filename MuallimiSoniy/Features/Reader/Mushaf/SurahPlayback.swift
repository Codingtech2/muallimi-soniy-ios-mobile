import SwiftUI

/// What the reader hands the surah banners on book pages 36–47: which surah is
/// being read start to end, how to start or stop one, and whether the one-time
/// "tap the surah name" hint still shows. Mirrors the web `SurahPlayContext`
/// (`SurahBanner.tsx`).
///
/// `nil` (the default) everywhere except `ReaderView` — a banner then draws as
/// a static heading and the hint never appears, so previews and the DEBUG
/// single-page host render exactly as before.
struct SurahPlaybackContext {
    /// The surah being read in full right now (its banner glows green), or `nil`.
    let playingSurah: Int?
    /// Whether the one-time hint still shows under the page's first banner.
    let showsHint: Bool
    /// "Tap the surah name to hear the whole surah" in the reader's language.
    let hintText: String
    /// "Got it" in the reader's language (the hint's button and its ✕ label).
    let hintDismissText: String
    /// "Listen to the surah" — VoiceOver hint on a banner that plays its surah.
    let playLabel: String
    /// "Stop" — VoiceOver hint on the banner of the surah that is playing.
    let stopLabel: String
    /// The surah's name in the reader's language ("Fotiha"), so VoiceOver
    /// never reads the Arabic heading glyphs with a Latin voice.
    let surahName: (_ number: Int) -> String?
    /// Plays surah `number` from start to end (onto the next page when it
    /// continues there), or stops it when it is the one playing. Closes the hint
    /// for good, since the learner has found the banner.
    let togglePlay: (_ number: Int) -> Void
    /// Closes the hint for good ("Got it" / ✕).
    let dismissHint: () -> Void
}

private struct SurahPlaybackKey: EnvironmentKey {
    static let defaultValue: SurahPlaybackContext? = nil
}

extension EnvironmentValues {
    /// The reader's surah playback + hint context, `nil` outside the reader.
    var surahPlayback: SurahPlaybackContext? {
        get { self[SurahPlaybackKey.self] }
        set { self[SurahPlaybackKey.self] = newValue }
    }
}
