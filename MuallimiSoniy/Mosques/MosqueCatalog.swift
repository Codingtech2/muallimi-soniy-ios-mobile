import Foundation

// Pure mosque logic: distances, the nearest list, the map's visible subset,
// search and the name to show. Foundation only on purpose — it also compiles
// on its own in tools/mosques-check. iOS-only feature, no web counterpart yet.

/// The bundled mosques plus a folded search key for each one. Built once, off
/// the main actor, when the dataset loads.
nonisolated struct MosqueCatalog: Sendable {
    /// Mean Earth radius used by the haversine formula.
    static let earthRadiusMeters = 6_371_000.0
    /// How far the "nearest mosques" list looks. Someone abroad gets an
    /// empty list instead of mosques thousands of kilometres away.
    static let nearbyRadiusMeters = 50_000.0

    let mosques: [Mosque]
    /// `searchKeys[i]`: every name of `mosques[i]`, folded by `MosqueText.searchKey`.
    private let searchKeys: [String]
    /// `sortKeys[i]`: the first name of `mosques[i]`, folded — the A→Z search order.
    private let sortKeys: [String]

    init(mosques: [Mosque]) {
        self.mosques = mosques
        searchKeys = mosques.map { mosque in
            [mosque.name, mosque.nameRu, mosque.nameUz]
                .compactMap { $0 }
                .map(MosqueText.searchKey)
                .joined(separator: " ")
        }
        sortKeys = mosques.map { MosqueText.sortKey($0.name ?? $0.nameUz ?? $0.nameRu ?? "") }
    }

    // MARK: - Distance

    /// Great-circle (haversine) distance in meters.
    static func meters(from start: GeoPoint, to end: GeoPoint) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let deltaLat = lat2 - lat1
        let deltaLon = (end.longitude - start.longitude) * .pi / 180
        let halfChord = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        return 2 * earthRadiusMeters * asin(min(1, sqrt(halfChord)))
    }

    /// Closest first, at most `limit`, none further than `maxMeters`; ties
    /// keep a stable order by id.
    func nearest(to origin: GeoPoint, limit: Int, within maxMeters: Double = .infinity) -> [NearbyMosque] {
        guard limit > 0, origin.isValid else { return [] }
        return Self.closest(mosques, to: origin, limit: limit).filter { $0.meters <= maxMeters }
    }

    // MARK: - Visible region

    /// The mosques inside the box. When there are more than `limit`, keeps
    /// the ones nearest the box centre (the map draws a capped number of
    /// markers). A box whose min longitude is above its max crosses ±180°.
    func inBox(
        minLatitude: Double, maxLatitude: Double, minLongitude: Double, maxLongitude: Double, limit: Int
    ) -> [Mosque] {
        let edges = [minLatitude, maxLatitude, minLongitude, maxLongitude]
        guard limit > 0, edges.allSatisfy(\.isFinite), minLatitude <= maxLatitude else { return [] }
        let crossesDateLine = minLongitude > maxLongitude
        let inside = mosques.filter { mosque in
            guard (minLatitude...maxLatitude).contains(mosque.lat) else { return false }
            if crossesDateLine {
                return mosque.lon >= minLongitude || mosque.lon <= maxLongitude
            }
            return (minLongitude...maxLongitude).contains(mosque.lon)
        }
        guard inside.count > limit else { return inside }
        var centreLongitude = (minLongitude + maxLongitude) / 2
        if crossesDateLine {
            centreLongitude = centreLongitude > 0 ? centreLongitude - 180 : centreLongitude + 180
        }
        let centre = GeoPoint(latitude: (minLatitude + maxLatitude) / 2, longitude: centreLongitude)
        return Self.closest(inside, to: centre, limit: limit).map(\.mosque)
    }

    // MARK: - Search

    /// Case-, diacritic- and script-insensitive: every word of the query must
    /// appear in one of the names, and a Latin query finds Cyrillic names (and
    /// the other way round) because both sides are folded to Latin. Sorted by
    /// distance when `origin` is known, otherwise alphabetically.
    func search(_ query: String, near origin: GeoPoint?, limit: Int) -> [Mosque] {
        let words = MosqueText.searchKey(query).split(separator: " ")
        guard limit > 0, !words.isEmpty else { return [] }
        let hits = mosques.indices.filter { index in
            words.allSatisfy { searchKeys[index].contains($0) }
        }
        if let origin, origin.isValid {
            return Self.closest(hits.map { mosques[$0] }, to: origin, limit: limit).map(\.mosque)
        }
        let ordered = hits.sorted { left, right in
            if sortKeys[left] != sortKeys[right] { return sortKeys[left] < sortKeys[right] }
            return mosques[left].id < mosques[right].id
        }
        return ordered.prefix(limit).map { mosques[$0] }
    }

    // MARK: - Names

    /// The name to show in the app's language, or nil for an unnamed mosque:
    /// ru → nameRu, then name; uz-latn → nameUz, then name, written in Latin
    /// with Uzbek apostrophes (oʻ, gʻ, ʼ); uz-cyrl → name, then nameUz; en →
    /// name, nameUz, then nameRu. Always starts with a capital letter.
    static func displayName(of mosque: Mosque, locale: AppLocale) -> String? {
        let name: String?
        switch locale {
        case .ru: name = firstNonEmpty(mosque.nameRu, mosque.name)
        case .uzLatn:
            name = firstNonEmpty(mosque.nameUz, mosque.name).map { MosqueText.uzbekApostrophes(MosqueText.latin($0)) }
        case .uzCyrl: name = firstNonEmpty(mosque.name, mosque.nameUz)
        case .en: name = firstNonEmpty(mosque.name, mosque.nameUz, mosque.nameRu)
        }
        return name.map(MosqueText.capitalizingFirstLetter)
    }

    // MARK: - Helpers

    /// Edges OpenStreetMap names sometimes carry: spaces plus zero-width marks.
    private static let trimmedCharacters = CharacterSet.whitespacesAndNewlines
        .union(CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}"))

    private static func firstNonEmpty(_ candidates: String?...) -> String? {
        for candidate in candidates {
            let trimmed = candidate?.trimmingCharacters(in: trimmedCharacters) ?? ""
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    private static func closest(_ items: [Mosque], to origin: GeoPoint, limit: Int) -> [NearbyMosque] {
        let measured = items.map { NearbyMosque(mosque: $0, meters: meters(from: origin, to: $0.point)) }
        let sorted = measured.sorted { left, right in
            if left.meters != right.meters { return left.meters < right.meters }
            return left.mosque.id < right.mosque.id
        }
        return Array(sorted.prefix(limit))
    }
}

// MARK: - Straight-line route

nonisolated extension MosqueRoute {
    /// Walking pace for the estimate, in meters per minute.
    static let walkingMetersPerMinute = 80.0
    /// Streets are never straight: the estimate walks a quarter further than the line.
    static let detourFactor = 1.25

    /// The fallback when Apple Maps has no walking route: a two-point line, its
    /// haversine length and an estimated walk.
    static func straightLine(from start: GeoPoint, to end: GeoPoint, mosqueID: String) -> MosqueRoute {
        let meters = MosqueCatalog.meters(from: start, to: end)
        return MosqueRoute(
            mosqueID: mosqueID,
            points: [start, end],
            meters: meters,
            seconds: estimatedWalkSeconds(forMeters: meters),
            isStraightLine: true
        )
    }

    /// meters / 80 m per minute × 60 × 1.25 detour.
    static func estimatedWalkSeconds(forMeters meters: Double) -> Double {
        meters / walkingMetersPerMinute * 60 * detourFactor
    }
}

// MARK: - Script folding

/// Uzbek Cyrillic → Latin, and the folded keys search compares.
nonisolated enum MosqueText {
    /// One Latin spelling per lowercase Cyrillic letter (Uzbek alphabet plus
    /// the Russian-only letters). "е" and "ц" are missing on purpose: their
    /// spelling depends on the letter before them.
    private static let latinLetters: [String: String] = [
        "а": "a", "б": "b", "в": "v", "г": "g", "д": "d", "ё": "yo", "ж": "j", "з": "z",
        "и": "i", "й": "y", "к": "k", "л": "l", "м": "m", "н": "n", "о": "o", "п": "p",
        "р": "r", "с": "s", "т": "t", "у": "u", "ф": "f", "х": "x", "ч": "ch", "ш": "sh",
        "щ": "sh", "ъ": "\u{02BC}", "ы": "i", "ь": "", "э": "e", "ю": "yu", "я": "ya",
        "ў": "o\u{02BB}", "қ": "q", "ғ": "g\u{02BB}", "ҳ": "h"
    ]
    private static let cyrillicVowels: Set<String> = ["а", "е", "ё", "и", "о", "у", "ў", "э", "ю", "я", "ы"]
    private static let cyrillicSigns: Set<String> = ["ъ", "ь"]
    /// Every apostrophe-like mark OSM names use for oʻ / gʻ / the hard sign.
    private static let apostrophes = Set("'`´ʹʻʼʽʾʿ‘’‛′".unicodeScalars)
    /// The marks `uzbekApostrophes` rewrites (the two right ones included,
    /// so a ʼ typed after o becomes ʻ).
    private static let typedApostrophes: Set<Character> = ["'", "`", "´", "ʹ", "ʻ", "ʼ", "‘", "’", "‛"]

    /// Writes Uzbek (and Russian) Cyrillic in the Uzbek Latin alphabet: ʻ
    /// (U+02BB) in oʻ / gʻ, ʼ (U+02BC) for the hard sign, sh / ch / yo / yu /
    /// ya, "ye" for е at a word start or after a vowel, "ts" for ц after a
    /// vowel ("s" elsewhere). Anything that isn't Cyrillic passes through.
    static func latin(_ text: String) -> String {
        let letters = Array(text)
        var result = ""
        result.reserveCapacity(text.utf8.count)
        for index in letters.indices {
            result += latinSpelling(at: index, in: letters)
        }
        return result
    }

    /// Lowercase Latin letters and digits separated by single spaces, with
    /// Cyrillic written in Latin, accents and apostrophes gone, and the
    /// spellings Russian and Uzbek disagree on merged (dj → j, kh / x → h).
    /// Both the names and the query go through it, so they compare equal.
    static func searchKey(_ text: String) -> String {
        sortKey(text)
            .replacingOccurrences(of: "dj", with: "j")
            .replacingOccurrences(of: "kh", with: "h")
            .replacingOccurrences(of: "x", with: "h")
    }

    /// Uzbek Latin apostrophes, whatever mark the name was typed with (' ` ‘
    /// ’ ´ …): ʻ (U+02BB) after o / g — oʻ, gʻ — and the tutuq belgisi ʼ
    /// (U+02BC) after any other letter. A mark that doesn't follow a letter
    /// (an opening quote) stays as it is.
    static func uzbekApostrophes(_ text: String) -> String {
        var result = ""
        var previous: Character?
        for character in text {
            if typedApostrophes.contains(character), let letter = previous, letter.isLetter {
                let afterOOrG = letter == "o" || letter == "O" || letter == "g" || letter == "G"
                result.append(afterOOrG ? "\u{02BB}" : "\u{02BC}")
            } else {
                result.append(character)
            }
            previous = character
        }
        return result
    }

    /// The text with its first letter in capitals: "jomʼe masjid" → "Jomʼe
    /// masjid", "«нур» масжиди" → "«Нур» масжиди".
    static func capitalizingFirstLetter(_ text: String) -> String {
        guard let index = text.firstIndex(where: \.isLetter) else { return text }
        var result = text
        result.replaceSubrange(index...index, with: text[index].uppercased())
        return result
    }

    /// The A→Z key: like `searchKey` but keeps every letter as written, so
    /// "Xoʻja" still sorts under X.
    static func sortKey(_ text: String) -> String {
        // Apostrophes go first: folding would turn "´" into a space and split the word.
        var withoutApostrophes = String.UnicodeScalarView()
        for scalar in latin(text).unicodeScalars where !apostrophes.contains(scalar) {
            withoutApostrophes.append(scalar)
        }
        let folded = String(withoutApostrophes).folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil
        )
        var key = ""
        var wantsSpace = false
        for scalar in folded.unicodeScalars {
            guard CharacterSet.alphanumerics.contains(scalar) else {
                wantsSpace = true
                continue
            }
            if wantsSpace, !key.isEmpty { key += " " }
            wantsSpace = false
            key.unicodeScalars.append(scalar)
        }
        return key
    }

    private static func latinSpelling(at index: Int, in letters: [Character]) -> String {
        let letter = letters[index]
        let lower = letter.lowercased()
        let spelling: String
        switch lower {
        case "е": spelling = startsSyllable(at: index, in: letters) ? "ye" : "e"
        case "ц": spelling = followsVowel(at: index, in: letters) ? "ts" : "s"
        default:
            guard let mapped = latinLetters[lower] else { return String(letter) }
            spelling = mapped
        }
        guard letter.isUppercase, let first = spelling.first else { return spelling }
        // "Ш" → "Sh" in "Шаҳар", but "SH" inside an all-caps word ("ШАҲАР").
        if spelling.count > 1, isInsideCapitals(index, letters) {
            return spelling.uppercased()
        }
        return first.uppercased() + spelling.dropFirst()
    }

    /// е is "ye" at a word start and after a vowel or a hard / soft sign.
    private static func startsSyllable(at index: Int, in letters: [Character]) -> Bool {
        guard index > 0, letters[index - 1].isLetter else { return true }
        let previous = letters[index - 1].lowercased()
        return cyrillicVowels.contains(previous) || cyrillicSigns.contains(previous)
    }

    private static func followsVowel(at index: Int, in letters: [Character]) -> Bool {
        index > 0 && cyrillicVowels.contains(letters[index - 1].lowercased())
    }

    private static func isInsideCapitals(_ index: Int, _ letters: [Character]) -> Bool {
        let next = index + 1
        if next < letters.count, letters[next].isLetter {
            return letters[next].isUppercase
        }
        return index > 0 && letters[index - 1].isUppercase
    }
}
