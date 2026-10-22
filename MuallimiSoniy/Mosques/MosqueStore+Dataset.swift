import Foundation

// The store's work off the main actor: reads + decodes the bundled
// Resources/mosques-uz.json and builds the search index
// (`MosqueStore.loadDataset()` runs it in a detached task), and finds the
// nearest mosques once the user is located.

extension MosqueStore {
    /// What the off-main decode hands back to the store.
    nonisolated struct DatasetLoad: Sendable {
        let catalog: MosqueCatalog
        let generatedAt: String?
        /// Records dropped for unusable coordinates.
        let skipped: Int
        let problem: String?
        let milliseconds: Double
        let decodedOnMainThread: Bool
    }

    /// Reads + decodes `Resources/mosques-uz.json` and builds the search
    /// index. Never throws: a missing or broken file gives an empty catalog
    /// and a `problem` to log.
    nonisolated static func decodeBundledDataset() -> DatasetLoad {
        let clock = ContinuousClock()
        let start = clock.now
        var mosques: [Mosque] = []
        var generatedAt: String?
        var problem: String?
        var skipped = 0
        do {
            let dataset = try readBundledDataset()
            mosques = dataset.mosques.filter(\.point.isValid)
            skipped = dataset.mosques.count - mosques.count
            generatedAt = dataset.generatedAt
        } catch {
            problem = "could not load mosques-uz.json: \(error)"
        }
        let catalog = MosqueCatalog(mosques: mosques)
        let milliseconds = MosqueLog.milliseconds(clock.now - start)
        return DatasetLoad(
            catalog: catalog, generatedAt: generatedAt, skipped: skipped, problem: problem,
            milliseconds: milliseconds, decodedOnMainThread: Thread.isMainThread
        )
    }

    /// What the off-main nearest-mosques search hands back to the store.
    nonisolated struct NearbySearch: Sendable {
        let nearby: [NearbyMosque]
        let milliseconds: Double
        let ranOnMainThread: Bool
    }

    /// The closest `limit` mosques within `MosqueCatalog.nearbyRadiusMeters`
    /// of `point`. Called in a detached task, so the measuring and the sort
    /// never hold up the main thread.
    nonisolated static func searchNearby(
        in catalog: MosqueCatalog, around point: GeoPoint, limit: Int
    ) -> NearbySearch {
        let clock = ContinuousClock()
        let start = clock.now
        let nearby = catalog.nearest(to: point, limit: limit, within: MosqueCatalog.nearbyRadiusMeters)
        let milliseconds = MosqueLog.milliseconds(clock.now - start)
        return NearbySearch(nearby: nearby, milliseconds: milliseconds, ranOnMainThread: Thread.isMainThread)
    }

    private nonisolated static func readBundledDataset() throws -> MosqueDataset {
        guard let url = Bundle.main.url(forResource: "mosques-uz", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(MosqueDataset.self, from: Data(contentsOf: url))
    }
}
