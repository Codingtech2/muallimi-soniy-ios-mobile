import SwiftUI
import OSLog

/// A surah's name in the mushaf-style frame (`surahHeaderFrame`) at the start
/// of the surah — the port of the web `SurahBanner`. Tapping it reads the whole
/// surah (via `\.surahPlayback`); while that runs the band glows green.
struct SurahBanner: View {
    /// Qur'an surah number this banner opens (1, 2, 91…114).
    let surah: Int
    /// Arabic surah name drawn inside the frame.
    let text: String
    /// Small chig'atoy note under the frame, drawn in the book's own font.
    var sub: String?
    /// The page's first banner: the one-time hint shows under it.
    var carriesHint: Bool = false

    var body: some View {
        // Same `❀ name ❀` heading as the translation layout's `SurahTitle` —
        // the spec keeps the banner's look as it is.
        SurahBannerFrame(surah: surah, name: text, sub: sub, carriesHint: carriesHint) { isPlaying in
            SurahTitleLabel(text: text, isPlaying: isPlaying)
        }
    }
}

/// What every surah heading on book pages 36–47 shares — the mushaf view's
/// `SurahBanner` and the translation layout's headings alike (web
/// `SurahBanner` + `BannerFrame`): the double-ruled band, and inside the
/// reader one tap on it that reads the whole surah.
///
/// With no reader context (`\.surahPlayback == nil`: previews, the DEBUG
/// single-page host) or no `surah`, it draws `label(false)` in the plain band —
/// exactly the static heading of before. In the reader the band is one button
/// that calls `togglePlay(surah)`; while that surah plays the band turns green
/// and `label(true)` draws its text white. The page's first heading
/// (`carriesHint`) shows the one-time hint under it, outside the button, so a
/// tap on the hint never starts the surah.
struct SurahBannerFrame<Label: View>: View {
    /// The surah a tap reads, or `nil` for a heading that never plays.
    let surah: Int?
    /// The surah's name — what VoiceOver says for the banner.
    let name: String
    /// Small chig'atoy note under the band (mushaf view), in the book's font.
    var sub: String?
    /// The page's first surah heading: the one-time hint shows under it.
    var carriesHint = false
    /// The heading inside the band; `true` while its surah is playing.
    @ViewBuilder let label: (_ isPlaying: Bool) -> Label

    @Environment(\.surahPlayback) private var readerPlayback
    @Environment(\.readingTheme) private var readingTheme
    @Environment(\.verseFontScale) private var verseFontScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var playback: SurahPlaybackContext? { SurahBannerQA.resolve(readerPlayback) }

    private var isPlaying: Bool {
        guard let surah else { return false }
        return playback?.playingSurah == surah
    }

    /// Web: `hint && playable && ctx.surahHint`. Also hidden while this surah
    /// plays (▶ can start it too) — the hint has nothing to add then.
    private var showsHint: Bool {
        guard carriesHint, surah != nil, let playback, !isPlaying else { return false }
        return playback.showsHint
    }

    var body: some View {
        VStack(spacing: 0) {
            band
            if sub != nil || showsHint {
                underBand
            }
        }
    }

    @ViewBuilder
    private var band: some View {
        if let playback, let surah {
            Button { playback.togglePlay(surah) } label: {
                label(isPlaying)
                    .surahHeaderFrame(isActive: isPlaying)
                    // The margins around the band are tappable too, so the
                    // target is well over 44 pt tall.
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(reduceMotion ? nil : SurahBannerLayout.lightUp, value: isPlaying)
            .accessibilityLabel(playback.surahName(surah) ?? name)
            .accessibilityHint(isPlaying ? playback.stopLabel : playback.playLabel)
            .accessibilityAddTraits(
                isPlaying ? [.isHeader, .startsMediaSession, .isSelected] : [.isHeader, .startsMediaSession]
            )
        } else {
            label(false).surahHeaderFrame()
        }
    }

    /// The note and the hint, tucked up into the band's bottom margin so they
    /// read as part of the banner (web `mt-0.5` / `mt-2`); the margin comes
    /// back under them.
    private var underBand: some View {
        VStack(spacing: SurahBannerLayout.hintGap) {
            if let sub {
                subNote(sub)
            }
            if showsHint, let playback {
                SurahHintBubble(text: playback.hintText, dismissText: playback.hintDismissText) {
                    // Animated, so the page closes the gap smoothly.
                    withAnimation(reduceMotion ? nil : .easeOut(duration: SurahBannerLayout.closeSeconds)) {
                        playback.dismissHint()
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.top, SurahBannerLayout.underBandGap - SurahHeaderLayout.outerMargin)
        .padding(.bottom, SurahHeaderLayout.outerMargin)
    }

    private func subNote(_ sub: String) -> some View {
        Text(sub)
            // Always the book's own face: UthmanicHafs draws the ZWNJ in
            // "سوره‌سی" as a visible mark (web `.surah-sub`).
            .font(arabicFont(SurahBannerLayout.subSize * verseFontScale, weight: .regular, typeface: .naskh))
            .foregroundStyle(readingTheme.textMuted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .environment(\.layoutDirection, .rightToLeft)
    }
}

private enum SurahBannerLayout {
    /// Band (or note) to the hint's arrow tip; the arrow nearly touches it.
    static let underBandGap: CGFloat = 2
    /// Note to the hint's arrow tip (web `mt-2` minus the arrow).
    static let hintGap: CGFloat = 6
    /// Web `text-[0.625rem]`.
    static let subSize: CGFloat = 10
    static let closeSeconds: Double = 0.25
    /// The band lighting up / going out — the same spring as `TitleBanner`.
    static let lightUp = Animation.spring(response: 0.3, dampingFraction: 0.62)
}

// MARK: - QA hook

/// The context the banners act on: the reader's own, except in DEBUG runs
/// launched with `-MSSurahBanner <off|quiet|hint|playing:N>`, which swap in a
/// stand-in so screenshot QA can show the hint or a lit banner on any host —
/// also the single-page host, which has no reader — with no taps and no audio
/// pack. `off` = no context (static headings), `quiet` = tappable banners with
/// no hint and nothing playing, `hint` = hint up and nothing playing,
/// `playing:N` = hint up and surah N lit. The stand-in only logs taps
/// (category "SurahBanner"), so QA can check which control a tap reached.
enum SurahBannerQA {
    static func resolve(_ context: SurahPlaybackContext?) -> SurahPlaybackContext? {
        #if DEBUG
        guard let mode = launchMode else { return context }
        return standIn(mode, base: context)
        #else
        return context
        #endif
    }

    #if DEBUG
    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy",
        category: "SurahBanner"
    )

    private static let launchMode: String? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-MSSurahBanner"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }()

    private static func standIn(_ mode: String, base: SurahPlaybackContext?) -> SurahPlaybackContext? {
        guard mode != "off" else { return nil }
        let playingPrefix = "playing:"
        let playing = mode.hasPrefix(playingPrefix) ? Int(mode.dropFirst(playingPrefix.count)) : nil
        return SurahPlaybackContext(
            playingSurah: playing,
            showsHint: mode != "quiet",
            // The reader's own words when there is a reader, else the catalog.
            hintText: base?.hintText ?? String(localized: "surah_hint"),
            hintDismissText: base?.hintDismissText ?? String(localized: "surah_hint_ok"),
            playLabel: base?.playLabel ?? String(localized: "hifz_listen_surah"),
            stopLabel: base?.stopLabel ?? String(localized: "hifz_stop"),
            surahName: { base?.surahName($0) },
            togglePlay: { number in logger.notice("QA banner tapped: surah \(number, privacy: .public)") },
            dismissHint: { logger.notice("QA hint dismissed") }
        )
    }
    #endif
}

#if DEBUG
#Preview("SurahBanner") {
    let context = SurahPlaybackContext(
        playingSurah: 95,
        showsHint: true,
        hintText: String(localized: "surah_hint"),
        hintDismissText: String(localized: "surah_hint_ok"),
        playLabel: String(localized: "hifz_listen_surah"),
        stopLabel: String(localized: "hifz_stop"),
        surahName: { _ in nil },
        togglePlay: { _ in },
        dismissHint: {}
    )
    return VStack(spacing: 0) {
        SurahBanner(surah: 94, text: "سورة الشرح", sub: "شرح سوره‌سی", carriesHint: true)
        SurahBanner(surah: 95, text: "سورة التين", sub: "تین سوره‌سی")
        SurahBanner(surah: 1, text: "سُورَةُ الْفَاتِحَة")
    }
    .padding(24)
    .frame(width: 390)
    .background(AppColor.background)
    .environment(\.surahPlayback, context)
}
#endif
