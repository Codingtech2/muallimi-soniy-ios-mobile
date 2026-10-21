import SwiftUI

/// What the bottom panel shows. A chosen mosque wins; otherwise it follows
/// the location flow: ask → locating → nearest five (or why not).
enum MosquePanelState: Equatable {
    case loading
    case permission
    case locating
    case denied
    case restricted
    case failed
    case nearby
    case selected(Mosque)
}

/// Sizes shared by the bottom panel and the search bar above the map.
enum MosqueLayout {
    /// The floating card's width on iPad, where the map stays full screen.
    static let regularPanelWidth: CGFloat = 420
    /// How much of the iPad map the floating card covers on the left
    /// (card + margins): the map centres what it shows in the rest.
    static let regularPanelInset: CGFloat = 460
    static let compactMargin: CGFloat = 12
    static let regularMargin: CGFloat = 20
    static let panelCornerRadius: CGFloat = 28
    /// The panel never covers more than this share of the screen; past it
    /// its text scrolls (large text sizes) while its buttons stay in view.
    static let maxHeightShare: CGFloat = 0.5
    /// At accessibility text sizes the panel may take a bit more of the map.
    static let accessibilityMaxHeightShare: CGFloat = 0.62
    /// Screens shorter than this (iPhone SE, mini) list 3 nearest, not 5.
    static let shortScreenHeight: CGFloat = 700
    static let nearbyCount = 5
    static let shortScreenNearbyCount = 3
    /// The fade at the bottom of a scrolling panel, in points.
    static let scrollFade: CGFloat = 24
}

/// The glass panel at the bottom of the map (bottom-leading floating card on
/// iPad). Shows exactly one state at a time: its text scrolls when it no
/// longer fits (large text sizes), its buttons always stay in view.
struct MosquePanel: View {
    let locale: AppLocale
    let maxHeight: CGFloat
    /// How many of the nearest mosques to list (fewer on short screens).
    var nearbyLimit = MosqueLayout.nearbyCount

    @Environment(MosqueStore.self) private var mosques
    @Environment(ContentStore.self) private var content
    @Environment(\.layoutMetrics) private var layoutMetrics
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var state: MosquePanelState {
        if let mosque = mosques.selected { return .selected(mosque) }
        guard mosques.isLoaded else { return .loading }
        switch mosques.locationState {
        case .notDetermined: return .permission
        case .locating: return .locating
        case .located: return .nearby
        case .denied: return .denied
        case .restricted: return .restricted
        case .failed: return .failed
        }
    }

    private var margin: CGFloat {
        layoutMetrics.isRegular ? MosqueLayout.regularMargin : MosqueLayout.compactMargin
    }

    private func tr(_ key: String) -> String { content.t(key, locale) }

    var body: some View {
        MaxHeightLayout(maxHeight: maxHeight) {
            VStack(alignment: .leading, spacing: 14 * layoutMetrics.uiScale) {
                ViewThatFits(in: .vertical) {
                    stateBody
                    scrollingBody
                }
                stateFooter
            }
            .padding(layoutMetrics.isRegular ? 22 : 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The glass is its own layer behind the content: on iOS 26 a Menu
        // opening from a button inside a glass view takes that view's glass
        // with it, which left the card see-through while "Ochish" was open.
        .background {
            Color.clear.glassCard(cornerRadius: MosqueLayout.panelCornerRadius)
        }
        .frame(maxWidth: layoutMetrics.isRegular ? MosqueLayout.regularPanelWidth : .infinity, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, margin)
        .padding(.bottom, layoutMetrics.isRegular ? margin : 8)
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: state)
    }

    /// The state's text when it no longer fits (large text, small phones):
    /// a visible, flashing scroll bar, room at the end and a soft fade at the
    /// bottom edge, so it reads as "there is more".
    private var scrollingBody: some View {
        ScrollView { stateBody }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.visible)
            .scrollIndicatorsFlash(onAppear: true)
            .contentMargins(.bottom, MosqueLayout.scrollFade, for: .scrollContent)
            .mask {
                VStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: MosqueLayout.scrollFade)
                }
            }
    }

    /// What the state says. Location off, restricted or failed: say so —
    /// the map and the search keep working either way.
    @ViewBuilder
    private var stateBody: some View {
        switch state {
        case .loading:
            MosqueProgressRow(text: tr("loading"))
        case .permission:
            MosqueMessageCard(
                icon: "location.circle.fill",
                title: tr("mosques_nearest"),
                message: tr("mosques_permission_desc")
            )
        case .locating:
            MosqueProgressRow(text: tr("mosques_locating"))
        case .denied:
            MosqueMessageCard(
                icon: "location.slash.fill",
                title: tr("mosques_location_denied"),
                message: tr("mosques_location_denied_desc")
            )
        case .restricted:
            MosqueMessageCard(
                icon: "location.slash.fill",
                title: tr("mosques_location_restricted"),
                message: tr("mosques_browse_hint")
            )
        case .failed:
            MosqueMessageCard(
                icon: "location.magnifyingglass",
                title: tr("mosques_location_failed"),
                message: tr("mosques_location_failed_desc")
            )
        case .nearby:
            MosqueNearbyList(locale: locale, limit: nearbyLimit)
        case .selected(let mosque):
            MosqueSelectedCard(mosque: mosque, route: route(to: mosque), locale: locale)
        }
    }

    /// The state's buttons, kept out of the scrolling part so they never
    /// slide out of reach.
    @ViewBuilder
    private var stateFooter: some View {
        switch state {
        case .permission:
            MosquePanelButton(title: tr("mosques_find_nearest"), systemImage: "location.fill") {
                Task { await mosques.locateUser() }
            }
        case .denied:
            MosquePanelButton(title: tr("mosques_open_settings"), systemImage: "gearshape.fill") {
                mosques.openLocationSettings()
            }
        case .failed:
            MosquePanelButton(title: tr("retry"), systemImage: "arrow.clockwise") {
                Task { await mosques.locateUser() }
            }
        case .selected(let mosque):
            MosqueSelectedActions(mosque: mosque, route: route(to: mosque), locale: locale)
        case .loading, .locating, .restricted, .nearby:
            EmptyView()
        }
    }

    /// The drawn route, when it leads to `mosque`.
    private func route(to mosque: Mosque) -> MosqueRoute? {
        guard let route = mosques.route, route.mosqueID == mosque.id else { return nil }
        return route
    }
}

// MARK: - Building blocks

/// Icon chip, title and a line or two of explanation. At accessibility text
/// sizes the chip is left out, so the text gets the room.
struct MosqueMessageCard: View {
    let icon: String
    let title: String
    let message: String

    @Environment(\.layoutMetrics) private var layoutMetrics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let scale = layoutMetrics.uiScale
        HStack(alignment: .top, spacing: 12 * scale) {
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: icon)
                    .font(.system(size: 18 * scale, weight: .semibold))
                    .foregroundStyle(AppColor.primary)
                    .frame(width: 40 * scale, height: 40 * scale)
                    .background(
                        AppColor.primary.opacity(0.15),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4 * scale) {
                Text(title)
                    .font(layoutMetrics.font(.headline, .title3.weight(.semibold)))
                    .foregroundStyle(AppColor.textMain)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(layoutMetrics.font(.subheadline, .body))
                    .foregroundStyle(AppColor.textMuted)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Spinner with a short line ("Joylashuvingiz aniqlanmoqda…").
struct MosqueProgressRow: View {
    let text: String

    @Environment(\.layoutMetrics) private var layoutMetrics

    var body: some View {
        HStack(spacing: 12 * layoutMetrics.uiScale) {
            ProgressView()
                .tint(AppColor.primary)
            Text(text)
                .font(layoutMetrics.font(.subheadline.weight(.medium), .body.weight(.medium)))
                .foregroundStyle(AppColor.textMain)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Offers its content at most `maxHeight` and takes exactly the content's
/// size — unlike `.frame(maxHeight:)`, which grows to the cap whenever the
/// parent offers more (the bottom inset offers the whole screen).
private struct MaxHeightLayout: Layout {
    let maxHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let height = proposal.height.map { min($0, maxHeight) } ?? maxHeight
        return child.sizeThatFits(ProposedViewSize(width: proposal.width, height: height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
        )
    }
}
