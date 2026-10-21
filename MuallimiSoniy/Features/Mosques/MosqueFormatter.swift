import Foundation

/// Short labels for the mosques screen: the name to show, "350 m" /
/// "1,2 km" and "≈ 5 daqiqa piyoda" — always in the app's language (the
/// in-app picker), never the system one. The `spoken…` variants are for
/// VoiceOver, which would read "≈" and "·" aloud.
struct MosqueFormatter {
    let content: ContentStore
    let mosques: MosqueStore
    let locale: AppLocale

    /// Past this nobody walks: no walking time and no "Yoʻl koʻrsatish".
    static let walkableMeters = 20_000.0
    /// Upper bound for a duration label (100 hours), so a broken value can
    /// never overflow the minute count.
    private static let longestDurationSeconds = 360_000.0

    // MARK: - Names

    /// The name in the app's language, or "Masjid" for a mosque without one.
    func name(of mosque: Mosque) -> String {
        mosques.displayName(of: mosque, locale: locale) ?? content.t("mosques_unnamed", locale)
    }

    /// The mosque's other names (say the Russian one under an Uzbek title),
    /// joined with " · ", or nil when there is nothing more to show.
    func otherNames(of mosque: Mosque) -> String? {
        var seen: Set<String> = [Self.folded(name(of: mosque))]
        var others: [String] = []
        for candidate in [mosque.name, mosque.nameRu, mosque.nameUz] {
            guard let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty,
                  seen.insert(Self.folded(trimmed)).inserted else { continue }
            others.append(trimmed)
        }
        return others.isEmpty ? nil : others.prefix(2).joined(separator: " · ")
    }

    // MARK: - Distance and time

    /// "350 m" under a kilometre (rounded to 10 m), "1,2 km" from there on.
    func distance(_ meters: Double) -> String {
        let safeMeters = meters.isFinite ? max(meters, 0) : 0
        let roundedMeters = max((safeMeters / 10).rounded() * 10, 10)
        if roundedMeters < 1000 {
            return String(format: content.t("mosques_distance_m", locale), number(roundedMeters, fractionDigits: 0))
        }
        let kilometers = safeMeters / 1000
        // One decimal reads well for a walk; past 100 km it's just noise.
        let digits = kilometers < 100 ? 1 : 0
        return String(format: content.t("mosques_distance_km", locale), number(kilometers, fractionDigits: digits))
    }

    /// "≈ 5 daqiqa piyoda" for a straight-line distance — the store's own
    /// straight-line estimate — or nil when nobody would walk that far.
    func walk(meters: Double) -> String? {
        walkText(meters: meters, minutesKey: "mosques_walk_minutes", hoursKey: "mosques_walk_hours")
    }

    /// "taxminan 5 daqiqa piyoda": the same walk for VoiceOver.
    func spokenWalk(meters: Double) -> String? {
        walkText(meters: meters, minutesKey: "mosques_walk_minutes_a11y", hoursKey: "mosques_walk_hours_a11y")
    }

    /// Distance and walking time for one line, e.g. "350 m · ≈ 5 daqiqa piyoda".
    func summary(meters: Double) -> String {
        [distance(meters), walk(meters: meters)].compactMap { $0 }.joined(separator: " · ")
    }

    /// "350 m, taxminan 5 daqiqa piyoda" for VoiceOver.
    func spokenSummary(meters: Double) -> String {
        [distance(meters), spokenWalk(meters: meters)].compactMap { $0 }.joined(separator: ", ")
    }

    // MARK: - Route

    /// "≈ 2,5 km · ≈ 39 daqiqa piyoda": a straight line is only an estimate.
    func routeLine(_ route: MosqueRoute) -> String {
        let length = route.isStraightLine ? "≈ " + distance(route.meters) : distance(route.meters)
        return [length, walk(meters: route.meters)].compactMap { $0 }.joined(separator: " · ")
    }

    /// "≈ 2,5 km · toʻgʻri chiziq": the chip at the middle of the line.
    func routeChip(_ route: MosqueRoute) -> String {
        "≈ " + distance(route.meters) + " · " + content.t("mosques_straight_line", locale)
    }

    /// "taxminan 2,5 km, toʻgʻri chiziq": the same chip for VoiceOver.
    func spokenRouteChip(_ route: MosqueRoute) -> String {
        String(format: content.t("mosques_about_a11y", locale), distance(route.meters))
            + ", " + content.t("mosques_straight_line", locale)
    }

    /// The route for VoiceOver: the straight-line note, then "taxminan 2,5 km,
    /// taxminan 39 daqiqa piyoda".
    func spokenRoute(_ route: MosqueRoute) -> String {
        var parts: [String] = []
        if route.isStraightLine {
            parts.append(content.t("mosques_route_straight", locale))
        }
        parts.append(String(format: content.t("mosques_about_a11y", locale), distance(route.meters)))
        if let walk = spokenWalk(meters: route.meters) {
            parts.append(walk)
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Helpers

    /// Minutes under an hour, hours and minutes from an hour up; nil past
    /// `walkableMeters`.
    private func walkText(meters: Double, minutesKey: String, hoursKey: String) -> String? {
        guard meters.isFinite, meters >= 0, meters <= Self.walkableMeters else { return nil }
        let seconds = MosqueRoute.estimatedWalkSeconds(forMeters: meters)
        let clamped = seconds.isFinite ? min(max(seconds, 0), Self.longestDurationSeconds) : 0
        let minutes = max(Int((clamped / 60).rounded()), 1)
        guard minutes >= 60 else {
            return String(format: content.t(minutesKey, locale), "\(minutes)")
        }
        return String(format: content.t(hoursKey, locale), "\(minutes / 60)", "\(minutes % 60)")
    }

    private func number(_ value: Double, fractionDigits: Int) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(fractionDigits))
                .locale(Locale(identifier: locale.appleLanguageCode))
        )
    }

    /// Case- and accent-blind form, so "Juma" and "JUMA" count as one name.
    private static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
