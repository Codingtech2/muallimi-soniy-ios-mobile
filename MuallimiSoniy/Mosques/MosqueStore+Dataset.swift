import Foundation

// The store's dataset loading: reads + decodes the bundled
// Resources/mosques-uz.json and builds the search index, all off the main
// actor (`MosqueStore.loadDataset()` runs it in a detached task).

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
        let elapsed = clock.now - start
        let milliseconds = Double(elapsed.components.seconds) * 1000
            + Double(elapsed.components.attoseconds) / 1e15
        return DatasetLoad(
            catalog: catalog, generatedAt: generatedAt, skipped: skipped, problem: problem,
            milliseconds: milliseconds, decodedOnMainThread: Thread.isMainThread
        )
    }

    private nonisolated static func readBundledDataset() throws -> MosqueDataset {
        guard let url = Bundle.main.url(forResource: "mosques-uz", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(MosqueDataset.self, from: Data(contentsOf: url))
    }
}
