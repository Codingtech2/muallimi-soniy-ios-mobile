import Foundation
import Observation
import OSLog

/// Everything behind the Masjidlar tab: the bundled OpenStreetMap mosques,
/// the user's location and the five nearest mosques, the selected mosque, a
/// route to it and the hand-off to Yandex / Google / Apple Maps and Yandex Go.
/// The dataset loads (off the main actor) only when the tab first appears.
/// iOS-only, no web counterpart yet.
@MainActor
@Observable
final class MosqueStore {
    /// The whole dataset, once loaded.
    private(set) var mosques: [Mosque] = []
    private(set) var isLoaded = false
    /// When the OpenStreetMap snapshot was taken ("2026-10-21T09:10:18Z").
    private(set) var datasetDate: String?
    private(set) var userLocation: GeoPoint?
    private(set) var locationState: MosqueLocationState = .notDetermined
    /// Closest first, up to five within 50 km; empty without a location.
    private(set) var nearby: [NearbyMosque] = []
    private(set) var selected: Mosque?
    private(set) var route: MosqueRoute?
    private(set) var isRouting = false
    /// Bumped whenever the map should move to `selected` (or to the user) —
    /// the map view reacts with a camera change.
    private(set) var focusRequest = 0

    #if DEBUG
    /// QA-only launch overrides, handed over by the App before any view
    /// appears (see MosqueStore+Debug.swift).
    @ObservationIgnored var debugOverrides = MosqueDebugOverrides()
    @ObservationIgnored var didStartDebugOverrides = false
    #endif

    @ObservationIgnored private var catalog = MosqueCatalog(mosques: [])
    /// The one dataset load; later callers wait for it instead of starting another.
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    /// Made when the tab first loads — never at app launch, the tab may be hidden.
    @ObservationIgnored private var locationProvider: LocationProvider?
    /// The locate in flight; later callers wait for it instead of applying twice.
    @ObservationIgnored private var locateTask: Task<Void, Never>?
    /// Bumped by every route request and by `clearRoute()`: an answer that
    /// comes back after a newer request started is dropped (the newer one wins).
    @ObservationIgnored private var routeRequestID = 0
    /// The mosque a route is being worked out for right now.
    @ObservationIgnored private var routingMosqueID: String?
    /// Whether the Masjidlar screen is up: permission changes locate the user
    /// again only then.
    @ObservationIgnored private var isScreenVisible = false
    /// Set once the screen reports itself (`screenDidAppear` / `screenDidDisappear`);
    /// until then a load counts as the screen being up.
    @ObservationIgnored private var hasScreenCallbacks = false

    private static let nearbyCount = 5

    init() {}

    // MARK: - Loading

    /// Loads the bundled dataset once (decoded off the main actor; concurrent
    /// callers share the one load), then follows the location permission:
    /// allowed earlier → locates right away; denied → `locationState` says so.
    func loadIfNeeded() async {
        await loadDataset()
        if !hasScreenCallbacks { isScreenVisible = true }
        followPermission()
        #if DEBUG
        startDebugOverridesOnce()
        #endif
    }

    /// The Masjidlar screen is up: a permission given meanwhile (e.g. in
    /// Settings) locates the user now.
    func screenDidAppear() {
        hasScreenCallbacks = true
        isScreenVisible = true
        followPermission()
    }

    /// The screen went away: no automatic locating until it's back.
    func screenDidDisappear() {
        hasScreenCallbacks = true
        isScreenVisible = false
    }

    private func loadDataset() async {
        guard !isLoaded else { return }
        if let loadTask {
            await loadTask.value
            return
        }
        let task = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                MosqueStore.decodeBundledDataset()
            }.value
            self?.apply(result)
        }
        loadTask = task
        await task.value
    }

    private func apply(_ result: DatasetLoad) {
        catalog = result.catalog
        mosques = result.catalog.mosques
        datasetDate = result.generatedAt
        isLoaded = true
        if let problem = result.problem {
            MosqueLog.logger.error("dataset: \(problem, privacy: .public)")
        }
        MosqueLog.logger.info("""
            dataset: \(result.catalog.mosques.count) mosques (\(result.skipped) skipped) \
            in \(result.milliseconds, format: .fixed(precision: 1)) ms, \
            on the main thread: \(result.decodedOnMainThread, privacy: .public)
            """)
    }

    // MARK: - Location

    /// One fix → `userLocation`, the nearest mosques and `locationState`,
    /// because the user asked (a button, a route): asks for permission the
    /// first time, and with "Precise Location" off may ask once for a precise
    /// fix. DEBUG `-MSMosqueLocation` replaces CoreLocation with a fixed point.
    func locateUser() async {
        await locate(askForPrecise: true)
    }

    /// Concurrent callers share one locate.
    private func locate(askForPrecise: Bool) async {
        if let locateTask {
            await locateTask.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLocate(askForPrecise: askForPrecise)
        }
        locateTask = task
        defer { if locateTask == task { locateTask = nil } }
        await task.value
    }

    private func performLocate(askForPrecise: Bool) async {
        await loadDataset()
        #if DEBUG
        if let fake = debugOverrides.location {
            useLocation(fake, source: "-MSMosqueLocation")
            return
        }
        #endif
        let provider = makeLocationProvider()
        locationState = .locating
        switch await provider.requestOneShot(askForPrecise: askForPrecise) {
        case .located(let point): useLocation(point, source: "CoreLocation")
        case .denied: forgetLocation(becoming: .denied)
        case .restricted: forgetLocation(becoming: .restricted)
        case .failed: locateFailed()
        }
    }

    /// Meters from the user, or nil without a location.
    func distance(to mosque: Mosque) -> Double? {
        guard let userLocation else { return nil }
        return MosqueCatalog.meters(from: userLocation, to: mosque.point)
    }

    private func makeLocationProvider() -> LocationProvider {
        if let locationProvider { return locationProvider }
        let provider = LocationProvider()
        provider.onPermissionChange = { [weak self] permission in
            self?.permissionDidChange(permission)
        }
        locationProvider = provider
        return provider
    }

    /// Reads the permission (making the provider the first time) and acts on
    /// it. DEBUG fake location: nothing to follow.
    private func followPermission() {
        #if DEBUG
        guard debugOverrides.location == nil else { return }
        #endif
        permissionDidChange(makeLocationProvider().permission)
    }

    /// The permission changed (or is first read) while no request runs.
    private func permissionDidChange(_ permission: LocationProvider.Permission) {
        guard locationState != .locating else { return }
        switch permission {
        case .authorized:
            // Allowed earlier, or just now in Settings: locate without asking —
            // only while the screen is up, and without the "precise location"
            // prompt (nobody tapped anything). `.locating` right away, so a
            // repeated callback doesn't locate twice.
            guard userLocation == nil, isScreenVisible else { return }
            locationState = .locating
            Task { [weak self] in await self?.locate(askForPrecise: false) }
        case .denied:
            forgetLocation(becoming: .denied)
        case .restricted:
            forgetLocation(becoming: .restricted)
        case .notDetermined:
            if userLocation == nil { locationState = .notDetermined }
        }
    }

    private func useLocation(_ point: GeoPoint, source: String) {
        userLocation = point
        // Only mosques within reach: abroad the list stays empty.
        nearby = catalog.nearest(to: point, limit: Self.nearbyCount, within: MosqueCatalog.nearbyRadiusMeters)
        locationState = .located
        if selected == nil { focusRequest += 1 }
        let list = nearby.map { "\($0.mosque.name ?? $0.mosque.nameRu ?? $0.id) \(Int($0.meters)) m" }
        let spot = MosqueLog.describe(point)
        MosqueLog.nearUser("located at \(spot) via \(source); nearest: \(list.joined(separator: "; "))")
    }

    /// No permission any more: drop the location and everything built on it.
    private func forgetLocation(becoming state: MosqueLocationState) {
        // CoreLocation repeats the permission once right after start-up.
        guard userLocation != nil || locationState != state else { return }
        if userLocation != nil { clearRoute() }
        userLocation = nil
        nearby = []
        locationState = state
        MosqueLog.logger.info("location: \(String(describing: state), privacy: .public)")
    }

    /// No fix this time. An earlier fix (if any) stays — still more useful
    /// than nothing; without one the state says it failed.
    private func locateFailed() {
        guard userLocation != nil else {
            locationState = .failed
            return
        }
        locationState = .located
        MosqueLog.logger.notice("location: no new fix, keeping the last one")
    }

    // MARK: - Selection + route

    /// Selects a mosque and moves the map to it. nil clears the selection and
    /// the route (the map stays where it is).
    func select(_ mosque: Mosque?) {
        guard let mosque else {
            selected = nil
            clearRoute()
            return
        }
        // A route (or one on its way) to another mosque no longer applies.
        if let routeTarget = route?.mosqueID ?? routingMosqueID, routeTarget != mosque.id {
            clearRoute()
        }
        selected = mosque
        focusRequest += 1
    }

    /// Draws the way to `mosque`: a straight line with its length and an
    /// estimated walk, worked out on the device — the user's location never
    /// leaves it (Apple Maps has no walking routes in Uzbekistan anyway; real
    /// navigation is the hand-off). Locates the user first when needed, which
    /// is the only wait; a newer request wins.
    func showRoute(to mosque: Mosque) async {
        routeRequestID += 1
        let requestID = routeRequestID
        routingMosqueID = mosque.id
        if route?.mosqueID != mosque.id { route = nil }
        isRouting = true
        if userLocation == nil { await locateUser() }
        // While locating, another route (or a clear) may have been asked for.
        guard requestID == routeRequestID else { return }
        guard let start = userLocation else {
            endRouting()
            MosqueLog.logger.notice("route: no location, nothing to draw")
            return
        }
        let line = MosqueRoute.straightLine(from: start, to: mosque.point, mosqueID: mosque.id)
        route = line
        endRouting()
        logRoute(line)
    }

    func clearRoute() {
        routeRequestID += 1
        route = nil
        endRouting()
    }

    private func endRouting() {
        isRouting = false
        routingMosqueID = nil
    }

    private func logRoute(_ route: MosqueRoute) {
        let minutes = Int((route.seconds / 60).rounded())
        let length = "\(Int(route.meters)) m, ≈\(minutes) min, \(route.points.count) points"
        MosqueLog.nearUser("route: straight line to \(route.mosqueID): \(length)")
    }

    // MARK: - Map, search, names

    /// The mosques inside the visible region; over `limit`, the ones nearest
    /// its centre.
    func visibleMosques(
        minLatitude: Double, maxLatitude: Double, minLongitude: Double, maxLongitude: Double, limit: Int
    ) -> [Mosque] {
        catalog.inBox(
            minLatitude: minLatitude, maxLatitude: maxLatitude,
            minLongitude: minLongitude, maxLongitude: maxLongitude, limit: limit
        )
    }

    /// What the map draws for `viewport`: single mosques, and one round badge
    /// with the count where pins would pile up (see `MosqueClustering`). The
    /// selected mosque is always its own pin.
    func mapItems(in viewport: GeoBounds, grid: MosqueClustering.Grid) -> [MosqueMapItem] {
        MosqueClustering.items(for: mosques, in: viewport, grid: grid, selectedID: selected?.id)
    }

    /// Case-, accent- and script-insensitive ("juma" finds "Жума" and back);
    /// nearest first when the location is known, else A→Z.
    func search(_ query: String, limit: Int) -> [Mosque] {
        catalog.search(query, near: userLocation, limit: limit)
    }

    /// The name to show in the app's language, or nil for an unnamed mosque
    /// (the UI then says just "Masjid").
    func displayName(of mosque: Mosque, locale: AppLocale) -> String? {
        MosqueCatalog.displayName(of: mosque, locale: locale)
    }

    // MARK: - Hand-off

    /// Hand-off targets that can be opened on this device, in hand-off order.
    /// All of them: each has a fallback (website / browser / App Store /
    /// Apple Maps itself), so none is ever a dead button.
    func availableApps() -> [MapApp] { MapApp.allCases }

    /// Opens the route to `mosque` in another app. Only the mosque's position
    /// leaves the device — each app starts at its own live location. `locale`
    /// is the app's language (Yandex Go `lang`, the Apple Maps pin name).
    /// Failures are logged; every app has a fallback.
    func open(_ mosque: Mosque, in app: MapApp, mode: TravelMode, locale: AppLocale) {
        Task { await MapHandoffOpener.open(mosque, in: app, mode: mode, locale: locale) }
    }

    /// The same without a language: uses the one iOS was told about
    /// (`AppleLanguages`), Uzbek (Latin) by default.
    func open(_ mosque: Mosque, in app: MapApp, mode: TravelMode) {
        open(mosque, in: app, mode: mode, locale: MapHandoffOpener.appLocale())
    }

    /// The app's page in Settings, to turn location back on.
    func openLocationSettings() {
        Task { await MapHandoffOpener.openSettings() }
    }
}
