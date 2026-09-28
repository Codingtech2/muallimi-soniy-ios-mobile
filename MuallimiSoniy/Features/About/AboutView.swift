import SwiftUI

/// "Dastur haqida" — opened from the publisher seal on Home. Shows the app
/// (name, version, what it is, credits), the company that made it (VIPADS,
/// content taken from vipads.uz) and how to reach it. Every sentence comes
/// from the String Catalog through `ContentStore.t(_:_:)`, so the screen
/// follows the in-app language live, like the rest of the UI.
struct AboutView: View {
    @Environment(ContentStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.layoutMetrics) private var layoutMetrics
    @Environment(\.dismiss) private var dismiss

    private var locale: AppLocale { settings.settings.locale }
    private var scale: CGFloat { layoutMetrics.uiScale }
    private func tr(_ key: String) -> String { store.t(key, locale) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20 * scale) {
                    appHeader
                    appCard
                    companyCard
                    contactCard
                    footer
                }
                .padding(.horizontal, 20 * scale)
                .padding(.top, 8 * scale)
                .padding(.bottom, 28 * scale)
                .frame(maxWidth: layoutMetrics.contentMaxWidth)
                .frame(maxWidth: .infinity)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationTitle(tr("about_app"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("close")) { dismiss() }
                }
            }
        }
    }

    // MARK: - Sections

    private var appHeader: some View {
        VStack(spacing: 8 * scale) {
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 88 * scale, height: 88 * scale)
                .accessibilityHidden(true)
            Text(tr("app_name"))
                .font(layoutMetrics.font(.title2.weight(.bold), .largeTitle.weight(.bold)))
                .fontDesign(.rounded)
                .foregroundStyle(AppColor.textMain)
                .accessibilityAddTraits(.isHeader)
            Text(String(format: tr("about_version"), AboutInfo.appVersion))
                .font(layoutMetrics.font(.subheadline, .title3))
                .monospacedDigit()
                .foregroundStyle(AppColor.textMuted)
            Text(tr("about_app_desc"))
                .font(layoutMetrics.font(.body, .title3))
                .foregroundStyle(AppColor.textMain)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4 * scale)
        }
        .frame(maxWidth: .infinity)
    }

    private var appCard: some View {
        AboutCard(icon: "book.closed", title: tr("about_section")) {
            AboutFactRow(label: tr("about_book_author_label"), value: tr("book_author"))
            AboutFactRow(label: tr("audio"), value: tr("about_audio_reader"))
        }
    }

    private var companyCard: some View {
        AboutCard(icon: "building.2", title: tr("about_us")) {
            // The description opens with the company's name, so no separate name line.
            Text(tr("about_company_desc"))
                .font(layoutMetrics.font(.subheadline, .body))
                .foregroundStyle(AppColor.textMain)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6 * scale) {
                Text(tr("about_mission_title"))
                    .font(layoutMetrics.font(.subheadline.weight(.semibold), .body.weight(.semibold)))
                    .foregroundStyle(AppColor.textMain)
                Text(tr("about_mission"))
                    .font(layoutMetrics.font(.subheadline, .body))
                    .foregroundStyle(AppColor.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            AboutFactRow(label: tr("about_founded"), value: AboutInfo.foundedYear)
            AboutFactRow(label: tr("about_headquarters"), value: tr("about_headquarters_value"))
            AboutFactRow(label: tr("about_activity"), value: tr("about_activity_value"))
            AboutFactRow(label: tr("about_tax_id"), value: AboutInfo.taxId)
        }
    }

    private var contactCard: some View {
        AboutCard(icon: "paperplane", title: tr("about_contact")) {
            AboutLinkRow(icon: "globe", label: tr("about_website"), value: AboutInfo.websiteLabel, url: AboutInfo.websiteURL)
            AboutLinkRow(icon: "envelope", label: tr("about_email"), value: AboutInfo.email, url: AboutInfo.emailURL)
            AboutLinkRow(icon: "phone", label: tr("about_phone"), value: AboutInfo.phoneLabel, url: AboutInfo.phoneURL)
        }
    }

    private var footer: some View {
        VStack(spacing: 2 * scale) {
            Text(String(format: tr("about_copyright"), AboutInfo.currentYear))
            Text(tr("about_made_in"))
        }
        .font(layoutMetrics.font(.footnote, .body))
        .foregroundStyle(AppColor.textMuted)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Company facts

/// Facts that read the same in every language (numbers, addresses), taken
/// from vipads.uz. Everything worded lives in the String Catalog.
private enum AboutInfo {
    static let foundedYear = "2024"
    static let taxId = "312819017"
    static let websiteLabel = "vipads.uz"
    static let websiteURL = URL(string: "https://vipads.uz")
    static let email = "info@vipads.uz"
    static let emailURL = URL(string: "mailto:info@vipads.uz")
    static let phoneLabel = "+998 99 094 33 21"
    static let phoneURL = URL(string: "tel:+998990943321")

    /// "1.1.1 (4)" straight from the bundle, so it never drifts from the build.
    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    /// Plain digits ("2026"), never a grouped "2,026".
    static var currentYear: String {
        String(Calendar.current.component(.year, from: Date()))
    }
}

// MARK: - Building blocks

/// A titled glass card, the same surface family as the Settings sections.
private struct AboutCard<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder var content: Content

    @Environment(\.layoutMetrics) private var layoutMetrics

    var body: some View {
        let scale = layoutMetrics.uiScale
        VStack(alignment: .leading, spacing: 14 * scale) {
            HStack(spacing: 10 * scale) {
                Image(systemName: icon)
                    .font(.system(size: 16 * scale, weight: .semibold))
                    .foregroundStyle(AppColor.primary)
                    .frame(width: 32 * scale, height: 32 * scale)
                    .background(AppColor.primary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                Text(title)
                    .font(layoutMetrics.font(.headline, .title3.weight(.semibold)))
                    .foregroundStyle(AppColor.textMain)
                    .accessibilityAddTraits(.isHeader)
            }
            content
        }
        .padding(layoutMetrics.isRegular ? 24 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
    }
}

/// Label on the leading edge, value on the trailing edge; stacks the two
/// when they no longer fit on one line (long values, large text sizes).
private struct AboutFactRow: View {
    let label: String
    let value: String

    @Environment(\.layoutMetrics) private var layoutMetrics

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                labelText
                Spacer(minLength: 12)
                valueText.multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: 2) {
                labelText
                valueText
            }
        }
        .font(layoutMetrics.font(.subheadline, .body))
        .accessibilityElement(children: .combine)
    }

    private var labelText: some View {
        Text(label).foregroundStyle(AppColor.textMuted).fixedSize()
    }

    private var valueText: some View {
        Text(value).foregroundStyle(AppColor.textMain).fixedSize(horizontal: false, vertical: true)
    }
}

/// A contact row that opens the website, mail or phone. Falls back to plain
/// text if the URL can't be built.
private struct AboutLinkRow: View {
    let icon: String
    let label: String
    let value: String
    let url: URL?

    @Environment(\.layoutMetrics) private var layoutMetrics

    var body: some View {
        if let url {
            Link(destination: url) { row(showsArrow: true) }
                .buttonStyle(.plain)
        } else {
            row(showsArrow: false)
        }
    }

    private func row(showsArrow: Bool) -> some View {
        let scale = layoutMetrics.uiScale
        return HStack(spacing: 12 * scale) {
            Image(systemName: icon)
                .font(.system(size: 15 * scale, weight: .medium))
                .foregroundStyle(AppColor.primary)
                .frame(width: 28 * scale)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(layoutMetrics.font(.caption, .subheadline))
                    .foregroundStyle(AppColor.textMuted)
                Text(value)
                    .font(layoutMetrics.font(.body, .title3))
                    .foregroundStyle(AppColor.textMain)
            }
            Spacer(minLength: 8)
            if showsArrow {
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColor.textMuted)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
