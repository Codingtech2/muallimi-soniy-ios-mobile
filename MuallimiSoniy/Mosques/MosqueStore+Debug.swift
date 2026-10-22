#if DEBUG
import Foundation
import OSLog

/// QA-only launch overrides for the mosques map, parsed in MuallimiSoniyApp:
/// a fixed user location instead of CoreLocation, a mosque to select, a
/// logged self-test and a hand-off to open — so headless QA reaches every
/// state without a tap.
nonisolated struct MosqueDebugOverrides: Sendable {
    /// `-MSMosqueLocation <lat,lon>`.
    var location: GeoPoint?
    /// `-MSMosqueSelect <id|nearest>`.
    var selectID: String?
    /// `-MSMosqueSelfTest`: logs the nearest list, searches and a route.
    var selfTest = false
    /// `-MSMosqueOpen <yandexMaps|googleMaps|yandexGo|appleMaps>`.
    var openApp: MapApp?

    var isEmpty: Bool { location == nil && selectID == nil && !selfTest && openApp == nil }
}

extension MosqueStore {
    /// Runs the overrides once, after the first load, without holding up the screen.
    func startDebugOverridesOnce() {
        guard !didStartDebugOverrides, !debugOverrides.isEmpty else { return }
        didStartDebugOverrides = true
        let overrides = debugOverrides
        Task { [weak self] in await self?.runDebugOverrides(overrides) }
    }

    private func runDebugOverrides(_ overrides: MosqueDebugOverrides) async {
        // A fixed location stands for the user saying yes to the nearest mosques.
        if overrides.location != nil { await findNearest() }
        if let id = overrides.selectID { selectForDebug(id) }
        if overrides.selfTest { await runSelfTest() }
        guard let app = overrides.openApp else { return }
        guard let target = selected ?? nearby.first?.mosque else {
            MosqueLog.logger.error("debug: nothing to open in \(app.rawValue, privacy: .public)")
            return
        }
        open(target, in: app, mode: .walking)
    }

    /// `nearest` picks the closest mosque; anything else is a dataset id.
    private func selectForDebug(_ id: String) {
        let target = id == "nearest" ? nearby.first?.mosque : mosques.first { $0.id == id }
        guard let target else {
            MosqueLog.logger.error("debug: no mosque \(id, privacy: .public) to select")
            return
        }
        select(target)
        let name = displayName(of: target, locale: .uzLatn) ?? "-"
        MosqueLog.logger.info("debug: selected \(target.id, privacy: .public) \(name, privacy: .public)")
    }

    private func runSelfTest() async {
        let apps = availableApps().map(\.rawValue).joined(separator: ", ")
        MosqueLog.logger.info("self-test: \(self.mosques.count) mosques loaded, apps \(apps, privacy: .public)")
        if userLocation == nil { await locateUser() }
        for (rank, item) in nearby.enumerated() {
            let name = displayName(of: item.mosque, locale: .uzLatn) ?? "Masjid"
            let minutes = Int((MosqueRoute.estimatedWalkSeconds(forMeters: item.meters) / 60).rounded())
            let distance = "\(Int(item.meters)) m, ≈\(minutes) min"
            MosqueLog.nearUser("self-test: nearest #\(rank + 1) \(item.id) \(name) — \(distance)")
        }
        for query in ["juma", "жума", "минор", "minor", "xoʻja"] {
            let hits = await search(query, limit: 100)
            let names = hits.prefix(3).map { displayName(of: $0, locale: .uzLatn) ?? $0.id }
            let sample = names.joined(separator: "; ")
            MosqueLog.logger.info(
                "self-test: search \"\(query, privacy: .public)\" → \(hits.count) hits: \(sample, privacy: .public)"
            )
        }
        let visible = visibleMosques(
            minLatitude: 41.2, maxLatitude: 41.4, minLongitude: 69.1, maxLongitude: 69.4, limit: 150
        )
        MosqueLog.logger.info("self-test: Tashkent box shows \(visible.count) markers (cap 150)")
        guard let target = selected ?? nearby.first?.mosque else {
            MosqueLog.logger.error("self-test: no mosque to route to")
            return
        }
        let clock = ContinuousClock()
        let started = clock.now
        await showRoute(to: target)
        let milliseconds = MosqueLog.milliseconds(clock.now - started)
        let kind = route.map { $0.isStraightLine ? "straight line" : "a routed line" } ?? "none"
        MosqueLog.logger.info(
            "self-test: done, route = \(kind, privacy: .public) in \(milliseconds, format: .fixed(precision: 2)) ms"
        )
    }
}
#endif
