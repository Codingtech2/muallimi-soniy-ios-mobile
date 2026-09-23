import SwiftUI

/// The "Yodlash" (memorize) settings sheet — picks a scope (one ayah, a whole
/// surah, or Qur'an order from here) and a few repeat/pause/speed options,
/// then hands a finished `HifzPlan` back to the reader. Modelled on
/// `ReadingOptionsSheet.swift`: a frosted header up top, plain rows on the
/// app background below, `.presentationDragIndicator(.visible)` here and
/// `.presentationDetents([.medium, .large])` at the `ReaderView` call site.
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

    @State private var scopeChoice: ScopeChoice
    @State private var selectedSurahNumber: Int
    @State private var eachAyah: HifzRepeat
    @State private var rounds: HifzRepeat
    @State private var pauseToRepeat = false

    private enum ScopeChoice: Hashable {
        case ayah, surah, continuous
    }

    private static let scopeButtonHeight: CGFloat = 56
    private static let chipSide: CGFloat = 48
    private static let startButtonHeight: CGFloat = 56
    private static let timesOptions: [HifzRepeat] = [.times(1), .times(3), .times(5), .times(10), .forever]
    private static let eachAyahOptions: [HifzRepeat] = [.times(1), .times(2), .times(3), .times(5)]

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
        .presentationDragIndicator(.visible)
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
    var hasHighlightedUnit: Bool {
        activeElementId.flatMap { catalog.unit(containing: $0) } != nil
    }

    // MARK: - Header

    var header: some View {
        HStack(alignment: .top) {
            Text(tr("hifz_title"))
                .font(.system(size: 18 * layoutMetrics.uiScale, weight: .bold))
                .foregroundStyle(AppColor.textMain)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15 * layoutMetrics.uiScale, weight: .semibold))
                    .foregroundStyle(AppColor.textMain)
                    .frame(width: 36 * layoutMetrics.uiScale, height: 36 * layoutMetrics.uiScale)
                    .glassCard(cornerRadius: 12)
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
            HStack(spacing: 10 * layoutMetrics.uiScale) {
                ForEach(surahsOnPage) { surah in
                    surahChip(surah)
                }
            }
        }
    }

    func surahChip(_ surah: HifzSurah) -> some View {
        let isSelected = surah.number == selectedSurahNumber
        return Button {
            selectedSurahNumber = surah.number
        } label: {
            Text(surah.name.text(locale))
                .font(.system(size: 15 * layoutMetrics.uiScale, weight: .semibold))
                .foregroundStyle(isSelected ? .white : AppColor.textMain)
                .padding(.horizontal, 16 * layoutMetrics.uiScale)
                .frame(minHeight: 44 * layoutMetrics.uiScale)
                .background(Capsule().fill(isSelected ? AppColor.primary : AppColor.surface))
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : AppColor.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Scope

    var scopeSection: some View {
        VStack(alignment: .leading, spacing: 12 * layoutMetrics.uiScale) {
            scopeButton(
                .ayah,
                title: tr("hifz_scope_ayah"),
                description: hasHighlightedUnit ? tr("hifz_scope_ayah_desc") : tr("hifz_tap_ayah_first")
            )
            scopeButton(.surah, title: tr("hifz_scope_surah"), description: tr("hifz_scope_surah_desc"))
            scopeButton(
                .continuous, title: tr("hifz_scope_continuous"), description: tr("hifz_scope_continuous_desc")
            )
        }
    }

    /// One big scope row. Selection, disabled state and icon are all derived
    /// from `choice` itself so every call site only supplies the text.
    private func scopeButton(_ choice: ScopeChoice, title: String, description: String) -> some View {
        let isSelected = scopeChoice == choice
        let isDisabled = choice == .ayah && !hasHighlightedUnit
        return Button {
            scopeChoice = choice
        } label: {
            HStack(spacing: 14 * layoutMetrics.uiScale) {
                Image(systemName: scopeIcon(choice))
                    .font(.system(size: 22 * layoutMetrics.uiScale, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : AppColor.primary)
                    .frame(width: 30 * layoutMetrics.uiScale)
                VStack(alignment: .leading, spacing: 2 * layoutMetrics.uiScale) {
                    Text(title)
                        .font(.system(size: 16 * layoutMetrics.uiScale, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : AppColor.textMain)
                    Text(description)
                        .font(.system(size: 12 * layoutMetrics.uiScale))
                        .foregroundStyle(isSelected ? .white.opacity(0.85) : AppColor.textMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20 * layoutMetrics.uiScale))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 16 * layoutMetrics.uiScale)
            .frame(minHeight: Self.scopeButtonHeight * layoutMetrics.uiScale)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AppColor.primary : AppColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : AppColor.divider, lineWidth: 1)
            )
            .opacity(isDisabled ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityHint(description)
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

    @ViewBuilder
    var repeatSection: some View {
        VStack(alignment: .leading, spacing: 20 * layoutMetrics.uiScale) {
            if scopeChoice == .ayah {
                chipRow(title: tr("hifz_times"), options: Self.timesOptions, selection: eachAyah) { eachAyah = $0 }
            } else {
                chipRow(title: tr("hifz_times"), options: Self.timesOptions, selection: rounds) { rounds = $0 }
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
            HStack(spacing: 10 * layoutMetrics.uiScale) {
                ForEach(options, id: \.self) { option in
                    repeatChip(option, isSelected: option == selection) { onSelect(option) }
                }
            }
        }
    }

    func repeatChip(_ value: HifzRepeat, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let side = Self.chipSide * layoutMetrics.uiScale
        return Button(action: action) {
            Text(chipLabel(value))
                .font(.system(size: 16 * layoutMetrics.uiScale, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(isSelected ? .white : AppColor.textMain)
                .frame(minWidth: side, minHeight: side)
                .padding(.horizontal, 6 * layoutMetrics.uiScale)
                .background(Capsule().fill(isSelected ? AppColor.primary : AppColor.surface))
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : AppColor.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chipAccessibilityLabel(value))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    func chipLabel(_ value: HifzRepeat) -> String {
        switch value {
        case .times(let count): return "\(count)"
        case .forever: return "∞"
        }
    }

    func chipAccessibilityLabel(_ value: HifzRepeat) -> String {
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
            HStack(spacing: 10 * layoutMetrics.uiScale) {
                speedChip(0.75)
                speedChip(1.0)
            }
        }
    }

    func speedChip(_ value: Double) -> some View {
        let isSelected = abs(preferences.settings.speed - value) < 0.01
        return Button {
            preferences.setSpeed(value)
        } label: {
            Text(String(format: "%g×", value))
                .font(.system(size: 15 * layoutMetrics.uiScale, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : AppColor.textMain)
                .frame(minWidth: 64 * layoutMetrics.uiScale, minHeight: Self.chipSide * layoutMetrics.uiScale)
                .background(Capsule().fill(isSelected ? AppColor.primary : AppColor.surface))
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : AppColor.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: "%g×", value))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                    .font(.system(size: 17 * layoutMetrics.uiScale, weight: .bold))
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
            return HifzPlan(
                scope: .continuous(fromUnitID: anchor), eachAyah: eachAyah, rounds: rounds,
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
                .presentationDetents([.medium, .large])
                .environment(ContentStore())
                .environment(SettingsStore())
        }
}
#endif
