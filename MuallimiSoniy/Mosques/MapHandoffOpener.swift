import Foundation
import CoreLocation
import MapKit
import OSLog
import UIKit

/// Opens a route to a mosque in another app — the UIKit side of the hand-off.
/// The links come from `MapHandoff`; every app has a fallback, so a tap never
/// silently does nothing. Only the mosque's position leaves the device: the
/// user's location is never put in a link, each app starts the route at its
/// own live location. iOS-only, no web counterpart yet.
@MainActor
enum MapHandoffOpener {
    /// Opens `mosque` in `app`. `locale` is the app's language: Yandex Go's
    /// `lang` and the pin name Apple Maps shows.
    static func open(_ mosque: Mosque, in app: MapApp, mode: TravelMode, locale: AppLocale) async {
        let destination = mosque.point
        let opened: Bool
        switch app {
        case .yandexMaps: opened = await openYandexMaps(to: destination, mode: mode)
        case .googleMaps: opened = await openGoogleMaps(to: destination, mode: mode)
        case .yandexGo: opened = await openYandexGo(to: destination, locale: locale)
        case .appleMaps: opened = openAppleMaps(mosque, mode: mode, locale: locale)
        }
        if opened {
            MosqueLog.nearUser("hand-off: opened \(app.rawValue) for \(mosque.id)")
        } else {
            MosqueLog.logger.error("hand-off: could not open \(app.rawValue, privacy: .public)")
            MosqueLog.nearUser("hand-off: \(app.rawValue) failed for \(mosque.id)")
        }
    }

    /// The app's own page in Settings, where its location permission lives.
    static func openSettings() async {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if await !UIApplication.shared.open(url) {
            MosqueLog.logger.error("settings: could not open the app's Settings page")
        }
    }

    /// The language the app runs in as far as iOS knows: `SettingsStore.setLocale`
    /// (and iOS's per-app language setting) write it to this app's own
    /// `AppleLanguages`; with none there it's the default, Uzbek (Latin).
    /// Only for callers that don't pass the app's locale themselves.
    static func appLocale() -> AppLocale {
        let domain = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0) }
        let code = (domain?["AppleLanguages"] as? [String])?.first?.lowercased() ?? ""
        if code.hasPrefix("uz-cyrl") { return .uzCyrl }
        if code.hasPrefix("ru") { return .ru }
        if code.hasPrefix("en") { return .en }
        return .uzLatn
    }

    // MARK: - Apps

    /// The Yandex Maps app when it's installed, else the same route on yandex.uz.
    /// An empty start makes Yandex begin at the phone's own location.
    private static func openYandexMaps(to destination: GeoPoint, mode: TravelMode) async -> Bool {
        if let appURL = MapHandoff.yandexMapsAppURL(to: destination, from: nil, mode: mode),
           UIApplication.shared.canOpenURL(appURL),
           await UIApplication.shared.open(appURL) {
            return true
        }
        MosqueLog.logger.info("hand-off: no Yandex Maps app, opening yandex.uz")
        guard let webURL = MapHandoff.yandexMapsWebURL(to: destination, from: nil, mode: mode) else { return false }
        MosqueLog.nearUser("hand-off: \(webURL.absoluteString)")
        return await UIApplication.shared.open(webURL)
    }

    /// Google's link is a universal link: it opens the Google Maps app when
    /// installed; otherwise the same link opens in the browser. Without an
    /// origin Google starts at the phone's own location.
    private static func openGoogleMaps(to destination: GeoPoint, mode: TravelMode) async -> Bool {
        guard let url = MapHandoff.googleMapsURL(to: destination, from: nil, mode: mode) else { return false }
        MosqueLog.nearUser("hand-off: \(url.absoluteString)")
        if await UIApplication.shared.open(url, options: [.universalLinksOnly: true]) {
            return true
        }
        MosqueLog.logger.info("hand-off: no Google Maps app, opening the browser")
        return await UIApplication.shared.open(url)
    }

    /// Yandex Go's link opens the app (which picks the user up where they
    /// are), or the App Store for people without it.
    private static func openYandexGo(to destination: GeoPoint, locale: AppLocale) async -> Bool {
        let language = MapHandoff.yandexGoLanguage(for: locale)
        guard let url = MapHandoff.yandexGoURL(to: destination, from: nil, language: language) else { return false }
        MosqueLog.nearUser("hand-off: \(url.absoluteString)")
        return await UIApplication.shared.open(url)
    }

    /// Apple Maps through MapKit; it starts the route at the phone's location.
    private static func openAppleMaps(_ mosque: Mosque, mode: TravelMode, locale: AppLocale) -> Bool {
        let item = mapItem(at: mosque.point)
        item.name = MosqueCatalog.displayName(of: mosque, locale: locale)
        let directionsMode = switch mode {
        case .walking: MKLaunchOptionsDirectionsModeWalking
        case .driving: MKLaunchOptionsDirectionsModeDriving
        }
        return item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: directionsMode])
    }

    /// A map item at `point`: the iOS 26 initializer when available, the
    /// placemark one (deprecated in iOS 26) before that.
    private static func mapItem(at point: GeoPoint) -> MKMapItem {
        if #available(iOS 26, *) {
            return MKMapItem(location: CLLocation(latitude: point.latitude, longitude: point.longitude), address: nil)
        } else {
            let coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
            return MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        }
    }
}
