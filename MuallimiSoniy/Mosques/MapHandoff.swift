import Foundation

/// Builds the links that hand a route to a mosque off to another app. Pure on
/// purpose: tools/mosques-check pins every string, and `MapHandoffOpener`
/// (the UIKit side) opens them with the fallbacks. Apple Maps has no link
/// here — it opens through `MKMapItem`. iOS-only, no web counterpart yet.
nonisolated enum MapHandoff {
    /// Referrer and AppMetrica tracking id of the Yandex Go partner route link.
    static let yandexGoReferrer = "muallimisoniy"
    static let yandexGoTrackingID = "1178268795219780156"

    /// `yandexmaps://maps.yandex.ru/?rtext=<from>~<lat>,<lon>&rtt=pd` — an
    /// empty "from" makes Yandex Maps start at the phone's location.
    static func yandexMapsAppURL(to destination: GeoPoint, from start: GeoPoint?, mode: TravelMode) -> URL? {
        guard let query = yandexRouteQuery(to: destination, from: start, mode: mode) else { return nil }
        return URL(string: "yandexmaps://maps.yandex.ru/?" + query)
    }

    /// The same route on the Yandex Maps website, when the app isn't installed.
    static func yandexMapsWebURL(to destination: GeoPoint, from start: GeoPoint?, mode: TravelMode) -> URL? {
        guard let query = yandexRouteQuery(to: destination, from: start, mode: mode) else { return nil }
        return URL(string: "https://yandex.uz/maps/?" + query)
    }

    /// Google Maps directions link (a universal link: opens the app when it's
    /// installed). `origin` is added only when the start is known.
    static func googleMapsURL(to destination: GeoPoint, from start: GeoPoint?, mode: TravelMode) -> URL? {
        guard destination.isValid else { return nil }
        var link = "https://www.google.com/maps/dir/?api=1"
            + "&destination=\(pair(destination, separator: "%2C"))"
            + "&travelmode=\(googleTravelMode(mode))"
        if let start, start.isValid {
            link += "&origin=\(pair(start, separator: "%2C"))"
        }
        return URL(string: link)
    }

    /// Yandex Go taxi to the mosque. The link opens the app, or sends people
    /// without it to the App Store. A taxi drives, so there is no travel mode.
    static func yandexGoURL(to destination: GeoPoint, from start: GeoPoint?, language: String) -> URL? {
        guard destination.isValid else { return nil }
        var items: [String] = []
        if let start, start.isValid {
            items += ["start-lat=\(coordinate(start.latitude))", "start-lon=\(coordinate(start.longitude))"]
        }
        items += [
            "end-lat=\(coordinate(destination.latitude))",
            "end-lon=\(coordinate(destination.longitude))",
            "ref=\(yandexGoReferrer)",
            "appmetrica_tracking_id=\(yandexGoTrackingID)",
            "lang=\(language)"
        ]
        return URL(string: "https://3.redirect.appmetrica.yandex.com/route?" + items.joined(separator: "&"))
    }

    /// The `lang` Yandex Go understands for the app's language.
    static func yandexGoLanguage(for locale: AppLocale) -> String {
        switch locale {
        case .uzLatn, .uzCyrl: return "uz"
        case .ru: return "ru"
        case .en: return "en"
        }
    }

    /// Six decimals (~0.1 m) with a "." separator whatever the phone's locale.
    static func coordinate(_ value: Double) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    // MARK: - Helpers

    /// `rtext=<from>~<lat>,<lon>&rtt=<pd|auto>` shared by the app and web links.
    private static func yandexRouteQuery(to destination: GeoPoint, from start: GeoPoint?, mode: TravelMode) -> String? {
        guard destination.isValid else { return nil }
        let from = start.flatMap { $0.isValid ? pair($0, separator: ",") : nil } ?? ""
        return "rtext=\(from)~\(pair(destination, separator: ","))&rtt=\(yandexTravelMode(mode))"
    }

    private static func pair(_ point: GeoPoint, separator: String) -> String {
        coordinate(point.latitude) + separator + coordinate(point.longitude)
    }

    /// Yandex `rtt`: "pd" is on foot, "auto" is by car.
    private static func yandexTravelMode(_ mode: TravelMode) -> String {
        switch mode {
        case .walking: return "pd"
        case .driving: return "auto"
        }
    }

    private static func googleTravelMode(_ mode: TravelMode) -> String {
        switch mode {
        case .walking: return "walking"
        case .driving: return "driving"
        }
    }
}
