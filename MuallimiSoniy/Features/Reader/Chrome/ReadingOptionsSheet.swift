import SwiftUI

/// The reader's "Aa" reading-options sheet — text size, background palette,
/// line spacing and a few low-vision toggles. Modelled on `TocSheet.swift`: a
/// frosted header up top, plain rows below on the app background (no nested
/// glass cards), `.presentationDragIndicator(.visible)` here and
/// `.presentationDetents([.medium, .large])` at the `ReaderView` call site so
/// the page stays visible behind the sheet at `.medium` — every control
/// writes straight through `SettingsStore`, so a change is felt live with no
/// "Apply" step.
///
/// Reads `ContentStore` + `SettingsStore` directly from the environment
/// (both are injected once at the app root and flow into presented sheets),
/// so `ReaderView`'s call site stays a bare `ReadingOptionsSheet()`.
struct ReadingOptionsSheet: View {
    @Environment(ContentStore.self) private var store
    @Environment(SettingsStore.self) private var preferences
    @Environment(\.dismiss) private var dismiss
    /// Inherited from the presenting `ReaderView` — `.sheet` content inherits
    /// the presenter's environment, so this reads the same live iPad/iPhone
    /// metrics with no extra plumbing.
    @Environment(\.layoutMetrics) private var layoutMetrics

    private var locale: AppLocale { preferences.settings.locale }
    private func tr(_ key: String) -> String { store.t(key, locale) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 24 * layoutMetrics.uiScale) {
                    textSizeSection
                    sectionDivider
                    backgroundSection
                    sectionDivider
                    lineSpacingSection
                    sectionDivider
                    togglesSection
                }
                .padding(20 * layoutMetrics.uiScale)
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            Text(tr("reading_options"))
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
            .accessibilityLabel(store.t("close", locale))
        }
        .padding(.horizontal, 20 * layoutMetrics.uiScale)
        .padding(.top, 18 * layoutMetrics.uiScale)
        .padding(.bottom, 14 * layoutMetrics.uiScale)
        .background(.ultraThinMaterial)
    }

    // MARK: - 1. Text size

    private var textSizeSection: some View {
        VStack(alignment: .leading, spacing: 14 * layoutMetrics.uiScale) {
            sectionTitle(tr("text_size"))
            // Live sample: the first four letters of the Arabic alphabet — the
            // same "abjad" order this primer teaches — scaled by the slider so
            // the effect is felt immediately, before opening any page. The
            // `uiScale` factor is the same iPad chrome boost every other
            // number in this sheet gets — independent of `arabicScale`, which
            // is purely the user's slider position.
            Text(Self.textSample)
                .font(arabicFont(32 * layoutMetrics.uiScale * preferences.arabicScale, weight: .bold))
                .foregroundStyle(AppColor.textMain)
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .frame(maxWidth: .infinity, minHeight: 64 * layoutMetrics.uiScale)
                .environment(\.layoutDirection, .rightToLeft)
                .accessibilityHidden(true)
            TextScaleSlider(title: tr("text_size"), value: textScaleBinding)
        }
    }

    private static let textSample = "ا ب ت ث"

    private var textScaleBinding: Binding<Double> {
        Binding(
            get: { preferences.settings.textScale },
            set: { preferences.setTextScale($0) }
        )
    }

    // MARK: - 2. Background

    private var backgroundSection: some View {
        VStack(alignment: .leading, spacing: 14 * layoutMetrics.uiScale) {
            sectionTitle(tr("reading_background"))
            HStack(spacing: 10 * layoutMetrics.uiScale) {
                ForEach(ReadingBackground.allCases, id: \.self) { background in
                    backgroundSwatch(background)
                }
            }
        }
    }

    /// One tappable swatch: a small "page" preview (its own fill + an "A" in
    /// its own text color) plus a caption, matching the selected/unselected
    /// decoration `SettingsView`'s theme segment already uses.
    private func backgroundSwatch(_ background: ReadingBackground) -> some View {
        let selected = preferences.settings.readingBackground == background
        return Button {
            preferences.setReadingBackground(background)
        } label: {
            VStack(spacing: 8 * layoutMetrics.uiScale) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(background.pageFill)
                    .overlay(
                        Text("A")
                            .font(.system(size: 17 * layoutMetrics.uiScale, weight: .bold))
                            .foregroundStyle(background.textMain)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(AppColor.divider, lineWidth: 1)
                    )
                    .frame(width: 44 * layoutMetrics.uiScale, height: 44 * layoutMetrics.uiScale)
                Text(tr(labelKey(for: background)))
                    .font(layoutMetrics.font(.caption2.weight(.medium), .subheadline.weight(.medium)))
                    .foregroundStyle(selected ? AppColor.primary : AppColor.textMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10 * layoutMetrics.uiScale)
            .background(
                selected ? AppColor.primary.opacity(0.18) : AppColor.surface.opacity(0.6),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        selected ? AppColor.primary.opacity(0.4) : AppColor.divider.opacity(0.4),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr(labelKey(for: background)))
    }

    /// Localization key for a background's caption — kept local to this sheet
    /// since it is purely a UI label concern, not a `ReadingBackground` trait.
    private func labelKey(for background: ReadingBackground) -> String {
        switch background {
        case .paper: return "bg_paper"
        case .sepia: return "bg_sepia"
        case .gray: return "bg_gray"
        case .night: return "bg_night"
        }
    }

    // MARK: - 3. Line spacing

    private var lineSpacingSection: some View {
        VStack(alignment: .leading, spacing: 8 * layoutMetrics.uiScale) {
            HStack(spacing: 8 * layoutMetrics.uiScale) {
                Text(tr("line_spacing"))
                    .font(layoutMetrics.font(.subheadline.weight(.medium), .title3.weight(.medium)))
                    .foregroundStyle(AppColor.textMain)
                Spacer(minLength: 8)
                Text(lineSpacingDisplay)
                    .font(.system(size: 15 * layoutMetrics.uiScale, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColor.primary)
                    .monospacedDigit()
            }
            Slider(value: lineSpacingBinding, in: 1.0...2.0, step: 0.05)
                .tint(AppColor.primary)
                .accessibilityLabel(tr("line_spacing"))
                .accessibilityValue(lineSpacingDisplay)
        }
    }

    private var lineSpacingBinding: Binding<Double> {
        Binding(
            get: { preferences.settings.lineSpacingScale },
            set: { preferences.setLineSpacingScale($0) }
        )
    }

    /// `%g` drops trailing zeros: 1.0 → "1×", 1.25 → "1.25×" (matches the
    /// audio-speed display format in `SettingsView`).
    private var lineSpacingDisplay: String { String(format: "%g×", preferences.settings.lineSpacingScale) }

    // MARK: - 4-6. Toggles

    private var togglesSection: some View {
        VStack(spacing: 0) {
            toggleRow(tr("bold_text"), isOn: boldTextBinding)
            sectionDivider
            toggleRow(tr("strong_highlight"), isOn: strongHighlightBinding)
            sectionDivider
            toggleRow(tr("keep_screen_awake"), isOn: keepScreenAwakeBinding)
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(layoutMetrics.font(.subheadline.weight(.medium), .title3.weight(.medium)))
                .foregroundStyle(AppColor.textMain)
        }
        .tint(AppColor.primary)
        .padding(.vertical, 10 * layoutMetrics.uiScale)
    }

    private var boldTextBinding: Binding<Bool> {
        Binding(get: { preferences.settings.boldText }, set: { preferences.setBoldText($0) })
    }

    private var strongHighlightBinding: Binding<Bool> {
        Binding(get: { preferences.settings.strongHighlight }, set: { preferences.setStrongHighlight($0) })
    }

    private var keepScreenAwakeBinding: Binding<Bool> {
        Binding(get: { preferences.settings.keepScreenAwake }, set: { preferences.setKeepScreenAwake($0) })
    }

    // MARK: - Small pieces

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(layoutMetrics.font(.subheadline.weight(.semibold), .title3.weight(.semibold)))
            .foregroundStyle(AppColor.textMuted)
    }

    /// Hairline separator — used both between the four top-level sections and
    /// between individual toggle rows.
    private var sectionDivider: some View {
        Rectangle().fill(AppColor.divider.opacity(0.5)).frame(height: 0.5)
    }
}

#if DEBUG
#Preview("ReadingOptionsSheet") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ReadingOptionsSheet()
                .presentationDetents([.medium, .large])
                .environment(ContentStore())
                .environment(SettingsStore())
        }
}
#endif
