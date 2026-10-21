import Foundation

// Grid clustering for the mosques map: where pins would pile up, one round
// badge with their count instead. Pure Foundation on purpose — it also
// compiles on its own in tools/mosques-check. iOS-only, no web counterpart yet.

/// A latitude/longitude box in degrees. Never crosses ±180° (min ≤ max).
nonisolated struct GeoBounds: Hashable, Sendable {
    var minLatitude: Double
    var maxLatitude: Double
    var minLongitude: Double
    var maxLongitude: Double

    var latitudeSpan: Double { maxLatitude - minLatitude }
    var longitudeSpan: Double { maxLongitude - minLongitude }

    var center: GeoPoint {
        GeoPoint(latitude: (minLatitude + maxLatitude) / 2, longitude: (minLongitude + maxLongitude) / 2)
    }

    /// Finite, inside the valid ranges and the right way round.
    var isValid: Bool {
        GeoPoint(latitude: minLatitude, longitude: minLongitude).isValid
            && GeoPoint(latitude: maxLatitude, longitude: maxLongitude).isValid
            && minLatitude <= maxLatitude
            && minLongitude <= maxLongitude
    }

    func contains(_ point: GeoPoint) -> Bool {
        (minLatitude...maxLatitude).contains(point.latitude) && (minLongitude...maxLongitude).contains(point.longitude)
    }
}

nonisolated extension GeoBounds {
    /// The smallest box around the valid `points`; nil when there is none.
    init?(around points: [GeoPoint]) {
        let valid = points.filter(\.isValid)
        guard let first = valid.first else { return nil }
        self.init(
            minLatitude: first.latitude, maxLatitude: first.latitude,
            minLongitude: first.longitude, maxLongitude: first.longitude
        )
        for point in valid.dropFirst() {
            minLatitude = min(minLatitude, point.latitude)
            maxLatitude = max(maxLatitude, point.latitude)
            minLongitude = min(minLongitude, point.longitude)
            maxLongitude = max(maxLongitude, point.longitude)
        }
    }
}

/// Several mosques drawn as one round badge with their count.
nonisolated struct MosqueCluster: Identifiable, Hashable, Sendable {
    /// The grid cell it stands for: "cluster:<lat step>:<lon step>:<row>:<column>".
    /// Stays the same while the zoom level stays, however the map is panned.
    let id: String
    /// The average position of its mosques.
    let center: GeoPoint
    let count: Int
    /// The box around its mosques — a tap zooms the map to it.
    let bounds: GeoBounds
}

/// One thing the map draws: a mosque pin or a cluster badge.
nonisolated enum MosqueMapItem: Identifiable, Hashable, Sendable {
    case single(Mosque)
    case cluster(MosqueCluster)

    var id: String {
        switch self {
        case .single(let mosque): return mosque.id
        case .cluster(let cluster): return cluster.id
        }
    }

    var point: GeoPoint {
        switch self {
        case .single(let mosque): return mosque.point
        case .cluster(let cluster): return cluster.center
        }
    }
}

/// Puts the mosques in view into a GLOBAL grid of roughly `cellPoints`
/// squares; a cell holding two or more becomes one cluster at their average
/// position. The grid is anchored at 0°/0° and its cell size is the visible
/// span cut into the grid, rounded to a power of two of a degree — so panning
/// never moves a cell edge, and the clusters only change when the zoom
/// crosses a step. Mosques gather near cell edges (a city on a border), so a
/// last pass merges neighbours whose badges would still touch on screen.
/// Cheap enough to rerun on every camera stop: one pass over the mosques, a
/// dictionary, and a merge over the few dozen piles left.
nonisolated enum MosqueClustering {
    /// Wanted cell size on screen, in points (cells come out 45–90 pt).
    static let cellPoints = 64.0
    /// Narrower than this (about 1.7 km across in Tashkent) every mosque is
    /// drawn on its own: pins no longer pile up.
    static let streetLongitudeSpan = 0.02
    /// Last resort: never more items than this, whatever the input.
    static let maxItems = 400
    /// A pin's round head reaches about this far from its point, in points.
    static let pinReach = 16.0
    /// Room kept between two drawn items, in points.
    static let gap = 4.0
    /// Merge passes at most (a merged badge is bigger and may touch another).
    fileprivate static let mergePasses = 3
    /// Cells stay between 2^-20° (about 10 cm, which also keeps the cell
    /// indices well inside `Int`) and 2^9° (bigger than any map).
    fileprivate static let exponentRange = -20...9

    /// The map's size in cells.
    struct Grid: Hashable, Sendable {
        let columns: Double
        let rows: Double

        init(columns: Double, rows: Double) {
            self.columns = columns
            self.rows = rows
        }

        /// From the map's size in points: about one cell per `cellPoints`.
        init(mapWidth: Double, mapHeight: Double) {
            self.init(columns: mapWidth / MosqueClustering.cellPoints, rows: mapHeight / MosqueClustering.cellPoints)
        }

        var isValid: Bool { columns.isFinite && rows.isFinite && columns > 0 && rows > 0 }
    }

    /// A badge's diameter in points: 34 for a handful, about 44 at 100 and
    /// 54 from a few thousand up.
    static func badgeDiameter(for count: Int) -> Double {
        min(max(30 + 7 * log10(Double(max(count, 1))), 34), 54)
    }

    /// What to draw for `viewport`: clusters and single mosques for every
    /// grid cell touching it, plus one ring of cells around it (whole cells,
    /// so a badge near the edge counts every mosque of its cell). The selected
    /// mosque is always a single — left out of its cell's count — and is
    /// returned even when it lies outside the viewport.
    static func items(
        for mosques: [Mosque], in viewport: GeoBounds, grid: Grid, selectedID: String? = nil
    ) -> [MosqueMapItem] {
        let selected = selectedID.flatMap { id in mosques.first { $0.id == id && $0.point.isValid } }
        let tail = selected.map { [MosqueMapItem.single($0)] } ?? []
        guard viewport.isValid, grid.isValid, let cell = CellSize(viewport: viewport, grid: grid) else { return tail }
        let others = mosques.filter { $0.id != selected?.id && $0.point.isValid }
        let piles = group(others, in: viewport, cell: cell)
        let items: [MosqueMapItem]
        if viewport.longitudeSpan < streetLongitudeSpan {
            items = piles.flatMap { $0.members.sorted { $0.id < $1.id }.map(MosqueMapItem.single) }
        } else {
            let scale = ScreenScale(viewport: viewport, grid: grid)
            items = merged(piles, scale: scale).compactMap { $0.item(cell: cell) }
        }
        return capped(items, around: viewport.center, limit: maxItems - tail.count) + tail
    }

    // MARK: - Grid

    /// The mosques of every cell touching the viewport or the ring of cells
    /// around it, one pile per cell, in a fixed (row, column) order.
    private static func group(_ mosques: [Mosque], in viewport: GeoBounds, cell: CellSize) -> [Pile] {
        let rows = range(from: viewport.minLatitude, to: viewport.maxLatitude, cellSize: cell.latitude)
        let columns = range(from: viewport.minLongitude, to: viewport.maxLongitude, cellSize: cell.longitude)
        var cells: [CellKey: [Mosque]] = [:]
        for mosque in mosques {
            let key = CellKey(row: index(mosque.lat, cell.latitude), column: index(mosque.lon, cell.longitude))
            guard rows.contains(key.row), columns.contains(key.column) else { continue }
            cells[key, default: []].append(mosque)
        }
        return cells.sorted { $0.key < $1.key }.map { Pile(key: $0.key, members: $0.value) }
    }

    /// Which cell `degrees` falls in, counting from 0°.
    private static func index(_ degrees: Double, _ cellSize: Double) -> Int {
        Int((degrees / cellSize).rounded(.down))
    }

    /// The cells from `low` to `high`, plus one more on each side.
    private static func range(from low: Double, to high: Double, cellSize: Double) -> ClosedRange<Int> {
        (index(low, cellSize) - 1)...(index(high, cellSize) + 1)
    }

    // MARK: - Merging

    /// Piles whose drawn items would touch on screen become one. Biggest
    /// first (then by cell, a fixed order), each pile joins the first kept
    /// pile it touches; repeated, as a grown badge may now touch another.
    private static func merged(_ piles: [Pile], scale: ScreenScale) -> [Pile] {
        var current = piles
        for _ in 0..<mergePasses {
            let ordered = current.sorted { $0.count != $1.count ? $0.count > $1.count : $0.key < $1.key }
            var kept: [Pile] = []
            for pile in ordered {
                if let index = kept.firstIndex(where: { scale.touches($0, pile) }) {
                    kept[index].absorb(pile)
                } else {
                    kept.append(pile)
                }
            }
            let changed = kept.count != current.count
            current = kept
            if !changed { break }
        }
        return current.sorted { $0.key < $1.key }
    }

    /// Last resort: with more than `limit` items, keeps the ones nearest the
    /// viewport centre (a fixed order on ties).
    private static func capped(_ items: [MosqueMapItem], around center: GeoPoint, limit: Int) -> [MosqueMapItem] {
        guard items.count > limit else { return items }
        // A degree of longitude is shorter than one of latitude away from the equator.
        let squeeze = cos(center.latitude * .pi / 180)
        func distance(_ point: GeoPoint) -> Double {
            let north = point.latitude - center.latitude
            let east = (point.longitude - center.longitude) * squeeze
            return north * north + east * east
        }
        let ordered = items
            .map { (item: $0, distance: distance($0.point)) }
            .sorted { $0.distance != $1.distance ? $0.distance < $1.distance : $0.item.id < $1.item.id }
        return ordered.prefix(max(limit, 0)).map(\.item)
    }
}

/// A cell of the global grid: its row (latitude) and column (longitude).
nonisolated private struct CellKey: Hashable, Comparable {
    let row: Int
    let column: Int

    static func < (left: CellKey, right: CellKey) -> Bool {
        (left.row, left.column) < (right.row, right.column)
    }
}

/// The mosques of one cell — or of several cells merged into the first one.
nonisolated private struct Pile {
    /// The cell it started from; names the cluster.
    let key: CellKey
    private(set) var members: [Mosque]
    private var latitudeSum: Double
    private var longitudeSum: Double

    init(key: CellKey, members: [Mosque]) {
        self.key = key
        self.members = members
        latitudeSum = members.reduce(0) { $0 + $1.lat }
        longitudeSum = members.reduce(0) { $0 + $1.lon }
    }

    var count: Int { members.count }

    /// The average position of its mosques.
    var center: GeoPoint {
        let count = Double(max(members.count, 1))
        return GeoPoint(latitude: latitudeSum / count, longitude: longitudeSum / count)
    }

    mutating func absorb(_ other: Pile) {
        members += other.members
        latitudeSum += other.latitudeSum
        longitudeSum += other.longitudeSum
    }

    /// A single for one mosque, a cluster named after its first cell for
    /// more; nil for an empty pile (never made).
    func item(cell: CellSize) -> MosqueMapItem? {
        guard members.count > 1 else { return members.first.map(MosqueMapItem.single) }
        guard let bounds = GeoBounds(around: members.map(\.point)) else { return nil }
        return .cluster(MosqueCluster(id: clusterID(cell), center: center, count: members.count, bounds: bounds))
    }

    private func clusterID(_ cell: CellSize) -> String {
        "cluster:\(cell.latitudeExponent):\(cell.longitudeExponent):\(key.row):\(key.column)"
    }
}

/// Degrees → points on the current map, to tell whether two items touch.
nonisolated private struct ScreenScale {
    let pointsPerLatitude: Double
    let pointsPerLongitude: Double

    init(viewport: GeoBounds, grid: MosqueClustering.Grid) {
        let width = grid.columns * MosqueClustering.cellPoints
        let height = grid.rows * MosqueClustering.cellPoints
        pointsPerLatitude = viewport.latitudeSpan > 0 ? height / viewport.latitudeSpan : 0
        pointsPerLongitude = viewport.longitudeSpan > 0 ? width / viewport.longitudeSpan : 0
    }

    /// Whether the two piles' pins or badges would overlap (with a small gap).
    func touches(_ first: Pile, _ second: Pile) -> Bool {
        let north = (first.center.latitude - second.center.latitude) * pointsPerLatitude
        let east = (first.center.longitude - second.center.longitude) * pointsPerLongitude
        let room = reach(first.count) + reach(second.count) + MosqueClustering.gap
        return (north * north + east * east).squareRoot() < room
    }

    private func reach(_ count: Int) -> Double {
        count > 1 ? MosqueClustering.badgeDiameter(for: count) / 2 : MosqueClustering.pinReach
    }
}

/// The grid's cell size at one zoom level, as powers of two of a degree.
nonisolated private struct CellSize {
    let latitudeExponent: Int
    let longitudeExponent: Int

    var latitude: Double { exp2(Double(latitudeExponent)) }
    var longitude: Double { exp2(Double(longitudeExponent)) }

    /// The visible span cut into the grid, rounded to the nearest power of
    /// two (cells of 45–90 pt); nil when the span or the grid is empty.
    init?(viewport: GeoBounds, grid: MosqueClustering.Grid) {
        guard let latitude = Self.exponent(viewport.latitudeSpan / grid.rows),
              let longitude = Self.exponent(viewport.longitudeSpan / grid.columns) else { return nil }
        latitudeExponent = latitude
        longitudeExponent = longitude
    }

    private static func exponent(_ degrees: Double) -> Int? {
        guard degrees.isFinite, degrees > 0 else { return nil }
        let range = MosqueClustering.exponentRange
        let rounded = log2(degrees).rounded()
        return Int(min(max(rounded, Double(range.lowerBound)), Double(range.upperBound)))
    }
}
