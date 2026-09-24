import SwiftUI

/// Navigation-value marker for pushing the hifz surah list from `HomeView`'s
/// `NavigationStack` — a tiny `Hashable` route, same pattern as `ReaderEntry`.
struct HifzListRoute: Hashable, Sendable {}

/// Kid-friendly "which surah do you want to memorize" screen: every surah the
/// catalog resolved, as a big card — Arabic name, localized name, ayah count
/// (or the Baqara excerpt's "1–5-oyat · Boshlanishi"), a "Yodladim"
/// checkmark and a big play button that opens the reader with that surah's
/// hifz session already running. A "listen to all in order" button up top
/// starts a continuous session from the very first unit in the whole book
/// (Fatiha's isti'adha). The list shows in Mushaf order by default; a small
/// switch can show it from An-Nas instead (display only — playback is always
/// Qurʼan order).
struct HifzSurahListView: View {
    @Environment(ContentStore.self) private var store
    @Environment(ProgressStore.self) private var progress
    @Environment(SettingsStore.self) private var settings
    @Environment(\.layoutMetrics) private var layoutMetrics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Most children start memorizing from An-Nas, the last card in Mushaf
    /// order — this only flips the order the cards are shown in.
    @AppStorage("ms.hifzListFromNas") private var listFromNas = false
    /// Lets the iPad's fixed 46 pt title grow with Dynamic Type, like the
    /// system large title it replaces.
    @ScaledMetric(relativeTo: .largeTitle) private var titleScale: CGFloat = 1

    private var locale: AppLocale { settings.settings.locale }
    private var catalog: HifzCatalog { store.hifzCatalog }
    private var totalSurahs: Int { catalog.surahs.count }
    private var displayedSurahs: [HifzSurah] {
        listFromNas ? Array(catalog.surahs.reversed()) : catalog.surahs
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 340), spacing: 14 * layoutMetrics.uiScale)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18 * layoutMetrics.uiScale) {
                header
                listenAllButton
                orderSwitch
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 14 * layoutMetrics.uiScale) {
                    ForEach(displayedSurahs) { surah in
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
        .sensoryFeedback(.selection, trigger: listFromNas)
        // The title is drawn in the content column (see `header`), so the
        // bar keeps only the back button; the navigation title stays set so
        // the back-button history and VoiceOver still name this screen.
        .navigationTitle(store.t("hifz_list_title", locale))
        .navigationBarTitleDisplayMode(.inline)
        .modifier(HiddenBarTitle())
        .navigationDestination(for: HifzLaunch.self) { launch in
            ReaderView(entry: .global(index: launch.startGlobalIndex), hifzAutoStart: launch.plan)
        }
    }

    // MARK: - Header

    /// Title + "X/26 yodlandi", drawn inside the capped content column so on
    /// iPad the title lines up with the cards — same as Home / Contents /
    /// Settings (the system large title sat at the screen's own margin).
    private var header: some View {
        VStack(alignment: .leading, spacing: 4 * layoutMetrics.uiScale) {
            Text(store.t("hifz_list_title", locale))
                .font(layoutMetrics.font(.largeTitle.bold(), .system(size: 46 * titleScale, weight: .bold)))
                .foregroundStyle(AppColor.textMain)
                .accessibilityAddTraits(.isHeader)
            Text(memorizedSummary)
                .font(layoutMetrics.font(.subheadline, .title2))
                .foregroundStyle(AppColor.textMuted)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var memorizedSummary: String {
        String(format: store.t("hifz_memorized_count", locale), "\(progress.memorizedCount)", "\(totalSurahs)")
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

    // MARK: - Order switch

    /// Two small segments that only change the order the cards are shown in.
    /// "Listen to all" and every surah's own playback stay in Qurʼan order
    /// either way. Side by side when both labels fit; stacked when they
    /// don't (very large Dynamic Type on a phone).
    private var orderSwitch: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4 * layoutMetrics.uiScale) {
                orderSegment(fromNas: false, titleKey: "hifz_order_mushaf", stretch: false)
                orderSegment(fromNas: true, titleKey: "hifz_order_from_nas", stretch: false)
            }
            .fixedSize()
            VStack(spacing: 4 * layoutMetrics.uiScale) {
                orderSegment(fromNas: false, titleKey: "hifz_order_mushaf", stretch: true)
                orderSegment(fromNas: true, titleKey: "hifz_order_from_nas", stretch: true)
            }
        }
        .padding(4 * layoutMetrics.uiScale)
        .background(
            AppColor.surface,
            in: RoundedRectangle(cornerRadius: 26 * layoutMetrics.uiScale, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }

    private func orderSegment(fromNas: Bool, titleKey: String, stretch: Bool) -> some View {
        let isSelected = listFromNas == fromNas
        let shape = RoundedRectangle(cornerRadius: 22 * layoutMetrics.uiScale, style: .continuous)
        return Button {
            withAnimation(reduceMotion ? nil : .snappy) { listFromNas = fromNas }
        } label: {
            Text(store.t(titleKey, locale))
                .font(layoutMetrics.font(.subheadline.weight(.semibold), .title3.weight(.semibold)))
                .multilineTextAlignment(.center)
                // Dark green, not `primary`: primary text on its own tint
                // falls under 3:1.
                .foregroundStyle(isSelected ? AppColor.textSecondary : AppColor.textMuted)
                .padding(.horizontal, 16 * layoutMetrics.uiScale)
                .padding(.vertical, 6 * layoutMetrics.uiScale)
                .frame(maxWidth: stretch ? .infinity : nil, minHeight: 44 * layoutMetrics.uiScale)
                .background(isSelected ? AppColor.primary.opacity(0.15) : Color.clear, in: shape)
                .overlay(shape.strokeBorder(isSelected ? AppColor.primary.opacity(0.35) : Color.clear, lineWidth: 1))
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Keeps the navigation title set (back-button history, VoiceOver) while
/// the bar itself doesn't draw it. iOS 17 has no `toolbar(removing: .title)`,
/// so an empty principal item takes the title's place there.
private struct HiddenBarTitle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.toolbar(removing: .title)
        } else {
            content.toolbar {
                ToolbarItem(placement: .principal) {
                    Color.clear.frame(width: 1, height: 1)
                }
            }
        }
    }
}

// MARK: - Card surface

/// The look Liquid Glass gave the surah cards on this flat background (a
/// faint lift, a bright rim, a soft shadow in light mode), drawn with plain
/// fills: 26 live glass cards re-sampled the backdrop on every scrolled frame.
private struct SurahCardSurface: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    /// The faint lift over the page background: white in light, grey in dark.
    private static let lift = Color(light: Color(white: 1, opacity: 0.3), dark: Color(white: 0.2, opacity: 0.28))
    private static let rim = Color(light: Color(white: 1, opacity: 0.9), dark: Color(white: 1, opacity: 0.12))
    private static let rimWidth: CGFloat = 0.5
    /// Light mode only: on the dark background a black shadow can't be seen.
    private static let lightShadow = ShadowStyle.drop(color: .black.opacity(0.1), radius: 16, y: 2)

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let shadow = colorScheme == .dark ? ShadowStyle.drop(color: .clear, radius: 0) : Self.lightShadow
        content.background {
            ZStack {
                // An opaque base in the page colour casts the shadow, so the
                // shadow never shows through the translucent lift above it.
                shape.fill(AppColor.background.shadow(shadow))
                shape.fill(Self.lift)
                // Increase Contrast gets the app's hairline border instead of the faint rim.
                shape.strokeBorder(contrast == .increased ? AppColor.divider : Self.rim, lineWidth: Self.rimWidth)
            }
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
    /// The Arabic name is a fixed-size custom font, so it grows with Dynamic
    /// Type through this instead — tracking `.title` keeps it larger than
    /// the localized name under it at every text size.
    @ScaledMetric(relativeTo: .title) private var titleScale: CGFloat = 1
    @ScaledMetric(relativeTo: .caption2) private var badgeScale: CGFloat = 1

    private var isMemorized: Bool { progress.isMemorized(surah.number) }
    private var surahName: String { surah.name.text(locale) }
    private var toggleSide: CGFloat { 44 * layoutMetrics.uiScale }
    private var playSide: CGFloat { 60 * layoutMetrics.uiScale }
    private var arabicNameSize: CGFloat { (layoutMetrics.isRegular ? 36 : 28) * titleScale }

    var body: some View {
        HStack(spacing: 14 * layoutMetrics.uiScale) {
            info
            memorizedToggle
            playButton
        }
        .padding(layoutMetrics.isRegular ? 20 : 14)
        // Fills the whole grid row, top-aligned, so two cards side by side
        // on iPad keep equal heights even when only one has the badge.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(SurahCardSurface(cornerRadius: 24))
    }

    // MARK: Static info (Arabic name, localized name, ayah count/range)

    private var info: some View {
        VStack(alignment: .leading, spacing: 4 * layoutMetrics.uiScale) {
            Text(surah.arabicName)
                .font(arabicFont(arabicNameSize))
                .foregroundStyle(AppColor.textMain)
                // One word: shrink a little rather than break it mid-word
                // when a huge text size meets a narrow card.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .environment(\.layoutDirection, .rightToLeft)
                // VoiceOver would try to sound out raw Arabic glyphs using
                // whatever language is active — hidden here, the localized
                // name below carries the spoken label instead.
                .accessibilityHidden(true)
            Text(surahName)
                .font(layoutMetrics.font(.subheadline.weight(.medium), .title3.weight(.medium)))
                .foregroundStyle(AppColor.textSecondary)
            ayahLine
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// The ayah text never wraps — a break inside "1–5-oyat" ("1–5-" /
    /// "oyat") misreads. When it and the "Boshlanishi" badge don't fit side
    /// by side at large Dynamic Type, the badge moves under it instead.
    private var ayahLine: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 6 * layoutMetrics.uiScale) {
                ayahLabel
                openingBadge
            }
            VStack(alignment: .leading, spacing: 4 * layoutMetrics.uiScale) {
                ayahLabel
                openingBadge
            }
        }
    }

    private var ayahLabel: some View {
        Text(ayahText)
            .font(layoutMetrics.font(.caption, .subheadline))
            .foregroundStyle(AppColor.textMuted)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    /// Dark green text on the light tint (about 5:1) — the old `primary`
    /// text on its own 14% tint was under 3:1.
    @ViewBuilder
    private var openingBadge: some View {
        if surah.isPartial {
            Text(store.t("hifz_opening_badge", locale))
                .font(.system(size: 11 * layoutMetrics.uiScale * badgeScale, weight: .semibold))
                .foregroundStyle(AppColor.textSecondary)
                .padding(.horizontal, 8 * layoutMetrics.uiScale)
                .padding(.vertical, 3 * layoutMetrics.uiScale)
                .background(AppColor.primary.opacity(0.14), in: Capsule())
                .fixedSize()
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
                .font(.system(size: min(20 * typeScale * layoutMetrics.uiScale, toggleSide * 0.6), weight: .semibold))
                .foregroundStyle(isMemorized ? AppColor.primary : AppColor.textMuted)
                .frame(width: toggleSide, height: toggleSide)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        // The surah name leads, so 26 rows don't all read the same
        // "Yodladim" in the VoiceOver rotor or Voice Control.
        .accessibilityLabel("\(surahName), \(store.t("hifz_mark_memorized", locale))")
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
                    .font(.system(size: min(24 * typeScale * layoutMetrics.uiScale, playSide * 0.5), weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: playSide, height: playSide)
                    .background(AppColor.primary, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(surahName), \(store.t("hifz_listen_surah", locale))")
        }
    }
}
