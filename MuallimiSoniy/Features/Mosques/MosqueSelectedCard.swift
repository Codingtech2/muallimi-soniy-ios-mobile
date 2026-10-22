import SwiftUI
import Accessibility

/// The chosen mosque: its names, how far it is, a reminder that the data
/// can't tell whether it is open, and — once drawn — the route's distance
/// and time. Its buttons are `MosqueSelectedActions`, which the panel keeps
/// in view below it.
struct MosqueSelectedCard: View {
    let mosque: Mosque
    /// The drawn route, when it leads to this mosque.
    let route: MosqueRoute?
    let locale: AppLocale

    @Environment(MosqueStore.self) private var mosques
    @Environment(ContentStore.self) private var content
    @Environment(\.layoutMetrics) private var layoutMetrics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var scale: CGFloat { layoutMetrics.uiScale }
    private var formatter: MosqueFormatter { MosqueFormatter(content: content, mosques: mosques, locale: locale) }
    private func tr(_ key: String) -> String { content.t(key, locale) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14 * scale) {
            header
            hoursNote
            if let route {
                routeSummary(route)
            }
            locationNote
        }
        .onChange(of: route?.mosqueID) { _, id in
            guard id != nil, let route else { return }
            // VoiceOver users hear the route arrive, not just see the line.
            AccessibilityNotification.Announcement("\(tr("mosques_route_shown_a11y")). \(formatter.spokenRoute(route))")
                .post()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12 * scale) {
            VStack(alignment: .leading, spacing: 4 * scale) {
                Text(formatter.name(of: mosque))
                    .font(layoutMetrics.font(.title3.weight(.bold), .title2.weight(.bold)))
                    .fontDesign(.rounded)
                    .foregroundStyle(AppColor.textMain)
                    .accessibilityAddTraits(.isHeader)
                // At accessibility sizes the other names would crowd the card.
                if !dynamicTypeSize.isAccessibilitySize, let others = formatter.otherNames(of: mosque) {
                    Text(others)
                        .font(layoutMetrics.font(.subheadline, .body))
                        .foregroundStyle(AppColor.textMuted)
                }
                // Once a route is drawn its own summary below says how far.
                if route == nil, let meters = mosques.distance(to: mosque) {
                    Text(formatter.summary(meters: meters))
                        .font(layoutMetrics.font(.subheadline.weight(.medium), .body.weight(.medium)))
                        .foregroundStyle(AppColor.textSecondary)
                        .accessibilityLabel(formatter.spokenSummary(meters: meters))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            MosqueCloseButton(label: tr("close")) { mosques.select(nil) }
                // Pull the 44 pt hit area into the corner so the circle lines up with the title.
                .padding(.top, -6)
                .padding(.trailing, -6)
        }
    }

    // MARK: - Opening hours

    /// The OpenStreetMap data has no opening hours: check in a real map app
    /// whether the mosque is open — the app can't answer for it.
    private var hoursNote: some View {
        Label {
            Text(tr("mosques_hours_note"))
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColor.gold)
        }
        .font(layoutMetrics.font(.footnote, .subheadline))
        .foregroundStyle(AppColor.textMain)
        .fixedSize(horizontal: false, vertical: true)
        .padding(10 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Route

    /// The straight-line note comes first, so the numbers under it read as
    /// the estimate they are: "≈ 2,5 km · ≈ 39 daqiqa piyoda".
    private func routeSummary(_ route: MosqueRoute) -> some View {
        VStack(alignment: .leading, spacing: 6 * scale) {
            if route.isStraightLine {
                Label {
                    Text(tr("mosques_route_straight"))
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(layoutMetrics.font(.footnote.weight(.semibold), .subheadline.weight(.semibold)))
                .foregroundStyle(AppColor.textSecondary)
            }
            Label {
                Text(formatter.routeLine(route))
            } icon: {
                Image(systemName: "figure.walk")
            }
            .font(layoutMetrics.font(.subheadline.weight(.semibold), .body.weight(.semibold)))
            .foregroundStyle(AppColor.textMain)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(12 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(formatter.spokenRoute(route))
    }

    /// Why there is no route: location is off, restricted, or the fix failed.
    @ViewBuilder
    private var locationNote: some View {
        switch mosques.locationState {
        case .denied, .restricted:
            note(tr("mosques_route_needs_location"), icon: "location.slash")
        case .failed:
            note(tr("mosques_location_failed"), icon: "location.magnifyingglass")
        case .notDetermined, .allowed, .locating, .located:
            EmptyView()
        }
    }

    private func note(_ text: String, icon: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: icon)
        }
        .font(layoutMetrics.font(.footnote, .subheadline))
        .foregroundStyle(AppColor.textMuted)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The chosen mosque's buttons: "Yoʻl koʻrsatish" (or hide the route, or
/// open Settings when location is off) and the "Ochish" menu that hands the
/// way over to a real navigation app. A mosque too far to walk to gets only
/// the menu, full width.
struct MosqueSelectedActions: View {
    let mosque: Mosque
    /// The drawn route, when it leads to this mosque.
    let route: MosqueRoute?
    let locale: AppLocale

    @Environment(MosqueStore.self) private var mosques
    @Environment(ContentStore.self) private var content
    @Environment(\.layoutMetrics) private var layoutMetrics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var scale: CGFloat { layoutMetrics.uiScale }
    private func tr(_ key: String) -> String { content.t(key, locale) }

    /// More than a walk away: a line on the map would not help.
    private var isTooFarToWalk: Bool {
        guard let meters = mosques.distance(to: mosque) else { return false }
        return meters > MosqueFormatter.walkableMeters
    }

    /// Side by side at one equal width and height, in the first look both
    /// labels fit: with icons, without, a step smaller, or wrapped (Russian
    /// "Скрыть маршрут" is the long one). Stacked at accessibility sizes.
    @ViewBuilder
    var body: some View {
        if isTooFarToWalk {
            openMenu(prominent: true, style: .automatic, stretch: false)
        } else if dynamicTypeSize.isAccessibilitySize {
            // Full width each: every button decides its own icon.
            VStack(spacing: 10 * scale) {
                routeAction(style: .automatic, stretch: false)
                openMenu(prominent: false, style: .automatic, stretch: false)
            }
        } else {
            ViewThatFits(in: .horizontal) {
                actionRow(.icon)
                actionRow(.plain)
                actionRow(.compact)
                actionRow(.wrapped)
            }
        }
    }

    private func actionRow(_ style: MosqueButtonLabel.Style) -> some View {
        MosqueEqualWidthRow(spacing: 10 * scale) {
            routeAction(style: style, stretch: true)
            openMenu(prominent: false, style: style, stretch: true)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func routeAction(style: MosqueButtonLabel.Style, stretch: Bool) -> some View {
        switch mosques.locationState {
        case .denied:
            Button {
                mosques.openLocationSettings()
            } label: {
                MosqueButtonLabel(title: tr("mosques_open_settings"), systemImage: "gearshape.fill", style: style)
            }
            .buttonStyle(MosqueActionButtonStyle(prominent: true, stretch: stretch))
        case .restricted:
            // Nothing the user can change here; the menu beside it still works.
            EmptyView()
        case .notDetermined, .allowed, .locating, .located, .failed:
            routeButton(style: style, stretch: stretch)
        }
    }

    @ViewBuilder
    private func routeButton(style: MosqueButtonLabel.Style, stretch: Bool) -> some View {
        if mosques.isRouting {
            // A label, not a button: nothing to tap while the route is built.
            ProgressView()
                .tint(.white)
                .modifier(MosqueActionLook(prominent: true, stretch: stretch))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(tr("mosques_routing"))
        } else if route != nil {
            Button {
                mosques.clearRoute()
            } label: {
                MosqueButtonLabel(title: tr("mosques_clear_route"), systemImage: "eye.slash", style: style)
            }
            .buttonStyle(MosqueActionButtonStyle(prominent: false, stretch: stretch))
        } else {
            Button {
                Task { await mosques.showRoute(to: mosque) }
            } label: {
                MosqueButtonLabel(title: tr("mosques_route"), systemImage: "figure.walk", style: style)
            }
            .buttonStyle(MosqueActionButtonStyle(prominent: true, stretch: stretch))
        }
    }

    /// Yandex Maps, Google Maps, Yandex Go and Apple Maps — whichever can
    /// open on this device — always for walking, in the app's language.
    private func openMenu(prominent: Bool, style: MosqueButtonLabel.Style, stretch: Bool) -> some View {
        Menu {
            ForEach(mosques.availableApps(), id: \.self) { app in
                Button {
                    mosques.open(mosque, in: app, mode: .walking, locale: locale)
                } label: {
                    Label(tr(MosqueAppLabel.key(for: app)), systemImage: MosqueAppLabel.symbol(for: app))
                }
            }
        } label: {
            MosqueButtonLabel(title: tr("mosques_open_in"), systemImage: "arrow.up.forward.app", style: style)
                .modifier(MosqueActionLook(prominent: prominent, stretch: stretch))
        }
        // Keep Yandex Maps on top even when the menu opens upwards.
        .menuOrder(.fixed)
    }
}

/// The menu wording and icon for each hand-off app.
nonisolated enum MosqueAppLabel {
    static func key(for app: MapApp) -> String {
        switch app {
        case .yandexMaps: return "mosques_app_yandex_maps"
        case .googleMaps: return "mosques_app_google_maps"
        case .yandexGo: return "mosques_app_yandex_go"
        case .appleMaps: return "mosques_app_apple_maps"
        }
    }

    static func symbol(for app: MapApp) -> String {
        switch app {
        case .yandexMaps, .googleMaps: return "map"
        case .yandexGo: return "car.fill"
        case .appleMaps: return "map.fill"
        }
    }
}
