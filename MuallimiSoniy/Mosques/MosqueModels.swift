import Foundation

// Mosques map types. Pure Foundation on purpose: this file (with the catalog
// and the hand-off URL builders) also compiles on its own in tools/mosques-check.
// iOS-only feature for now — no web counterpart yet.

/// A point on Earth, in degrees.
nonisolated struct GeoPoint: Hashable, Codable, Sendable {
    var latitude: Double
    var longitude: Double

    /// Finite and inside the valid ranges — anything else can't be used.
    var isValid: Bool {
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

/// One mosque from the bundled OpenStreetMap dataset (`Resources/mosques-uz.json`).
nonisolated struct Mosque: Identifiable, Hashable, Codable, Sendable {
    /// OSM id with its type letter: "n123" (node), "w456" (way), "r789" (relation).
    let id: String
    let lat: Double
    let lon: Double
    /// OSM `name` — usually Uzbek (Latin or Cyrillic) or Russian.
    let name: String?
    let nameRu: String?
    let nameUz: String?

    var point: GeoPoint { GeoPoint(latitude: lat, longitude: lon) }
}

/// Root of `Resources/mosques-uz.json`, built by tools/mosques/build_mosques.py.
nonisolated struct MosqueDataset: Decodable, Sendable {
    let schemaVersion: Int
    let generatedAt: String?
    let attribution: String?
    let license: String?
    let count: Int?
    let mosques: [Mosque]
}

/// A mosque with its distance from the user.
nonisolated struct NearbyMosque: Identifiable, Hashable, Sendable {
    let mosque: Mosque
    let meters: Double

    var id: String { mosque.id }
}

/// The apps a route can be handed off to, in the order UZ users expect.
nonisolated enum MapApp: String, CaseIterable, Sendable, Hashable {
    case yandexMaps
    case googleMaps
    case yandexGo
    case appleMaps
}

nonisolated enum TravelMode: String, CaseIterable, Sendable, Hashable {
    case walking
    case driving
}

/// The line drawn from the user to a mosque. When Apple Maps has no route
/// there (it has no navigation in Uzbekistan) it is a straight line with an
/// estimated walking time — `isStraightLine` says so, so the UI can label it.
nonisolated struct MosqueRoute: Hashable, Sendable {
    let mosqueID: String
    let points: [GeoPoint]
    let meters: Double
    let seconds: Double
    let isStraightLine: Bool
}

/// Where location permission / the last fix stands.
nonisolated enum MosqueLocationState: Equatable, Sendable {
    /// Never asked yet.
    case notDetermined
    case locating
    case located
    case denied
    case restricted
    case failed
}
