import SwiftUI

/// Full Settings screen — 1:1 with the web `/sozlamalar` page.
///
/// Labels come from `ContentStore.t(_:_:)` in the user's current locale;
/// preferences are mutated through `SettingsStore`. Sections are laid out as
/// glass cards mirroring the web `GlassCard` + `SectionHeader` pattern (icon
/// chip + title + one-line description).
struct SettingsView: View {
    @Environment(ContentStore.self) private var content
    @Environment(SettingsStore.self) private var store

    /// App version — hardcoded to match the web `APP_VERSION`.
    private let appVersion = "1.0.0"

    private var locale: AppLocale { store.settings.locale }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    VStack(spacing: 16) {
                        OfflineCard()
                        repeatSection
                        languageSection
                        themeSection
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
            .sensoryFeedback(.selection, trigger: store.settings)
            // Settings has its own large header; hide the nav bar here so only the
            // pushed detail pages show one.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LegalDoc.self) { doc in
                LegalDetailView(doc: doc, title: tr(doc.labelKey), text: legalBody(for: doc))
            }
        }
    }

    // MARK: - Localization

    private func tr(_ key: String) -> String { content.t(key, locale) }

    // MARK: - Title / footer

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tr("settings"))
                .font(.title.bold())
                .foregroundStyle(AppColor.textMain)
            Text(tr("settings_subtitle"))
                .font(.subheadline)
                .foregroundStyle(AppColor.textMuted)
        }
    }

    private var footer: some View {
        VStack(spacing: 2) {
            Text("\(tr("app_name")) · v\(appVersion)")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColor.textMuted)
            Text(tr("footer_company"))
                .font(.caption2)
                .foregroundStyle(AppColor.textMuted.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Repeat count

    private var repeatSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSectionHeader(
                    icon: "repeat",
                    title: tr("repeat_count"),
                    desc: tr("repeat_desc")
                )
                HStack(spacing: 12) {
                    stepperButton(
                        icon: "minus",
                        label: tr("decrease"),
                        enabled: store.settings.repeatCount > SettingsView.repeatMin
                    ) { store.setRepeatCount(store.settings.repeatCount - 1) }

                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(store.settings.repeatCount)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColor.primary)
                            .monospacedDigit()
                        Text("×")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppColor.primary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    stepperButton(
                        icon: "plus",
                        label: tr("increase"),
                        enabled: store.settings.repeatCount < SettingsView.repeatMax
                    ) { store.setRepeatCount(store.settings.repeatCount + 1) }
                }
                Text(tr("repeat_reset_hint"))
                    .font(.caption2)
                    .foregroundStyle(AppColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func stepperButton(
        icon: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColor.textMain)
                .frame(width: 44, height: 44)
                .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }

    // MARK: - Language

    private var languageSection: some View {
        SettingsCard(padding: 0) {
            VStack(spacing: 0) {
                SettingsSectionHeader(
                    icon: "globe",
                    title: tr("language"),
                    desc: tr("language_desc")
                )
                .padding([.horizontal, .top], 16)
                .padding(.bottom, 12)

                ForEach(SettingsView.languages, id: \.value) { lang in
                    rowDivider
                    languageRow(lang)
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
                        Text(sub)
                            .font(.caption)
                            .foregroundStyle(AppColor.textMuted)
                    }
                }
                Spacer(minLength: 8)
                selectionCircle(selected: selected)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? AppColor.primary.opacity(0.15) : Color.clear)
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

    // MARK: - Theme

    private var themeSection: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSectionHeader(
                    icon: "circle.lefthalf.filled",
                    title: tr("theme"),
                    desc: tr("theme_desc")
                )
                HStack(spacing: 8) {
                    ForEach(SettingsView.themes, id: \.value) { option in
                        choiceButton(selected: store.settings.theme == option.value) {
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
        SettingsCard {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSectionHeader(
                    icon: "textformat.size",
                    title: tr("font_size"),
                    desc: tr("font_size_desc")
                )
                HStack(spacing: 8) {
                    ForEach(SettingsView.fontSizes, id: \.value) { option in
                        choiceButton(selected: store.settings.fontSize == option.value) {
                            store.setFontSize(option.value)
                        } content: {
                            Text("A")
                                .font(.system(size: option.point, weight: .bold))
                                .frame(height: 28, alignment: .bottom)
                            Text(tr(option.labelKey))
                                .font(.caption2)
                                .opacity(0.8)
                        }
                    }
                }
            }
        }
    }

    /// Shared 3-segment choice button (theme + font size), selected style
    /// mirrors web `bg-primary/20 text-primary border-primary/40`.
    private func choiceButton<Content: View>(
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
                    selected ? AppColor.primary.opacity(0.2) : AppColor.surface,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            selected ? AppColor.primary.opacity(0.4) : AppColor.divider.opacity(0.5),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - About

    private var aboutSection: some View {
        SettingsCard(padding: 0) {
            VStack(spacing: 0) {
                SettingsSectionHeader(
                    icon: "info.circle",
                    title: tr("about_section"),
                    desc: "\(tr("app_name")) · v\(appVersion)"
                )
                .padding([.horizontal, .top], 16)
                .padding(.bottom, 12)

                ForEach(LegalDoc.allCases) { doc in
                    rowDivider
                    legalRow(doc)
                }
            }
        }
    }

    private func legalRow(_ doc: LegalDoc) -> some View {
        NavigationLink(value: doc) {
            HStack(spacing: 12) {
                Image(systemName: doc.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AppColor.divider.opacity(0.6), lineWidth: 0.5)
                    )
                Text(tr(doc.labelKey))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.textMain)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColor.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared bits

    /// Hairline row separator (mirrors web `border-t border-white/5`).
    private var rowDivider: some View {
        Rectangle()
            .fill(AppColor.divider.opacity(0.6))
            .frame(height: 0.5)
    }

    /// Localized legal body for `doc`, falling back to Uzbek-Latin then empty.
    private func legalBody(for doc: LegalDoc) -> String {
        content.legal[locale.rawValue]?[doc.docKey]
            ?? content.legal[AppLocale.uzLatn.rawValue]?[doc.docKey]
            ?? ""
    }

    // MARK: - Static option tables (mirror the web arrays)

    private static let repeatMin = 1
    private static let repeatMax = 10

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

/// The three legal documents shown in the About section (keys match
/// `legal.json` doc keys and the i18n label keys).
private enum LegalDoc: String, Identifiable, CaseIterable {
    case privacyPolicy
    case termsOfUse
    case aboutApp

    var id: String { rawValue }
    /// Document key into `ContentStore.legal[locale]`.
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

/// Card container mirroring the web `GlassCard` (28pt radius, glass fill,
/// hairline border). Pass `padding: 0` for edge-to-edge list cards.
private struct SettingsCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.glass, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(AppColor.divider.opacity(0.6), lineWidth: 0.5)
            )
    }
}

/// Icon chip + title + one-line description, mirroring the web `SectionHeader`.
private struct SettingsSectionHeader: View {
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

/// Pushed detail page showing a legal document's localized body text. Opened via
/// `NavigationLink(value:)` from the About section; hides the tab bar while shown
/// (iOS 17 `.toolbar(.hidden, for: .tabBar)`), with the standard back button.
private struct LegalDetailView: View {
    let doc: LegalDoc
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
    SettingsView()
        .environment(ContentStore())
        .environment(SettingsStore())
        .environment(AudioDownloadManager())
}
