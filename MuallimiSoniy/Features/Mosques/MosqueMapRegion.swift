import Foundation
import MapKit

/// Camera maths for the mosques map: where it opens, how close it zooms in
/// on a mosque or a cluster, and the region that fits a set of points.
nonisolated enum MosqueMapRegion {
    /// Tashkent centre — where the map opens before the user is located.
    static let defaultCenter = GeoPoint(latitude: 41.3111, longitude: 69.2797)
    /// About a city across: the opening view without a location.
    static let citySpan = 0.12
    /// A few streets across: how close a chosen mosque is shown.
    static let streetSpan = 0.012
    /// Never zoom in closer than this when fitting points (about 600 m).
    static let minimumSpan = 0.006
    /// Room around fitted points so the pins don't sit on the map's edge.
    static let fitPadding = 1.6

    static func coordinate(_ point: GeoPoint) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
    }

    static func region(around point: GeoPoint, span: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate(point),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }

    /// The smallest padded region holding every valid point; nil without one.
    static func region(fitting points: [GeoPoint]) -> MKCoordinateRegion? {
        GeoBounds(around: points).map(region(fitting:))
    }

    /// `box` with room around it, never closer than `minimumSpan`.
    static func region(fitting box: GeoBounds) -> MKCoordinateRegion {
        let latitudeSpan = min(max(box.latitudeSpan * fitPadding, minimumSpan), 90)
        let longitudeSpan = min(max(box.longitudeSpan * fitPadding, minimumSpan), 180)
        return MKCoordinateRegion(
            center: coordinate(box.center),
            span: MKCoordinateSpan(latitudeDelta: latitudeSpan, longitudeDelta: longitudeSpan)
        )
    }

    /// `region` zoomed in `factor` times around `point`.
    static func zoomedIn(_ region: MKCoordinateRegion, around point: GeoPoint, factor: Double) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate(point),
            span: MKCoordinateSpan(
                latitudeDelta: max(region.span.latitudeDelta / factor, minimumSpan),
                longitudeDelta: max(region.span.longitudeDelta / factor, minimumSpan)
            )
        )
    }

    /// How close to show a chosen mosque: keep the current zoom when it is
    /// already close, otherwise come down to street level.
    static func focusSpan(current: Double?) -> Double {
        guard let current, current.isFinite, current > 0 else { return streetSpan }
        return min(max(current, minimumSpan), streetSpan * 2)
    }

    /// The region's box, clamped to the valid ranges.
    static func bounds(of region: MKCoordinateRegion) -> GeoBounds {
        let halfLatitude = abs(region.span.latitudeDelta) / 2
        let halfLongitude = abs(region.span.longitudeDelta) / 2
        return GeoBounds(
            minLatitude: max(region.center.latitude - halfLatitude, -90),
            maxLatitude: min(region.center.latitude + halfLatitude, 90),
            minLongitude: max(region.center.longitude - halfLongitude, -180),
            maxLongitude: min(region.center.longitude + halfLongitude, 180)
        )
    }
}

#if DEBUG
extension MosqueMapRegion {
    /// QA-only: `-MSMosqueCamera <lat>,<lon>,<span>` opens the map there —
    /// e.g. `41.6,64.5,14` (the whole country), `41.3111,69.2797,0.12` (the
    /// city), `41.3111,69.2797,0.015` (street level) — for zoom screenshots.
    static var debugLaunchRegion: MKCoordinateRegion? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-MSMosqueCamera"), arguments.indices.contains(index + 1) else {
            return nil
        }
        let parts = arguments[index + 1].split(separator: ",").compactMap { Double($0) }
        guard parts.count == 3 else { return nil }
        let center = GeoPoint(latitude: parts[0], longitude: parts[1])
        guard center.isValid, parts[2].isFinite, parts[2] > 0 else { return nil }
        return region(around: center, span: parts[2])
    }
}
#endif
