import SwiftUI
import MapKit

/// One thing on the map: a mosque pin with its title in the app's language,
/// or a round badge for mosques too close together to tell apart.
nonisolated enum MosqueMapPin: Identifiable, Equatable, Sendable {
    case single(Mosque, title: String)
    case cluster(MosqueCluster)

    var id: String {
        switch self {
        case .single(let mosque, _): return mosque.id
        case .cluster(let cluster): return cluster.id
        }
    }

    /// What the map draws for `viewport`: single mosques with their titles,
    /// and one round badge with the count where pins would pile up (see
    /// `MosqueClustering`). The selected mosque is always its own pin; a
    /// mosque without a name is called `unnamedTitle`. Pure, so it runs on a
    /// background thread.
    static func pins(
        for mosques: [Mosque], in viewport: GeoBounds, grid: MosqueClustering.Grid,
        selectedID: String?, locale: AppLocale, unnamedTitle: String
    ) -> [MosqueMapPin] {
        MosqueClustering.items(for: mosques, in: viewport, grid: grid, selectedID: selectedID).map { item in
            switch item {
            case .single(let mosque):
                return .single(mosque, title: MosqueCatalog.displayName(of: mosque, locale: locale) ?? unnamedTitle)
            case .cluster(let cluster):
                return .cluster(cluster)
            }
        }
    }
}

/// Everything the map's pins depend on: when it changes they are built again.
nonisolated private struct MosquePinsInput: Hashable, Sendable {
    let viewport: GeoBounds
    let grid: MosqueClustering.Grid
    let selectedID: String?
    let locale: AppLocale
}

/// The full-screen map: the user's dot, the mosques in view — clustered into
/// count badges where they would pile up, recomputed on a background thread
/// whenever the camera stops — the chosen mosque with its title showing, and
/// the route line.
/// Moves the camera when the store asks (`focusRequest`: a chosen mosque, or
/// the user once located), when a route arrives and when a badge is tapped.
struct MosqueMapView: View {
    let locale: AppLocale
    /// Height of the bottom panel. When it changes right after a camera move
    /// (a route summary appears, the list turns into a card) the map aims
    /// again, so the target fits the area the panel leaves free.
    let bottomInset: CGFloat

    @Environment(MosqueStore.self) private var mosques
    @Environment(ContentStore.self) private var content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var position: MapCameraPosition
    /// The area on screen when the camera last stopped.
    @State private var visibleRegion: MKCoordinateRegion
    /// The map's size in points — how many grid cells fit across and down.
    @State private var mapSize: CGSize = .zero
    @State private var pins: [MosqueMapPin] = []
    /// The map's own pin selection, kept in step with `mosques.selected`.
    @State private var mapSelection: String?
    /// Where the camera was last sent by the app (not by the user).
    @State private var cameraTarget: MKCoordinateRegion?
    /// Bumped on every badge tap, for the haptic.
    @State private var clusterTaps = 0

    private static let markerSymbol = "moon.stars.fill"
    private static let cameraAnimation = Animation.easeInOut(duration: 0.6)
    /// A badge tap zooms in at least this much, even on a tight cluster.
    private static let clusterZoomFactor = 4.0

    init(locale: AppLocale, bottomInset: CGFloat, startPoint: GeoPoint?) {
        self.locale = locale
        self.bottomInset = bottomInset
        var region = startPoint.map { MosqueMapRegion.region(around: $0, span: MosqueMapRegion.streetSpan * 2) }
            ?? MosqueMapRegion.region(around: MosqueMapRegion.defaultCenter, span: MosqueMapRegion.citySpan)
        #if DEBUG
        region = MosqueMapRegion.debugLaunchRegion ?? region
        #endif
        _position = State(initialValue: .region(region))
        _visibleRegion = State(initialValue: region)
    }

    var body: some View {
        // No tilt: a pitched map shows a different scale near and far, which
        // the on-screen clustering grid cannot follow.
        Map(position: $position, interactionModes: [.pan, .zoom, .rotate], selection: $mapSelection) {
            UserAnnotation()
            routeLine
            ForEach(pins) { pin in
                pinContent(pin)
            }
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        // The user's dot follows the map's tint: system blue, not the app's
        // green, so "you" never reads as a mosque (pins carry their own tint).
        .tint(Color.blue)
        .mapControls {
            if mosques.locationState == .located {
                MapUserLocationButton()
            }
            MapCompass()
            MapScaleView(anchorEdge: .leading)
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            mapSize = size
        }
        // A new camera stop, size, selection or language cancels the build
        // still running for the old one.
        .task(id: pinsInput) { await rebuildPins(for: pinsInput) }
        .onAppear {
            // Back on the tab with a mosque still chosen: show its pin chosen
            // too, and bring it (or its route) back into view.
            mapSelection = mosques.selected?.id
            if mosques.selected != nil { focusOnRequest() }
        }
        .onChange(of: bottomInset) { aimAgainAfterPanelChange() }
        .sensoryFeedback(.impact(weight: .light), trigger: clusterTaps)
        .modifier(MosqueMapReactions(
            mosques: mosques,
            mapSelection: $mapSelection,
            onMapSelection: mapSelectionChanged,
            onFocusRequest: focusOnRequest,
            onRoute: show
        ))
    }

    // MARK: - Map content

    /// A mosque pin (its title shows once chosen), or a count badge. Both are
    /// tagged, so every tap goes through the map's selection.
    @MapContentBuilder
    private func pinContent(_ pin: MosqueMapPin) -> some MapContent {
        switch pin {
        case .single(let mosque, let title):
            // The deep green: white glyphs stay readable, and pins match the badges.
            Marker(title, systemImage: Self.markerSymbol, coordinate: MosqueMapRegion.coordinate(mosque.point))
                .tint(AppColor.primaryButton)
                .annotationTitles(mosque.id == mosques.selected?.id ? .visible : .hidden)
                .tag(mosque.id)
        case .cluster(let cluster):
            Annotation(clusterLabel(cluster), coordinate: MosqueMapRegion.coordinate(cluster.center)) {
                MosqueClusterBadge(
                    count: cluster.count,
                    label: clusterLabel(cluster),
                    hint: content.t("mosques_cluster_hint", locale)
                )
            }
            .annotationTitles(.hidden)
            .tag(cluster.id)
        }
    }

    /// The route to the chosen mosque. A straight line (every route today:
    /// Apple Maps has no walking routes in Uzbekistan) is drawn light and
    /// dashed, with "≈ 2,5 km · toʻgʻri chiziq" at its middle, so it reads as
    /// an estimate, not a path. A small dot marks where it starts, so the
    /// line never floats when the user's own dot is elsewhere.
    @MapContentBuilder
    private var routeLine: some MapContent {
        if let route = mosques.route, route.mosqueID == mosques.selected?.id,
           let start = route.points.first, let end = route.points.last, route.points.count >= 2 {
            MapPolyline(
                coordinates: route.points.map(MosqueMapRegion.coordinate),
                contourStyle: route.isStraightLine ? .geodesic : .straight
            )
            .stroke(AppColor.primary.opacity(0.8), style: Self.routeStroke(dashed: route.isStraightLine))
            Annotation("", coordinate: MosqueMapRegion.coordinate(start)) {
                MosqueRouteStart()
            }
            .annotationTitles(.hidden)
            if route.isStraightLine {
                Annotation("", coordinate: MosqueMapRegion.coordinate(Self.midpoint(start, end))) {
                    let formatter = MosqueFormatter(content: content, mosques: mosques, locale: locale)
                    MosqueRouteChip(text: formatter.routeChip(route), spokenText: formatter.spokenRouteChip(route))
                }
                .annotationTitles(.hidden)
            }
        }
    }

    private static func routeStroke(dashed: Bool) -> StrokeStyle {
        StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: dashed ? [6, 8] : [])
    }

    /// Halfway along a short line (a few km): the plain average is close enough.
    private static func midpoint(_ start: GeoPoint, _ end: GeoPoint) -> GeoPoint {
        GeoPoint(latitude: (start.latitude + end.latitude) / 2, longitude: (start.longitude + end.longitude) / 2)
    }

    /// "12 ta masjid".
    private func clusterLabel(_ cluster: MosqueCluster) -> String {
        String(format: content.t("mosques_cluster_a11y", locale), "\(cluster.count)")
    }

    /// What the pins are built from; nil until the dataset and the map's size are known.
    private var pinsInput: MosquePinsInput? {
        guard mosques.isLoaded, mapSize.width > 0, mapSize.height > 0 else { return nil }
        return MosquePinsInput(
            viewport: MosqueMapRegion.bounds(of: visibleRegion),
            grid: MosqueClustering.Grid(mapWidth: mapSize.width, mapHeight: mapSize.height),
            selectedID: mosques.selected?.id,
            locale: locale
        )
    }

    /// Reclusters what is in view on a background thread and shows the
    /// result on the main actor, so a camera stop never holds up the map.
    /// A build overtaken by a newer one is dropped; equal pins leave the map
    /// untouched.
    private func rebuildPins(for input: MosquePinsInput?) async {
        guard let input else { return }
        let all = mosques.mosques
        let unnamedTitle = content.t("mosques_unnamed", input.locale)
        let built = await Task.detached(priority: .userInitiated) {
            MosqueMapPin.pins(
                for: all, in: input.viewport, grid: input.grid,
                selectedID: input.selectedID, locale: input.locale, unnamedTitle: unnamedTitle
            )
        }.value
        guard !Task.isCancelled, built != pins else { return }
        pins = built
    }

    // MARK: - Selection

    /// A tap on a pin chooses that mosque; a tap on a badge only zooms in
    /// (the chosen mosque stays chosen); a tap on empty map closes the card —
    /// unless a route is drawn, which stays until the card is closed.
    private func mapSelectionChanged(to id: String?) {
        guard id != mosques.selected?.id else { return }
        switch pins.first(where: { $0.id == id }) {
        case .cluster(let cluster):
            mapSelection = mosques.selected?.id
            zoom(into: cluster)
        case .single(let mosque, _):
            mosques.select(mosque)
        case nil:
            if mosques.route != nil {
                mapSelection = mosques.selected?.id
            } else {
                mosques.select(nil)
            }
        }
    }

    // MARK: - Camera

    /// A badge tap: zoom to its mosques with some room around them — or at
    /// least `clusterZoomFactor` times when they sit too close for that.
    private func zoom(into cluster: MosqueCluster) {
        clusterTaps += 1
        let fitted = MosqueMapRegion.region(fitting: cluster.bounds)
        if fitted.span.longitudeDelta <= visibleRegion.span.longitudeDelta / 2 {
            move(to: fitted)
        } else {
            move(to: MosqueMapRegion.zoomedIn(visibleRegion, around: cluster.center, factor: Self.clusterZoomFactor))
        }
    }

    /// The chosen mosque (with its route when one is drawn), or — nothing
    /// chosen — the user with the nearest mosques.
    private func focusOnRequest() {
        guard let mosque = mosques.selected else {
            showUserAndNearby()
            return
        }
        if let route = mosques.route, route.mosqueID == mosque.id {
            show(route)
        } else {
            let span = MosqueMapRegion.focusSpan(current: visibleRegion.span.latitudeDelta)
            move(to: MosqueMapRegion.region(around: mosque.point, span: span))
        }
    }

    /// The user and the nearest mosques together, right after locating.
    private func showUserAndNearby() {
        guard let user = mosques.userLocation else { return }
        let points = [user] + mosques.nearby.map(\.mosque.point)
        if let region = MosqueMapRegion.region(fitting: points) {
            move(to: region)
        }
    }

    private func show(_ route: MosqueRoute) {
        guard route.mosqueID == mosques.selected?.id,
              let region = MosqueMapRegion.region(fitting: route.points) else { return }
        move(to: region)
    }

    /// The panel grew or shrank: aim at the same target again so it fits the
    /// new free area — unless the user has moved the map (or follows their
    /// own location) since.
    private func aimAgainAfterPanelChange() {
        guard let cameraTarget, position.region != nil, !position.positionedByUser else { return }
        move(to: cameraTarget)
    }

    private func move(to region: MKCoordinateRegion) {
        cameraTarget = region
        if reduceMotion {
            position = .region(region)
        } else {
            withAnimation(Self.cameraAnimation) { position = .region(region) }
        }
    }
}

/// The store changes the map reacts to, kept out of `MosqueMapView.body`
/// so it stays readable. (The pins follow the store through the view's
/// `.task(id:)`: a newly chosen mosque leaves its cluster there.)
private struct MosqueMapReactions: ViewModifier {
    let mosques: MosqueStore
    @Binding var mapSelection: String?
    let onMapSelection: (String?) -> Void
    let onFocusRequest: () -> Void
    let onRoute: (MosqueRoute) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: mapSelection) { _, id in onMapSelection(id) }
            .onChange(of: mosques.selected?.id) { _, id in
                if mapSelection != id { mapSelection = id }
            }
            .onChange(of: mosques.focusRequest) { onFocusRequest() }
            .onChange(of: mosques.route) { _, route in
                if let route { onRoute(route) }
            }
    }
}
