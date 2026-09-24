import SwiftUI

/// The "Yodlash" (memorize) settings sheet — picks a scope (one ayah, a whole
/// surah, or Qur'an order from here) and a few repeat/pause/speed options,
/// then hands a finished `HifzPlan` back to the reader. Modelled on
/// `ReadingOptionsSheet.swift`: a frosted header up top, plain rows on the
/// app background below, `.presentationDragIndicator(.visible)`. Unlike that
/// sheet it sets its own detents (`HifzSheetSizing`): every option has to be
/// on screen before Start, so it opens at full height.
///
/// This view is intentionally dumb: it only builds a `HifzPlan` from its own
/// local state and calls `onStart`. Starting playback, dismissing the sheet
/// and everything else live in `ReaderView`.
struct HifzSheet: View {
    let catalog: HifzCatalog
    let pageGlobalIndex: Int
    let activeElementId: String?
    let onStart: (HifzPlan) -> Void

    @Environment(ContentStore.self) private var store
    @Environment(SettingsStore.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    @Environment(\.layoutMetrics) private var layoutMetrics
    /// Lets the few icon glyphs grow with Dynamic Type; every use caps it so a
    /// glyph never outgrows its slot (same technique as `ReaderControlBar`).
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    @State private var scopeChoice: ScopeChoice
    @State private var selectedSurahNumber: Int
    @State private var eachAyah: HifzRepeat
    @State private var rounds: HifzRepeat
    @State private var pauseToRepeat = false
    /// iPhone detent. Starts at `.large` on every presentation, so the repeat
    /// count, pause and speed are visible before Start.
    @State private var detent: PresentationDetent = .large

    private enum ScopeChoice: Hashable {
        case ayah, surah, continuous
    }

    private static let scopeButtonHeight: CGFloat = 56
    private static let chipSide: CGFloat = 48
    private static let startButtonHeight: CGFloat = 56
    private static let closeButtonSide: CGFloat = 44
    private static let disabledOpacity: CGFloat = 0.45
    private static let timesOptions: [HifzRepeat] = [.times(1), .times(3), .times(5), .times(10), .forever]
    private static let eachAyahOptions: [HifzRepeat] = [.times(1), .times(2), .times(3), .times(5)]
    /// Fill behind a selected option. Deeper than `AppColor.primary` on
    /// purpose: white text on the brand green is only ~3.3:1 (light) and
    /// ~2.3:1 (dark), under the 4.5:1 small text needs, while this green keeps
    /// white text at ~5:1 in both appearances.
    private static let selectedFill = Color(hex: "15803d")

    init(
        catalog: HifzCatalog,
        pageGlobalIndex: Int,
        activeElementId: String?,
        onStart: @escaping (HifzPlan) -> Void
    ) {
        self.catalog = catalog
        self.pageGlobalIndex = pageGlobalIndex
        self.activeElementId = activeElementId
        self.onStart = onStart

        let surahsOnPage = catalog.surahs(onGlobalPage: pageGlobalIndex)
        let highlightedSurahNumber = activeElementId.flatMap { catalog.surah(containing: $0)?.number }
        let initialSurahNumber = highlightedSurahNumber ?? surahsOnPage.first?.number ?? 0
        _selectedSurahNumber = State(initialValue: initialSurahNumber)

        let hasHighlight = activeElementId.flatMap { catalog.unit(containing: $0) } != nil
        let initialScope: ScopeChoice = hasHighlight ? .ayah : .surah
        _scopeChoice = State(initialValue: initialScope)

        let defaultScope: HifzScope = hasHighlight
            ? .ayah(unitID: activeElementId ?? "")
            : .surah(number: initialSurahNumber)
        let defaults = HifzPlan.defaults(for: defaultScope)
        _eachAyah = State(initialValue: defaults.eachAyah)
        _rounds = State(initialValue: defaults.rounds)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 24 * layoutMetrics.uiScale) {
                    if surahsOnPage.count > 1 {
                        surahPickerSection
                        sectionDivider
                    }
                    scopeSection
                    sectionDivider
                    repeatSection
                    sectionDivider
                    pauseSection
                    sectionDivider
                    speedSection
                }
                .padding(20 * layoutMetrics.uiScale)
            }
            startFooter
        }
        .background(AppColor.background.ignoresSafeArea())
        // Same Dynamic Type cap as the reader's control bar and hifz strip.
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .presentationDragIndicator(.visible)
        .modifier(HifzSheetSizing(isRegular: layoutMetrics.isRegular, detent: $detent))
        .onChange(of: scopeChoice) { _, newValue in
            applyDefaults(for: newValue)
        }
    }
}

/// Section views + small helpers, split from the main declaration purely to
/// keep the type body under SwiftLint's `type_body_length` — `private` still
/// grants full access to `HifzSheet`'s stored properties from any extension
/// in this same file, so this is a mechanical split, not a behavior change.
private extension HifzSheet {

    var locale: AppLocale { preferences.settings.locale }
    func tr(_ key: String) -> String { store.t(key, locale) }

    var surahsOnPage: [HifzSurah] { catalog.surahs(onGlobalPage: pageGlobalIndex) }
    var selectedSurah: HifzSurah? { catalog.surah(number: selectedSurahNumber) }
    var highlightedUnit: HifzUnit? { activeElementId.flatMap { catalog.unit(containing: $0) } }
    var hasHighlightedUnit: Bool { highlightedUnit != nil }

    // MARK: - Header

    var header: some View {
        HStack(alignment: .top) {
            Text(tr("hifz_title"))
                .font(layoutMetrics.font(.headline.weight(.bold), .title2.weight(.bold)))
                .foregroundStyle(AppColor.textMain)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: min(15 * typeScale, 20) * layoutMetrics.uiScale, weight: .semibold))
                    .foregroundStyle(AppColor.textMain)
                    .frame(width: 36 * layoutMetrics.uiScale, height: 36 * layoutMetrics.uiScale)
                    .glassCard(cornerRadius: 12)
                    // The same 36pt glass button as the reading-options sheet,
                    // inside a 44pt hit target.
                    .frame(
                        width: Self.closeButtonSide * layoutMetrics.uiScale,
                        height: Self.closeButtonSide * layoutMetrics.uiScale
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("close"))
        }
        .padding(.horizontal, 20 * layoutMetrics.uiScale)
        .padding(.top, 18 * layoutMetrics.uiScale)
        .padding(.bottom, 14 * layoutMetrics.uiScale)
        .background(.ultraThinMaterial)
    }

    // MARK: - Surah picker

    var surahPickerSection: some View {
        VStack(alignment: .leading, spacing: 14 * layoutMetrics.uiScale) {
            sectionTitle(tr("hifz_surah"))
            chipScroller {
                ForEach(surahsOnPage) { surah in
                    surahChip(surah)
                }
            }
        }
    }

    func surahChip(_ surah: HifzSurah) -> some View {
        let isSelected = surah.number == selectedSurahNumber
        let title = surahChipTitle(surah)
        let spokenLabel = "\(tr("hifz_surah")): \(title)"
        return Button {
            selectedSurahNumber = surah.number
        } label: {
            Text(title)
                .font(layoutMetrics.font(.subheadline.weight(.semibold), .title3.weight(.semibold)))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isSelected ? .white : AppColor.textMain)
                .padding(.horizontal, 16 * layoutMetrics.uiScale)
                .frame(minHeight: 44 * layoutMetrics.uiScale)
                .background(Capsule().fill(isSelected ? Self.selectedFill : AppColor.surface))
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : AppColor.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spokenLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The book only carries Baqara's opening ayat, so its chip names the
    /// range ("Baqara · 1–5-oyat") instead of passing for the whole surah.
    func surahChipTitle(_ surah: HifzSurah) -> String {
        let name = surah.name.text(locale)
        guard surah.isPartial else { return name }
        return "\(name) · \(String(format: tr("hifz_ayah_range"), "1", "\(surah.ayahCount)"))"
    }

    // MARK: - Scope

    var scopeSection: some View {
        VStack(alignment: .leading, spacing: 12 * layoutMetrics.uiScale) {
            scopeButton(.ayah, title: ayahScopeTitle, description: ayahScopeDescription)
            scopeButton(.surah, title: surahScopeTitle, description: surahScopeDescription)
            scopeButton(
                .continuous, title: tr("hifz_scope_continuous"), description: tr("hifz_scope_continuous_desc")
            )
        }
    }

    /// "Shu oyat" for an ayah. The isti'adha and a bismillah outside Fatiha
    /// aren't ayat, so they're offered under their own name, without the
    /// "only this ayah" line.
    var ayahScopeTitle: String {
        switch highlightedUnit?.role {
        case .taawwudh: return tr("hifz_taawwudh")
        case .bismillah: return tr("hifz_bismillah")
        case .ayah, nil: return tr("hifz_scope_ayah")
        }
    }

    var ayahScopeDescription: String? {
        guard let unit = highlightedUnit else { return tr("hifz_tap_ayah_first") }
        return unit.role == .ayah ? tr("hifz_scope_ayah_desc") : nil
    }

    /// Baqara's excerpt is offered as "this passage, ayat 1–5", never as a
    /// whole surah.
    var surahScopeTitle: String {
        selectedSurah?.isPartial == true ? tr("hifz_scope_excerpt") : tr("hifz_scope_surah")
    }

    var surahScopeDescription: String {
        guard let surah = selectedSurah, surah.isPartial else { return tr("hifz_scope_surah_desc") }
        return String(format: tr("hifz_scope_excerpt_desc"), "1", "\(surah.ayahCount)")
    }

    /// One big scope row. Selection, disabled state and icon are all derived
    /// from `choice` itself so every call site only supplies the text.
    private func scopeButton(_ choice: ScopeChoice, title: String, description: String?) -> some View {
        let isSelected = scopeChoice == choice
        let isDisabled = choice == .ayah && !hasHighlightedUnit
        // Disabled fades only the icon and title: the line under them is the
        // hint telling the user what to do first, so it stays readable.
        let fade = isDisabled ? Self.disabledOpacity : 1
        let iconSize = min(22 * typeScale, 30) * layoutMetrics.uiScale
        return Button {
            scopeChoice = choice
        } label: {
            HStack(spacing: 14 * layoutMetrics.uiScale) {
                Image(systemName: scopeIcon(choice))
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : AppColor.primary)
                    .frame(width: iconSize + 8 * layoutMetrics.uiScale)
                    .opacity(fade)
                VStack(alignment: .leading, spacing: 2 * layoutMetrics.uiScale) {
                    Text(title)
                        .font(layoutMetrics.font(.callout.weight(.semibold), .title3.weight(.semibold)))
                        .foregroundStyle(isSelected ? .white : AppColor.textMain)
                        .opacity(fade)
                    if let description {
                        Text(description)
                            .font(layoutMetrics.font(.footnote, .subheadline))
                            .foregroundStyle(isSelected ? .white : AppColor.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: min(20 * typeScale, 30) * layoutMetrics.uiScale))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16 * layoutMetrics.uiScale)
            .padding(.vertical, 6 * layoutMetrics.uiScale)
            .frame(minHeight: Self.scopeButtonHeight * layoutMetrics.uiScale)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Self.selectedFill : AppColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : AppColor.divider, lineWidth: 1)
            )
        }
        .buttonStyle(ScopeRowButtonStyle())
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityHint(description ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func scopeIcon(_ choice: ScopeChoice) -> String {
        switch choice {
        case .ayah: return "repeat.1"
        case .surah: return "repeat"
        case .continuous: return "arrow.right"
        }
    }

    // MARK: - Repeat chips

    var repeatSection: some View {
        VStack(alignment: .leading, spacing: 20 * layoutMetrics.uiScale) {
            switch scopeChoice {
            case .ayah:
                chipRow(title: tr("hifz_times"), options: Self.timesOptions, selection: eachAyah) { eachAyah = $0 }
            case .surah:
                chipRow(title: tr("hifz_times"), options: Self.timesOptions, selection: rounds) { rounds = $0 }
                chipRow(
                    title: tr("hifz_each_ayah"), options: Self.eachAyahOptions, selection: eachAyah
                ) { eachAyah = $0 }
            case .continuous:
                // Qur'an order plays through to An-Nas once and stops, so there
                // is no "how many times" to choose — only per-ayah repeats.
                chipRow(
                    title: tr("hifz_each_ayah"), options: Self.eachAyahOptions, selection: eachAyah
                ) { eachAyah = $0 }
            }
        }
    }

    func chipRow(
        title: String,
        options: [HifzRepeat],
        selection: HifzRepeat,
        onSelect: @escaping (HifzRepeat) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12 * layoutMetrics.uiScale) {
            sectionTitle(title)
            chipScroller {
                ForEach(options, id: \.self) { option in
                    repeatChip(option, rowTitle: title, isSelected: option == selection) { onSelect(option) }
                }
            }
        }
    }

    func repeatChip(
        _ value: HifzRepeat, rowTitle: String, isSelected: Bool, action: @escaping () -> Void
    ) -> some View {
        let side = Self.chipSide * layoutMetrics.uiScale
        // The row title keeps "3" in "How many times" and in "Each ayah" apart.
        let spokenLabel = "\(rowTitle): \(chipAccessibilityValue(value))"
        return Button(action: action) {
            Text(chipLabel(value))
                .font(layoutMetrics.font(
                    .system(.callout, design: .rounded, weight: .semibold).monospacedDigit(),
                    .system(.title3, design: .rounded, weight: .semibold).monospacedDigit()
                ))
                .foregroundStyle(isSelected ? .white : AppColor.textMain)
                .frame(minWidth: side, minHeight: side)
                .padding(.horizontal, 6 * layoutMetrics.uiScale)
                .background(Capsule().fill(isSelected ? Self.selectedFill : AppColor.surface))
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : AppColor.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spokenLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    func chipLabel(_ value: HifzRepeat) -> String {
        switch value {
        case .times(let count): return "\(count)"
        case .forever: return "∞"
        }
    }

    func chipAccessibilityValue(_ value: HifzRepeat) -> String {
        switch value {
        case .times(let count): return "\(count)"
        case .forever: return tr("hifz_forever")
        }
    }

    // MARK: - Pause to repeat

    var pauseSection: some View {
        Toggle(isOn: $pauseToRepeat) {
            VStack(alignment: .leading, spacing: 2 * layoutMetrics.uiScale) {
                Text(tr("hifz_pause"))
                    .font(layoutMetrics.font(.subheadline.weight(.semibold), .title3.weight(.semibold)))
                    .foregroundStyle(AppColor.textMain)
                Text(tr("hifz_pause_desc"))
                    .font(layoutMetrics.font(.caption, .subheadline))
                    .foregroundStyle(AppColor.textMuted)
            }
        }
        .tint(AppColor.primary)
    }

    // MARK: - Speed

    var speedSection: some View {
        VStack(alignment: .leading, spacing: 14 * layoutMetrics.uiScale) {
            sectionTitle(tr("speed"))
            chipScroller {
                speedChip(0.75)
                speedChip(1.0)
            }
        }
    }

    func speedChip(_ value: Double) -> some View {
        let isSelected = abs(preferences.settings.speed - value) < 0.01
        let label = speedLabel(value)
        let spokenLabel = "\(tr("speed")): \(label)"
        return Button {
            preferences.setSpeed(value)
        } label: {
            Text(label)
                .font(layoutMetrics.font(
                    .system(.subheadline, design: .rounded, weight: .semibold),
                    .system(.title3, design: .rounded, weight: .semibold)
                ))
                .foregroundStyle(isSelected ? .white : AppColor.textMain)
                .padding(.horizontal, 6 * layoutMetrics.uiScale)
                .frame(minWidth: 64 * layoutMetrics.uiScale, minHeight: Self.chipSide * layoutMetrics.uiScale)
                .background(Capsule().fill(isSelected ? Self.selectedFill : AppColor.surface))
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : AppColor.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spokenLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// "0.75×" in English, "0,75×" in Russian/Uzbek — the decimal separator
    /// follows the app's own language, not the device region.
    func speedLabel(_ value: Double) -> String {
        let number = value.formatted(
            .number.precision(.fractionLength(0...2)).locale(Locale(identifier: locale.appleLanguageCode))
        )
        return "\(number)×"
    }

    // MARK: - Start

    var startFooter: some View {
        let plan = buildPlan()
        return VStack(spacing: 0) {
            Rectangle().fill(AppColor.divider.opacity(0.5)).frame(height: 0.5)
            Button {
                if let plan { onStart(plan) }
            } label: {
                Text(tr("start"))
                    .font(layoutMetrics.font(.headline.weight(.bold), .title2.weight(.bold)))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: Self.startButtonHeight * layoutMetrics.uiScale)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppColor.primary))
                    .opacity(plan == nil ? 0.5 : 1)
            }
            .buttonStyle(.plain)
            .disabled(plan == nil)
            .padding(.horizontal, 20 * layoutMetrics.uiScale)
            .padding(.top, 14 * layoutMetrics.uiScale)
            .padding(.bottom, 10 * layoutMetrics.uiScale)
        }
        .background(AppColor.background)
    }

    // MARK: - Plan building

    /// Builds the plan the Start button would launch, or `nil` when the
    /// current selection can't resolve to a playable target (kept in sync
    /// with the scope buttons' own disabled states, so this should only be
    /// `nil` transiently — never crashes either way).
    func buildPlan() -> HifzPlan? {
        switch scopeChoice {
        case .ayah:
            guard let activeElementId, catalog.unit(containing: activeElementId) != nil else { return nil }
            return HifzPlan(
                scope: .ayah(unitID: activeElementId), eachAyah: eachAyah, rounds: .times(1),
                pauseToRepeat: pauseToRepeat
            )
        case .surah:
            guard catalog.surah(number: selectedSurahNumber) != nil else { return nil }
            return HifzPlan(
                scope: .surah(number: selectedSurahNumber), eachAyah: eachAyah, rounds: rounds,
                pauseToRepeat: pauseToRepeat
            )
        case .continuous:
            let anchor = activeElementId.flatMap { catalog.unit(containing: $0)?.id }
                ?? catalog.surah(number: selectedSurahNumber)?.units.first?.id
            guard let anchor else { return nil }
            // Always one pass: Qur'an order runs to An-Nas and never wraps back.
            return HifzPlan(
                scope: .continuous(fromUnitID: anchor), eachAyah: eachAyah, rounds: .times(1),
                pauseToRepeat: pauseToRepeat
            )
        }
    }

    /// Re-derives `eachAyah`/`rounds` from `HifzPlan.defaults(for:)` whenever
    /// the user switches scope, so leftover numbers from a previous scope
    /// (e.g. "each ayah 5×" from ayah scope) never leak into surah/continuous.
    private func applyDefaults(for choice: ScopeChoice) {
        let scope: HifzScope
        switch choice {
        case .ayah: scope = .ayah(unitID: activeElementId ?? "")
        case .surah: scope = .surah(number: selectedSurahNumber)
        case .continuous: scope = .continuous(fromUnitID: activeElementId ?? "")
        }
        let defaults = HifzPlan.defaults(for: scope)
        eachAyah = defaults.eachAyah
        rounds = defaults.rounds
    }

    // MARK: - Small pieces

    func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(layoutMetrics.font(.subheadline.weight(.semibold), .title3.weight(.semibold)))
            .foregroundStyle(AppColor.textMuted)
    }

    var sectionDivider: some View {
        Rectangle().fill(AppColor.divider.opacity(0.5)).frame(height: 0.5)
    }

    /// A row of option chips that scrolls sideways instead of squeezing or
    /// wrapping names when they don't fit (4 surahs in ru/en, large Dynamic
    /// Type). When they do fit it looks exactly like a plain row.
    func chipScroller<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10 * layoutMetrics.uiScale) {
                content()
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}

/// Looks like `.plain`, but without its automatic dimming of a disabled
/// button: that halved the whole scope row, so the "tap an ayah first" hint
/// dropped under 4.5:1. A disabled row fades only its own icon and title.
private struct ScopeRowButtonStyle: ButtonStyle {
    private static let pressedOpacity: CGFloat = 0.6

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? Self.pressedOpacity : 1)
    }
}

/// iPad (regular width) gets the full-height sheet only, at page size on iOS
/// 18+ — at the medium detent its form sheet showed little more than the
/// surah chips and Start. iPhone keeps both detents but opens at `.large`.
private struct HifzSheetSizing: ViewModifier {
    let isRegular: Bool
    @Binding var detent: PresentationDetent

    @ViewBuilder
    func body(content: Content) -> some View {
        if isRegular {
            if #available(iOS 18.0, *) {
                content
                    .presentationDetents([.large])
                    .presentationSizing(.page)
            } else {
                content.presentationDetents([.large])
            }
        } else {
            content.presentationDetents([.medium, .large], selection: $detent)
        }
    }
}

#if DEBUG
private struct HifzSheetPreview: View {
    @Environment(ContentStore.self) private var store
    var body: some View {
        HifzSheet(
            catalog: store.hifzCatalog,
            pageGlobalIndex: store.hifzCatalog.surahs.first?.startGlobalIndex ?? 0,
            activeElementId: nil,
            onStart: { _ in }
        )
    }
}

#Preview("HifzSheet") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            HifzSheetPreview()
                .environment(ContentStore())
                .environment(SettingsStore())
        }
}
#endif
