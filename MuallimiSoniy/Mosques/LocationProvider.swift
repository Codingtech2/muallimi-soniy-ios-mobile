import Foundation
import CoreLocation
import OSLog

/// One-shot "where am I" for the nearest mosque. Asks for When-In-Use
/// permission the first time it's needed, never tracks in the background and
/// never reverse-geocodes. Mosques can be a few hundred meters apart, so it
/// wants a precise fix: with "Precise Location" off it asks for temporary
/// full accuracy — only when the user asked for their location themselves
/// (`askForPrecise`), and at most once per launch. iOS-only, no web
/// counterpart yet.
@MainActor
final class LocationProvider {

    /// How a request ended.
    nonisolated enum Outcome: Sendable {
        case located(GeoPoint)
        /// The user said no, or Location Services are off.
        case denied
        /// Parental controls / device management forbid location here.
        case restricted
        /// No fix in time, or CoreLocation gave up.
        case failed
    }

    /// The app's location permission, without CoreLocation types.
    nonisolated enum Permission: Sendable {
        case notDetermined
        case denied
        case restricted
        case authorized
    }

    /// The system's current location permission for this app.
    var permission: Permission { Self.permission(for: manager.authorizationStatus) }

    /// Called when the permission changes while no request is running — e.g.
    /// the user flipped it in Settings and came back.
    var onPermissionChange: ((Permission) -> Void)?

    private enum Phase {
        case idle
        /// The permission prompt is up.
        case authorizing
        /// The "precise location" prompt is up.
        case upgradingAccuracy
        /// Permission is there; waiting for the fix.
        case locating
    }

    /// How long a fix may take once permission is there.
    private static let fixTimeout: Duration = .seconds(15)
    /// Safety net for the permission prompts, so a caller can never wait forever.
    private static let promptTimeout: Duration = .seconds(60)
    /// Without this purpose string iOS drops the permission request silently.
    private static let usageDescriptionKey = "NSLocationWhenInUseUsageDescription"
    /// Info.plist dictionary holding the "precise location" purpose strings.
    private static let temporaryUsageKey = "NSLocationTemporaryUsageDescriptionDictionary"
    /// Our entry in that dictionary (localized in InfoPlist.xcstrings).
    private static let fullAccuracyPurposeKey = "NearestMosque"

    private let manager = CLLocationManager()
    private let delegateProxy = LocationDelegateProxy()
    private var phase: Phase = .idle
    /// Everyone awaiting the request in flight; each is resumed exactly once.
    private var waiters: [CheckedContinuation<Outcome, Never>] = []
    private var timeoutTask: Task<Void, Never>?
    /// The "precise location" prompt is asked at most once per launch.
    private var didAskFullAccuracy = false
    /// Whether the request in flight may show the "precise location" prompt.
    private var wantsPrecise = false
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MuallimiSoniy", category: "Mosques")

    init() {
        // Ten meters: enough to tell two neighbouring mosques apart.
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        delegateProxy.owner = self
        manager.delegate = delegateProxy
    }

    /// Asks for one location fix, requesting When-In-Use permission first if
    /// the user hasn't been asked yet. A call made while a request is running
    /// waits for that same answer instead of starting another one.
    /// `askForPrecise`: the user asked (a button, a route), so with "Precise
    /// Location" off the "precise location" prompt may appear. Automatic
    /// fixes pass false and just take the approximate location.
    func requestOneShot(askForPrecise: Bool) async -> Outcome {
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
            switch phase {
            case .idle:
                wantsPrecise = askForPrecise
                begin()
            case .authorizing:
                // The accuracy question comes after the permission answer.
                wantsPrecise = wantsPrecise || askForPrecise
            case .upgradingAccuracy, .locating:
                break
            }
        }
    }

    // MARK: - Request steps

    /// Starts (or continues) a request according to the current permission.
    private func begin() {
        switch manager.authorizationStatus {
        case .notDetermined:
            askPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            requestFix()
        case .denied:
            finish(.denied)
        case .restricted:
            finish(.restricted)
        @unknown default:
            finish(.failed)
        }
    }

    private func askPermission() {
        guard Bundle.main.object(forInfoDictionaryKey: Self.usageDescriptionKey) != nil else {
            logger.error("location: NSLocationWhenInUseUsageDescription is missing from Info.plist")
            finish(.failed)
            return
        }
        phase = .authorizing
        armTimeout(Self.promptTimeout)
        manager.requestWhenInUseAuthorization()
    }

    private func requestFix() {
        let reduced = manager.accuracyAuthorization == .reducedAccuracy
        let mayAsk = wantsPrecise
        logger.info(
            "location: fix wanted, reduced \(reduced, privacy: .public), may ask precise \(mayAsk, privacy: .public)"
        )
        guard reduced else {
            startFix()
            return
        }
        guard wantsPrecise, !didAskFullAccuracy, hasFullAccuracyPurpose else {
            // "Approximate location" stays: the fix can be a few km off, which
            // still points at the right part of town.
            logger.notice("location: reduced accuracy, using the approximate fix")
            startFix()
            return
        }
        didAskFullAccuracy = true
        phase = .upgradingAccuracy
        armTimeout(Self.promptTimeout)
        logger.info("location: reduced accuracy, asking for precise location once")
        // Called back on the main run loop (where the manager was made); the
        // proxy's hop keeps that explicit.
        let completion: @Sendable ((any Error)?) -> Void = { [weak self] error in
            let owner = self
            let skipped = error != nil
            LocationDelegateProxy.onMain { owner?.fullAccuracyDidFinish(promptSkipped: skipped) }
        }
        manager.requestTemporaryFullAccuracyAuthorization(
            withPurposeKey: Self.fullAccuracyPurposeKey, completion: completion
        )
    }

    /// Info.plist must carry our purpose string, or iOS never shows the prompt.
    private var hasFullAccuracyPurpose: Bool {
        let purposes = Bundle.main.object(forInfoDictionaryKey: Self.temporaryUsageKey) as? [String: Any]
        return purposes?[Self.fullAccuracyPurposeKey] != nil
    }

    private func startFix() {
        phase = .locating
        armTimeout(Self.fixTimeout)
        manager.requestLocation()
    }

    /// Ends the request and answers every waiter, each exactly once.
    private func finish(_ outcome: Outcome) {
        timeoutTask?.cancel()
        timeoutTask = nil
        if phase == .locating {
            // Cancels a `requestLocation()` that is still running.
            manager.stopUpdatingLocation()
        }
        phase = .idle
        wantsPrecise = false
        let waiting = waiters
        waiters.removeAll()
        logger.info("location: \(Self.name(of: outcome), privacy: .public)")
        for waiter in waiting {
            waiter.resume(returning: outcome)
        }
    }

    /// (Re)starts the deadline for the current step. The task holds the
    /// provider strongly on purpose: while someone is waiting it has to stay
    /// alive to answer them. `finish` cancels it, which lets go again.
    private func armTimeout(_ timeout: Duration) {
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            self.timeoutDidFire()
        }
    }

    private func timeoutDidFire() {
        guard phase != .idle else { return }
        let step = switch phase {
        case .authorizing: "waiting for permission"
        case .upgradingAccuracy: "waiting for precise location"
        default: "waiting for a fix"
        }
        logger.error("location: timed out \(step, privacy: .public)")
        finish(.failed)
    }

    private static func name(of outcome: Outcome) -> String {
        switch outcome {
        case .located: return "located"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .failed: return "failed"
        }
    }

    private static func permission(for status: CLAuthorizationStatus) -> Permission {
        switch status {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        case .authorizedWhenInUse, .authorizedAlways: return .authorized
        @unknown default: return .denied
        }
    }

    // MARK: - Delegate callbacks (forwarded by the proxy, on the main actor)

    fileprivate func authorizationDidChange() {
        switch phase {
        case .idle:
            // Also fires once right after the manager is created.
            onPermissionChange?(permission)
        case .authorizing:
            // `.notDetermined` means the prompt is still waiting for an answer.
            guard manager.authorizationStatus != .notDetermined else { return }
            begin()
        case .upgradingAccuracy, .locating:
            // Permission taken away in the middle of the request.
            switch manager.authorizationStatus {
            case .denied: finish(.denied)
            case .restricted: finish(.restricted)
            default: return
            }
        }
    }

    /// `promptSkipped`: iOS answered with an error instead of showing the prompt.
    fileprivate func fullAccuracyDidFinish(promptSkipped: Bool) {
        guard phase == .upgradingAccuracy else { return }
        let precise = manager.accuracyAuthorization == .fullAccuracy
        logger.info("location: precise \(precise, privacy: .public), prompt skipped \(promptSkipped, privacy: .public)")
        startFix()
    }

    fileprivate func didLocate(latitude: Double, longitude: Double, horizontalAccuracy: Double) {
        guard phase == .locating else { return }
        let point = GeoPoint(latitude: latitude, longitude: longitude)
        // A negative accuracy marks an invalid fix.
        guard horizontalAccuracy >= 0, point.isValid else {
            logger.error("location: the fix was invalid")
            finish(.failed)
            return
        }
        logger.debug("location: fix within \(horizontalAccuracy, format: .fixed(precision: 0)) m")
        finish(.located(point))
    }

    fileprivate func didFail(code: Int) {
        guard phase != .idle else { return }
        guard code != CLError.Code.denied.rawValue else {
            finish(.denied)
            return
        }
        logger.error("location: request failed, CLError code \(code)")
        finish(.failed)
    }
}

/// Hands CoreLocation's delegate callbacks to the provider on the main actor,
/// carrying only `Sendable` values across.
private nonisolated final class LocationDelegateProxy: NSObject, CLLocationManagerDelegate {
    weak var owner: LocationProvider?

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let owner = owner
        Self.onMain { owner?.authorizationDidChange() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // The newest fix comes last.
        guard let fix = locations.last else { return }
        let latitude = fix.coordinate.latitude
        let longitude = fix.coordinate.longitude
        let accuracy = fix.horizontalAccuracy
        let owner = owner
        Self.onMain { owner?.didLocate(latitude: latitude, longitude: longitude, horizontalAccuracy: accuracy) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        let code = (error as? CLError)?.code.rawValue ?? -1
        let owner = owner
        Self.onMain { owner?.didFail(code: code) }
    }

    /// CoreLocation calls back on the thread that created the manager — the
    /// main thread here; hop there should it ever not.
    static func onMain(_ work: @escaping @MainActor @Sendable () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { work() }
        } else {
            Task { @MainActor in work() }
        }
    }
}
