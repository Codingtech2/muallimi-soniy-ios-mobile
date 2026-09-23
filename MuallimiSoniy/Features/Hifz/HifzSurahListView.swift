import SwiftUI

/// Navigation-value marker for pushing the hifz surah list from `HomeView`'s
/// `NavigationStack` — a tiny `Hashable` route, same pattern as `ReaderEntry`.
struct HifzListRoute: Hashable, Sendable {}

/// Kid-friendly "which surah do you want to memorize" screen: every surah the
/// catalog resolved, in Mushaf order, as a big card — Arabic name, localized
/// name, ayah count (or the Baqara excerpt's "1–5-oyat · Boshlanishi"), a
/// "Yodladim" checkmark and a big play button that opens the reader with that
/// surah's hifz session already running. A "listen to all in order" button up
/// top starts a continuous session from the very first unit in the whole
/// book (Fatiha's isti'adha).
struct HifzSurahListView: View {
    @Environment(ContentStore.self) private var store
    @Environment(ProgressStore.self) private var progress
    @Environment(SettingsStore.self) private var settings
    @Environment(\.layoutMetrics) private var layoutMetrics

    private var locale: AppLocale { settings.settings.locale }
    private var catalog: HifzCatalog { store.hifzCatalog }
    private var totalSurahs: Int { catalog.surahs.count }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 340), spacing: 14 * layoutMetrics.uiScale)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18 * layoutMetrics.uiScale) {
                summary
                listenAllButton
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 14 * layoutMetrics.uiScale) {
                    ForEach(catalog.surahs) { surah in
                        HifzSurahRow(surah: surah, store: store, progress: progress, locale: locale)
                    }
                }
            }
            .padding(.horizontal, 20 * layoutMetrics.uiScale)
            .padding(.top, 8 * layoutMetrics.uiScale)
            .padding(.bottom, 24 * layoutMetrics.uiScale)
            .frame(maxWidth: layoutMetrics.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle(store.t("hifz_list_title", locale))
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: HifzLaunch.self) { launch in
            ReaderView(entry: .global(index: launch.startGlobalIndex), hifzAutoStart: launch.plan)
        }
    }

    // MARK: - Summary

    private var summary: some View {
        Text(String(format: store.t("hifz_memorized_count", locale), "\(progress.memorizedCount)", "\(totalSurahs)"))
            .font(layoutMetrics.font(.subheadline, .title3))
            .foregroundStyle(AppColor.textMuted)
            .monospacedDigit()
    }

    // MARK: - Listen to all

    /// Continuous session starting at the very first unit in the whole book
    /// (Fatiha's isti'adha), so "listen to all" plays every surah in Qur'an
    /// order back to back. `@ViewBuilder` because there's nothing to link to
    /// until the catalog has resolved at least one unit — never crashes on
    /// an empty catalog, just doesn't show the button.
    @ViewBuilder
    private var listenAllButton: some View {
        if let firstUnit = catalog.surahs.first?.units.first {
            let launch = HifzLaunch(
                plan: .defaults(for: .continuous(fromUnitID: firstUnit.id)),
                startGlobalIndex: firstUnit.globalIndex
            )
            NavigationLink(value: launch) {
                HStack(spacing: 10 * layoutMetrics.uiScale) {
                    Image(systemName: "play.fill")
                    Text(store.t("hifz_listen_all", locale))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(layoutMetrics.font(.headline, .title2.weight(.semibold)))
                .foregroundStyle(.white)
                .padding(.vertical, 12 * layoutMetrics.uiScale)
                .frame(maxWidth: .infinity, minHeight: layoutMetrics.isRegular ? 68 : 56)
                // A plain rounded rect, not `Capsule()` — at huge Dynamic Type
                // the label wraps to 2-3 lines and a capsule's corner radius
                // (half its height) would curve straight into that wrapped
                // text and clip it.
                .background(AppColor.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.t("hifz_listen_all", locale))
        }
    }
}

// MARK: - Surah row

/// One surah card: Arabic name (large, RTL), localized name, ayah count, a
/// memorize checkmark and a big play button.
///
/// VoiceOver reads the localized name + ayah info as one combined stop —
/// never the raw Arabic glyphs (same "prefer the transliteration" rule as
/// `Element.accessibilityLabelText`, so a screen reader never tries to sound
/// out Arabic script in the wrong language). The checkmark and play button
/// stay separate, independently focusable stops since each needs its own
/// label/value.
private struct HifzSurahRow: View {
    let surah: HifzSurah
    let store: ContentStore
    let progress: ProgressStore
    let locale: AppLocale

    @Environment(\.layoutMetrics) private var layoutMetrics
    /// Lets the two fixed-diameter circle buttons' glyphs grow a little with
    /// Dynamic Type, capped so they never spill past their own circle — same
    /// technique as `ReaderControlBar`.
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    private var isMemorized: Bool { progress.isMemorized(surah.number) }
    private var toggleSide: CGFloat { 44 * layoutMetrics.uiScale }
    private var playSide: CGFloat { 60 * layoutMetrics.uiScale }
    private var arabicNameSize: CGFloat { layoutMetrics.isRegular ? 36 : 28 }

    var body: some View {
        HStack(spacing: 14 * layoutMetrics.uiScale) {
            info
            memorizedToggle
            playButton
        }
        .padding(layoutMetrics.isRegular ? 20 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }

    // MARK: Static info (Arabic name, localized name, ayah count/range)

    private var info: some View {
        VStack(alignment: .leading, spacing: 4 * layoutMetrics.uiScale) {
            Text(surah.arabicName)
                .font(arabicFont(arabicNameSize))
                .foregroundStyle(AppColor.textMain)
                .environment(\.layoutDirection, .rightToLeft)
                // VoiceOver would try to sound out raw Arabic glyphs using
                // whatever language is active — hidden here, the localized
                // name below carries the spoken label instead.
                .accessibilityHidden(true)
            Text(surah.name.text(locale))
                .font(layoutMetrics.font(.subheadline.weight(.medium), .title3.weight(.medium)))
                .foregroundStyle(AppColor.textSecondary)
            ayahLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// `.top`-aligned with `.fixedSize` on the ayah text: at very large
    /// Dynamic Type "1–5-oyat" wraps to 2 lines next to the "Boshlanishi"
    /// badge, and without these the wrapped text under-reports its own
    /// height, letting the badge clip into the row below.
    private var ayahLine: some View {
        HStack(alignment: .top, spacing: 6 * layoutMetrics.uiScale) {
            Text(ayahText)
                .font(layoutMetrics.font(.caption, .subheadline))
                .foregroundStyle(AppColor.textMuted)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            if surah.isPartial {
                Text(store.t("hifz_opening_badge", locale))
                    .font(.system(size: 11 * layoutMetrics.uiScale, weight: .semibold))
                    .foregroundStyle(AppColor.primary)
                    .padding(.horizontal, 8 * layoutMetrics.uiScale)
                    .padding(.vertical, 3 * layoutMetrics.uiScale)
                    .background(AppColor.primary.opacity(0.14), in: Capsule())
                    .fixedSize()
            }
        }
    }

    /// Baqara shows as an ayah range ("1–5-oyat") — the book only carries its
    /// opening excerpt, never labelled a whole surah (product rule).
    private var ayahText: String {
        surah.isPartial
            ? String(format: store.t("hifz_ayah_range", locale), "1", "\(surah.ayahCount)")
            : String(format: store.t("hifz_ayah_count", locale), "\(surah.ayahCount)")
    }

    // MARK: Memorized toggle

    private var memorizedToggle: some View {
        Button {
            progress.setMemorized(surah.number, !isMemorized)
        } label: {
            Image(systemName: isMemorized ? "checkmark.circle.fill" : "circle")
                .font(.system(size: min(20 * typeScale, toggleSide * 0.6), weight: .semibold))
                .foregroundStyle(isMemorized ? AppColor.primary : AppColor.textMuted)
                .frame(width: toggleSide, height: toggleSide)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.t("hifz_mark_memorized", locale))
        .accessibilityValue(store.t(isMemorized ? "hifz_memorized_yes" : "hifz_memorized_no", locale))
        .accessibilityAddTraits(isMemorized ? .isSelected : [])
    }

    // MARK: Play button

    /// `@ViewBuilder` because `HifzSurah.startGlobalIndex` is optional (a
    /// surah with zero resolved units "should never happen" per
    /// `HifzCatalog.build`, but the type stays honest) — degrades to nothing
    /// instead of force-unwrapping.
    @ViewBuilder
    private var playButton: some View {
        if let startIndex = surah.startGlobalIndex {
            let launch = HifzLaunch(
                plan: .defaults(for: .surah(number: surah.number)),
                startGlobalIndex: startIndex
            )
            NavigationLink(value: launch) {
                Image(systemName: "play.fill")
                    .font(.system(size: min(24 * typeScale, playSide * 0.5), weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: playSide, height: playSide)
                    .background(AppColor.primary, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.t("hifz_listen_surah", locale))
        }
    }
}
