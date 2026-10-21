import SwiftUI

/// The Masjidlar tab (optional, switched on in Settings): a full-screen map
/// of the mosques from the bundled OpenStreetMap snapshot, a search field
/// floating on top and one glass panel that follows the flow — ask for
/// location → nearest mosques → the chosen mosque with its route and the
/// "open in" apps. On iPhone the panel sits at the bottom; on iPad it floats
/// at the bottom-left and the map centres what it shows to its right.
/// iOS-only, no web counterpart yet.
struct MosquesView: View {
    @Environment(MosqueStore.self) private var mosques
    @Environment(SettingsStore.self) private var settings
    @Environment(\.layoutMetrics) private var layoutMetrics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var isSearchOpen = false
    /// The mosque picked in search. It is chosen only once the sheet has
    /// gone, so the camera moves while the map has its full size.
    @State private var searchPick: Mosque?
    /// Height of the whole screen area; the panel stays within a share of it.
    @State private var screenHeight: CGFloat = 0
    /// Height of the bottom panel (iPhone), so the map can re-aim when it changes.
    @State private var panelHeight: CGFloat = 0

    private var locale: AppLocale { settings.settings.locale }

    private var panelMaxHeight: CGFloat {
        let share = dynamicTypeSize.isAccessibilitySize
            ? MosqueLayout.accessibilityMaxHeightShare
            : MosqueLayout.maxHeightShare
        return screenHeight > 0 ? screenHeight * share : .infinity
    }

    /// Fewer nearest mosques on short screens (iPhone SE, mini).
    private var nearbyLimit: Int {
        screenHeight > 0 && screenHeight < MosqueLayout.shortScreenHeight
            ? MosqueLayout.shortScreenNearbyCount
            : MosqueLayout.nearbyCount
    }

    var body: some View {
        NavigationStack {
            mapScreen
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    screenHeight = height
                }
                .toolbar(.hidden, for: .navigationBar)
                // Same ceiling as Home and the reader chrome.
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        }
        // Keeps the clock and battery readable over the map's pins.
        .overlay(alignment: .top) { MosqueStatusBarFade() }
        // The map screen has no text field of its own: keep the search sheet's
        // keyboard from pushing the panel and the map's safe area around
        // behind the sheet.
        .ignoresSafeArea(.keyboard)
        .task { await mosques.loadIfNeeded() }
        .onAppear { mosques.screenDidAppear() }
        .onDisappear { mosques.screenDidDisappear() }
        .sheet(isPresented: $isSearchOpen, onDismiss: chooseSearchPick) {
            MosqueSearchSheet(locale: locale) { picked in searchPick = picked }
        }
        .sensoryFeedback(.selection, trigger: mosques.selected?.id)
        .sensoryFeedback(.success, trigger: mosques.route?.mosqueID) { _, newValue in newValue != nil }
    }

    // MARK: - Layout

    @ViewBuilder
    private var mapScreen: some View {
        if layoutMetrics.isRegular {
            regularScreen
        } else {
            compactScreen
        }
    }

    /// iPhone (and a narrow iPad window): the panel is a bottom inset, so the
    /// map's own controls and "Legal" label sit just above it.
    private var compactScreen: some View {
        MosqueMapView(locale: locale, bottomInset: panelHeight, startPoint: mosques.userLocation)
            // Inside the map's safe area, so it sits just above the panel
            // on the same line as Apple's own "Legal" label.
            .overlay(alignment: .bottomTrailing) {
                MosqueAttributionChip(locale: locale)
                    .padding(.trailing, 10)
            }
            .safeAreaInset(edge: .top, spacing: 0) { searchBar }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MosquePanel(locale: locale, maxHeight: panelMaxHeight, nearbyLimit: nearbyLimit)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        panelHeight = height
                    }
            }
    }

    /// iPad: the map stays full screen; the card floats at the bottom-left
    /// with the attribution chip on its trailing top corner, and the map's
    /// left safe-area padding keeps fitted mosques and routes clear of it.
    private var regularScreen: some View {
        MosqueMapView(locale: locale, bottomInset: 0, startPoint: mosques.userLocation)
            .safeAreaPadding(.leading, MosqueLayout.regularPanelInset)
            .safeAreaInset(edge: .top, spacing: 0) { searchBar }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .trailing, spacing: 0) {
                    MosqueAttributionChip(locale: locale)
                        .padding(.trailing, MosqueLayout.regularMargin)
                    MosquePanel(locale: locale, maxHeight: panelMaxHeight, nearbyLimit: nearbyLimit)
                }
                .frame(width: MosqueLayout.regularPanelInset)
            }
    }

    private var searchBar: some View {
        MosqueSearchBar(locale: locale) { isSearchOpen = true }
    }

    private func chooseSearchPick() {
        guard let picked = searchPick else { return }
        searchPick = nil
        mosques.select(picked)
    }
}
