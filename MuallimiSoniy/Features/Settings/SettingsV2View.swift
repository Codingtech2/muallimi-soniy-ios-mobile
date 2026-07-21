import SwiftUI

/// The glass Settings screen (replaces `SettingsView` in the Sozlamalar tab).
///
/// Same section model as the old settings, rebuilt on the reusable Liquid-Glass
/// system: every section is a `.glassCard()` surface (real Liquid Glass on
/// iOS 26, `.ultraThinMaterial` + hairline on iOS 17–25). The flagship addition
/// is the **Audio** card — three labelled sliders (Takror / Tezlik / Ovoz) that
/// persist through `SettingsStore` and apply live to the shared `AudioController`.
///
/// Labels come from `ContentStore.t(_:_:)` where keys exist; the short audio
/// slider labels are clean Uzbek literals. Preferences mutate only via the
/// store's `set*` methods, keeping the view free of business logic.
struct SettingsV2View: View {
    @Environment(ContentStore.self) private var content
    @Environment(SettingsStore.self) private var store
    @Environment(AudioController.self) private var audio

    /// App version — matches the web `APP_VERSION`.
    private let appVersion = "1.0.0"

    private var locale: AppLocale { store.settings.locale }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    VStack(spacing: 16) {
                        OfflineCard()          // already draws its own glass surface
                        audioSection           // the flagship
                        appearanceSection
                        languageSection
                        fontSizeSection
                        aboutSection
                    }

                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppColor.background.ignoresSafeArea())
            // Haptic on each discrete change. Volume is continuous, so it is left
            // out to avoid a buzz on every drag tick.
            .sensoryFeedback(.selection, trigger: store.settings.theme)
            .sensoryFeedback(.selection, trigger: store.settings.locale)
            .sensoryFeedback(.selection, trigger: store.settings.fontSize)
            .sensoryFeedback(.selection, trigger: store.settings.repeatCount)
            .sensoryFeedback(.selection, trigger: store.settings.speed)
            // The screen owns a large title, so hide the nav bar here; only the
            // pushed legal detail shows one.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LegalDocV2.self) { doc in
                LegalDetailV2(doc: doc, title: tr(doc.labelKey), text: legalBody(for: doc))
            }
        }
    }

    // MARK: - Localization

    private func tr(_ key: String) -> String { content.t(key, locale) }

    // MARK: - Title / footer

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tr("settings"))
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.textMain)
            Text(tr("settings_subtitle"))
                .font(.subheadline)
                .foregroundStyle(AppColor.textMuted)
        }
    }

    private var footer: some View {
        Text("\(tr("app_name")) · v\(appVersion) · \(tr("footer_company"))")
            .font(.caption.weight(.medium))
            .foregroundStyle(AppColor.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    // MARK: - Audio (flagship)

    private var audioSection: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeaderV2(
                    icon: "waveform",
                    title: "Audio",
                    desc: "Takror, tezlik va ovoz balandligi"
                )

                AudioSliderRow(
                    title: "Takror",
                    value: repeatBinding,
                    range: 1...10, step: 1,
                    display: "\(store.settings.repeatCount)×"
                )
                sliderDivider

                AudioSliderRow(
                    title: tr("speed"),
                    value: speedBinding,
                    range: 0.5...2.0, step: 0.25,
                    display: speedDisplay,
                    ticks: ["0.5×", "1×", "1.5×", "2×"]
                )
                sliderDivider

                AudioSliderRow(
                    title: "Ovoz",
                    icon: "speaker.wave.2.fill",
                    value: volumeBinding,
                    range: 0...1, step: nil,
                    display: volumeDisplay
                )
            }
        }
    }

    private var sliderDivider: some View {
        Rectangle()
            .fill(AppColor.divider.opacity(0.5))
            .frame(height: 0.5)
    }

    /// Each slider persists through the store *and* applies live to the player,
    /// so a change is reflected instantly if audio is already sounding.
    private var repeatBinding: Binding<Double> {
        Binding(
            get: { Double(store.settings.repeatCount) },
            set: { newValue in
                let count = Int(newValue.rounded())
                store.setRepeatCount(count)
                audio.setRepeatCount(count)
            }
        )
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { store.settings.speed },
            set: { store.setSpeed($0); audio.setSpeed($0) }
        )
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { store.settings.volume },
            set: { store.setVolume($0); audio.setVolume($0) }
        )
    }

    /// `%g` drops trailing zeros: 1.0 → "1×", 1.25 → "1.25×", 1.5 → "1.5×".
    private var speedDisplay: String { String(format: "%g×", store.settings.speed) }
    private var volumeDisplay: String { "\(Int((store.settings.volume * 100).rounded()))%" }

    // MARK: - Appearance (theme)

    private var appearanceSection: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeaderV2(
                    icon: "circle.lefthalf.filled",
                    title: tr("theme"),
                    desc: tr("theme_desc")
                )
                HStack(spacing: 8) {
                    ForEach(Self.themes, id: \.value) { option in
                        segment(selected: store.settings.theme == option.value) {
                            store.setTheme(option.value)
                        } content: {
                            Image(systemName: option.icon).font(.system(size: 20))
                            Text(tr(option.labelKey)).font(.caption.weight(.medium))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Font size

    private var fontSizeSection: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeaderV2(
                    icon: "textformat.size",
                    title: tr("font_size"),
                    desc: tr("font_size_desc")
                )
                HStack(spacing: 8) {
                    ForEach(Self.fontSizes, id: \.value) { option in
                        segment(selected: store.settings.fontSize == option.value) {
                            store.setFontSize(option.value)
                        } content: {
                            Text("A")
                                .font(.system(size: option.point, weight: .bold))
                                .frame(height: 28, alignment: .bottom)
                            Text(tr(option.labelKey)).font(.caption2).opacity(0.85)
                        }
                    }
                }
            }
        }
    }

    /// Shared 3-segment glass control (theme + font size).
    private func segment<Content: View>(
        selected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) { content() }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(selected ? AppColor.primary : AppColor.textMuted)
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
    }

    // MARK: - Language

    private var languageSection: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderV2(
                    icon: "globe",
                    title: tr("language"),
                    desc: tr("language_desc")
                )
                VStack(spacing: 6) {
                    ForEach(Self.languages, id: \.value) { lang in
                        languageRow(lang)
                    }
                }
            }
        }
    }

    private func languageRow(_ lang: LanguageOption) -> some View {
        let selected = store.settings.locale == lang.value
        return Button {
            store.setLocale(lang.value)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.label)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(selected ? AppColor.primary : AppColor.textMain)
                    if let sub = lang.sub {
                        Text(sub).font(.caption).foregroundStyle(AppColor.textMuted)
                    }
                }
                Spacer(minLength: 8)
                selectionCircle(selected: selected)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? AppColor.primary.opacity(0.15) : AppColor.surface.opacity(0.5),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? AppColor.primary.opacity(0.3) : .clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func selectionCircle(selected: Bool) -> some View {
        ZStack {
            if selected {
                Circle().fill(AppColor.primary)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle().strokeBorder(AppColor.divider, lineWidth: 2)
            }
        }
        .frame(width: 24, height: 24)
    }

    // MARK: - About

    private var aboutSection: some View {
        GlassSection {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderV2(
                    icon: "info.circle",
                    title: tr("about_section"),
                    desc: "\(tr("app_name")) · v\(appVersion)"
                )
                VStack(spacing: 6) {
                    ForEach(LegalDocV2.allCases) { doc in
                        aboutRow(doc)
                    }
                }
            }
        }
    }

    private func aboutRow(_ doc: LegalDocV2) -> some View {
        NavigationLink(value: doc) {
            HStack(spacing: 12) {
                Image(systemName: doc.icon)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(tr(doc.labelKey))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.textMain)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColor.textMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    /// Localized legal body for `doc`, falling back to Uzbek-Latin then empty.
    private func legalBody(for doc: LegalDocV2) -> String {
        content.legal[locale.rawValue]?[doc.docKey]
            ?? content.legal[AppLocale.uzLatn.rawValue]?[doc.docKey]
            ?? ""
    }

    // MARK: - Static option tables

    private static let languages: [LanguageOption] = [
        LanguageOption(value: .uzLatn, label: "Oʻzbekcha", sub: "Lotin yozuvi"),
        LanguageOption(value: .uzCyrl, label: "Ўзбекча", sub: "Кирилл ёзуви"),
        LanguageOption(value: .ru, label: "Русский", sub: nil),
        LanguageOption(value: .en, label: "English", sub: nil)
    ]

    private static let themes: [ThemeOption] = [
        ThemeOption(value: .light, icon: "sun.max.fill", labelKey: "light"),
        ThemeOption(value: .dark, icon: "moon.fill", labelKey: "dark"),
        ThemeOption(value: .system, icon: "circle.lefthalf.filled", labelKey: "system")
    ]

    private static let fontSizes: [FontSizeOption] = [
        FontSizeOption(value: .small, point: 13, labelKey: "small"),
        FontSizeOption(value: .medium, point: 16, labelKey: "medium"),
        FontSizeOption(value: .large, point: 20, labelKey: "large")
    ]
}

// MARK: - Option value types

private struct LanguageOption {
    let value: AppLocale
    let label: String
    let sub: String?
}

private struct ThemeOption {
    let value: AppTheme
    let icon: String
    let labelKey: String
}

private struct FontSizeOption {
    let value: FontSize
    let point: CGFloat
    let labelKey: String
}

/// The three legal documents in the About section (keys match `legal.json`
/// doc keys and the i18n label keys).
private enum LegalDocV2: String, Identifiable, CaseIterable {
    case privacyPolicy
    case termsOfUse
    case aboutApp

    var id: String { rawValue }
    var docKey: String { rawValue }

    var labelKey: String {
        switch self {
        case .privacyPolicy: return "privacy_policy"
        case .termsOfUse: return "terms_of_use"
        case .aboutApp: return "about_app"
        }
    }

    var icon: String {
        switch self {
        case .privacyPolicy: return "checkmark.shield"
        case .termsOfUse: return "doc.text"
        case .aboutApp: return "info.circle"
        }
    }
}

// MARK: - Reusable sub-views

/// Glass card wrapper: pads its content and applies the shared Liquid-Glass
/// surface (28pt continuous rounded rect) so every section reads as one family.
private struct GlassSection<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 28)
    }
}

/// Icon chip + title + one-line description, mirroring the web `SectionHeader`.
private struct SectionHeaderV2: View {
    let icon: String
    let title: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(AppColor.primary)
                .frame(width: 36, height: 36)
                .background(AppColor.primary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textMain)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(AppColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One labelled audio slider: title (+ optional leading icon) on the left, the
/// live value on the right, the slider below, and optional tick captions under
/// it. `step == nil` gives a continuous slider (used for volume).
private struct AudioSliderRow: View {
    let title: String
    var icon: String?
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double?
    let display: String
    var ticks: [String]?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColor.primary)
                }
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.textMain)
                Spacer(minLength: 8)
                Text(display)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColor.primary)
                    .monospacedDigit()
            }
            slider
                .accessibilityLabel(title)
                .accessibilityValue(display)
            if let ticks { tickRow(ticks) }
        }
    }

    @ViewBuilder private var slider: some View {
        if let step {
            Slider(value: $value, in: range, step: step).tint(AppColor.primary)
        } else {
            Slider(value: $value, in: range).tint(AppColor.primary)
        }
    }

    private func tickRow(_ ticks: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(ticks.enumerated()), id: \.offset) { idx, label in
                Text(label).font(.caption2).foregroundStyle(AppColor.textMuted)
                if idx < ticks.count - 1 { Spacer(minLength: 0) }
            }
        }
    }
}

/// Pushed detail page showing a legal document's localized body. Hides the tab
/// bar while shown (iOS 17 `.toolbar(.hidden, for: .tabBar)`) with a back button.
private struct LegalDetailV2: View {
    let doc: LegalDocV2
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: doc.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(AppColor.primary)
                        .frame(width: 40, height: 40)
                        .background(AppColor.primary.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(AppColor.textMain)
                    Spacer(minLength: 0)
                }

                Text(text.isEmpty ? "—" : text)
                    .font(.callout)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    SettingsV2View()
        .environment(ContentStore())
        .environment(SettingsStore())
        .environment(AudioController())
        .environment(AudioDownloadManager())
}
