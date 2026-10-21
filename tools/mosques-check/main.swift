import Foundation

// Standalone regression harness for the pure mosques layer
// (Mosques/MosqueModels.swift + MosqueCatalog.swift + MapHandoff.swift +
// MosqueClustering.swift). This file is NOT part of the app target. Run it
// from the repo root (argv[1] = repo root):
//   M=MuallimiSoniy/Mosques
//   xcrun swiftc -swift-version 5 -default-isolation MainActor \
//     MuallimiSoniy/Models/AppEnums.swift $M/MosqueModels.swift \
//     $M/MosqueCatalog.swift $M/MapHandoff.swift $M/MosqueClustering.swift \
//     tools/mosques-check/main.swift -o /tmp/mosques-check && /tmp/mosques-check "$PWD"

var passCount = 0
var failCount = 0

func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() {
        passCount += 1
        print("PASS  \(name)")
    } else {
        failCount += 1
        print("FAIL  \(name)")
    }
}

/// Like `check`, but prints both values when they differ.
func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ name: String) {
    check(actual == expected, name)
    if actual != expected {
        print("      expected: \(expected)")
        print("      actual:   \(actual)")
    }
}

func mosque(
    _ id: String, _ lat: Double, _ lon: Double, name: String? = nil, ru: String? = nil, uz: String? = nil
) -> Mosque {
    Mosque(id: id, lat: lat, lon: lon, name: name, nameRu: ru, nameUz: uz)
}

let tashkent = GeoPoint(latitude: 41.2995, longitude: 69.2401)
let samarkand = GeoPoint(latitude: 39.6542, longitude: 66.9597)

// MARK: - Section A: distance + nearest

func runDistanceTests() {
    let km = MosqueCatalog.meters(from: tashkent, to: samarkand) / 1000
    print("      Tashkent → Samarkand: \(String(format: "%.1f", km)) km")
    check(abs(km - 266) <= 2, "distance: Tashkent → Samarkand ≈ 266 km (±2)")
    check(MosqueCatalog.meters(from: tashkent, to: tashkent) == 0, "distance: a point to itself is 0 m")
    let there = MosqueCatalog.meters(from: tashkent, to: samarkand)
    let back = MosqueCatalog.meters(from: samarkand, to: tashkent)
    check(abs(there - back) < 0.001, "distance: symmetric")
    let northStep = GeoPoint(latitude: 41.001, longitude: 69.0)
    let step = MosqueCatalog.meters(from: GeoPoint(latitude: 41.0, longitude: 69.0), to: northStep)
    check(abs(step - 111.19) < 0.5, "distance: 0.001° of latitude ≈ 111 m")
}

func runNearestTests() {
    let origin = GeoPoint(latitude: 41.0, longitude: 69.0)
    let catalog = MosqueCatalog(mosques: [
        mosque("far", 41.010, 69.0),
        mosque("closest", 41.001, 69.0),
        mosque("middle", 41.005, 69.0),
        mosque("second", 40.998, 69.0)
    ])
    let three = catalog.nearest(to: origin, limit: 3)
    checkEqual(three.map(\.id), ["closest", "second", "middle"], "nearest: closest first, limited to 3")
    check(zip(three, three.dropFirst()).allSatisfy { $0.meters <= $1.meters }, "nearest: meters ascending")
    checkEqual(catalog.nearest(to: origin, limit: 10).count, 4, "nearest: limit above the count returns all")
    check(catalog.nearest(to: origin, limit: 0).isEmpty, "nearest: limit 0 returns nothing")
    let invalid = GeoPoint(latitude: .nan, longitude: 69)
    check(catalog.nearest(to: invalid, limit: 3).isEmpty, "nearest: an invalid origin returns nothing")
}

func runNearbyRadiusTests() {
    let origin = GeoPoint(latitude: 41.0, longitude: 69.0)
    let radius = MosqueCatalog.nearbyRadiusMeters
    checkEqual(radius, 50_000, "nearby: the list looks 50 km around")
    // 0.09° of latitude ≈ 10 km, 0.44° ≈ 49 km, 0.46° ≈ 51 km, 0.54° ≈ 60 km.
    let catalog = MosqueCatalog(mosques: [
        mosque("ten", 41.09, 69.0), mosque("inside", 41.44, 69.0),
        mosque("outside", 41.46, 69.0), mosque("sixty", 41.54, 69.0)
    ])
    let near = catalog.nearest(to: origin, limit: 5, within: radius)
    checkEqual(near.map(\.id), ["ten", "inside"], "nearby: 49 km is in, 51 km and 60 km are out")
    checkEqual(catalog.nearest(to: origin, limit: 5).count, 4, "nearby: without a radius nothing is dropped")
    let abroad = GeoPoint(latitude: 55.7558, longitude: 37.6173)
    check(catalog.nearest(to: abroad, limit: 5, within: radius).isEmpty, "nearby: abroad the list is empty")
}

// MARK: - Section B: visible region (bbox + cap)

func runBoxTests() {
    var grid: [Mosque] = []
    for row in -5...5 {
        for column in -5...5 {
            grid.append(mosque("g\(row)_\(column)", 41.0 + Double(row) * 0.01, 69.0 + Double(column) * 0.01))
        }
    }
    grid.append(mosque("outside", 41.2, 69.0))
    let catalog = MosqueCatalog(mosques: grid)
    let all = catalog.inBox(minLatitude: 40.9, maxLatitude: 41.1, minLongitude: 68.9, maxLongitude: 69.1, limit: 1000)
    checkEqual(all.count, 121, "bbox: every grid point inside, the outside one left out")
    let capped = catalog.inBox(minLatitude: 40.9, maxLatitude: 41.1, minLongitude: 68.9, maxLongitude: 69.1, limit: 5)
    checkEqual(
        Set(capped.map(\.id)), ["g0_0", "g0_-1", "g0_1", "g-1_0", "g1_0"],
        "bbox: over the cap keeps the 5 nearest the box centre"
    )
    check(
        catalog.inBox(minLatitude: 41.1, maxLatitude: 40.9, minLongitude: 68.9, maxLongitude: 69.1, limit: 5).isEmpty,
        "bbox: an upside-down latitude range returns nothing"
    )
    let dateLine = MosqueCatalog(mosques: [mosque("east", 0, 175), mosque("west", 0, -175), mosque("zero", 0, 0)])
    let wrapped = dateLine.inBox(minLatitude: -1, maxLatitude: 1, minLongitude: 170, maxLongitude: -170, limit: 10)
    checkEqual(Set(wrapped.map(\.id)), ["east", "west"], "bbox: a box across ±180° wraps")
}

// MARK: - Section C: transliteration + search keys

func runTransliterationTests() {
    let samples: [(String, String)] = [
        ("Қўштепа", "Qo\u{02BB}shtepa"),
        ("Ғишткўприк", "G\u{02BB}ishtko\u{02BB}prik"),
        ("Шаҳрисабз", "Shahrisabz"),
        ("Чорсу", "Chorsu"),
        ("Ёшлик", "Yoshlik"),
        ("Юнусобод", "Yunusobod"),
        ("Янгиобод", "Yangiobod"),
        ("Ер", "Yer"),
        ("поезд", "poyezd"),
        ("Шерали", "Sherali"),
        ("ШАЙХ ЗАЙНУДДИН", "SHAYX ZAYNUDDIN"),
        ("ТОШ", "TOSH"),
        ("Маъмур", "Ma\u{02BC}mur"),
        ("Жомеъ масжиди", "Jome\u{02BC} masjidi"),
        ("Ҳазрати Имом", "Hazrati Imom"),
        ("Олтин тепа Масжиди", "Oltin tepa Masjidi"),
        ("Ўзбекистон", "O\u{02BB}zbekiston"),
        ("Цирк", "Sirk"),
        ("милиция", "militsiya"),
        ("Соборная мечеть", "Sobornaya mechet"),
        ("Juma masjidi", "Juma masjidi")
    ]
    for (cyrillic, latin) in samples {
        checkEqual(MosqueText.latin(cyrillic), latin, "latin: \(cyrillic) → \(latin)")
    }
    checkEqual(MosqueText.searchKey("Жума масжиди"), "juma masjidi", "searchKey: Cyrillic folds to Latin")
    checkEqual(MosqueText.searchKey("Qoʻshtepa jome' masjidi"), "qoshtepa jome masjidi", "searchKey: apostrophes go")
    checkEqual(MosqueText.searchKey("Қўштепа"), MosqueText.searchKey("Qo‘shtepa"), "searchKey: Қўштепа = Qo‘shtepa")
    checkEqual(MosqueText.searchKey("Ходжа"), MosqueText.searchKey("Xo`ja"), "searchKey: Ходжа = Xo`ja (dj, x)")
    checkEqual(MosqueText.searchKey("  JÚMA--Bozor  "), "juma bozor", "searchKey: case, accents, punctuation")
    checkEqual(MosqueText.searchKey("jom´e"), "jome", "searchKey: an acute accent mark doesn't split a word")
}

func runSearchTests() {
    let catalog = MosqueCatalog(mosques: [
        mosque("cyr", 41.30, 69.24, name: "Жума масжиди"),
        mosque("lat", 41.31, 69.28, name: "Minor"),
        mosque("ru", 41.20, 69.20, name: "Juma masjid", ru: "Пятничная мечеть (Джума мечеть)"),
        mosque("xoja", 41.40, 69.30, name: "Xoʻja Ahror jome' masjidi"),
        mosque("unnamed", 41.0, 69.0)
    ])
    let ids = { (query: String) in catalog.search(query, near: nil, limit: 10).map(\.id) }
    check(ids("juma").contains("cyr"), "search: \"juma\" finds \"Жума\"")
    check(ids("минор").contains("lat"), "search: \"минор\" finds \"Minor\"")
    check(ids("JUMA").contains("cyr") && ids("júma").contains("ru"), "search: case and accent insensitive")
    check(ids("Хўжа").contains("xoja") && ids("xo'ja").contains("xoja"), "search: Хўжа / xo'ja find Xoʻja")
    checkEqual(ids("juma мечеть"), ["ru"], "search: every word must match")
    check(ids("").isEmpty && ids("  ").isEmpty && ids("''").isEmpty, "search: an empty query finds nothing")
    check(catalog.search("juma", near: nil, limit: 1).count == 1, "search: limit is honoured")
    checkEqual(ids("masjid"), ["ru", "cyr", "xoja"], "search: A→Z without a location (Cyrillic sorts as Latin)")
    let near = catalog.search("masjid", near: GeoPoint(latitude: 41.30, longitude: 69.24), limit: 10).map(\.id)
    checkEqual(near, ["cyr", "ru", "xoja"], "search: by distance with a location")
}

// MARK: - Section D: display names

func runDisplayNameTests() {
    let both = mosque("a", 41, 69, name: "Жума масжиди", ru: "Джума мечеть")
    checkEqual(MosqueCatalog.displayName(of: both, locale: .ru), "Джума мечеть", "name: ru prefers nameRu")
    checkEqual(MosqueCatalog.displayName(of: both, locale: .uzLatn), "Juma masjidi", "name: uz-latn writes Cyrillic in Latin")
    checkEqual(MosqueCatalog.displayName(of: both, locale: .uzCyrl), "Жума масжиди", "name: uz-cyrl keeps name")
    checkEqual(MosqueCatalog.displayName(of: both, locale: .en), "Жума масжиди", "name: en uses name first")

    let uzOnly = mosque("b", 41, 69, name: "Minor", uz: "Қўштепа")
    checkEqual(MosqueCatalog.displayName(of: uzOnly, locale: .uzLatn), "Qo\u{02BB}shtepa", "name: uz-latn prefers nameUz")
    checkEqual(MosqueCatalog.displayName(of: uzOnly, locale: .uzCyrl), "Minor", "name: uz-cyrl prefers name over nameUz")
    checkEqual(MosqueCatalog.displayName(of: uzOnly, locale: .ru), "Minor", "name: ru falls back to name")

    let ruOnly = mosque("c", 41, 69, ru: "Мечеть")
    checkEqual(MosqueCatalog.displayName(of: ruOnly, locale: .en), "Мечеть", "name: en falls back to nameRu")
    checkEqual(MosqueCatalog.displayName(of: ruOnly, locale: .uzLatn), nil, "name: uz-latn never uses nameRu")
    checkEqual(MosqueCatalog.displayName(of: ruOnly, locale: .uzCyrl), nil, "name: uz-cyrl never uses nameRu")

    let padded = mosque("d", 41, 69, name: "  Bobo ota\u{200B} ", ru: "   ")
    checkEqual(MosqueCatalog.displayName(of: padded, locale: .ru), "Bobo ota", "name: trimmed, blank nameRu skipped")
    let blank = mosque("e", 41, 69, name: " ", ru: "", uz: "\n")
    check(AppLocale.allCases.allSatisfy { MosqueCatalog.displayName(of: blank, locale: $0) == nil }, "name: blank → nil")
}

func runDisplayNameCleanupTests() {
    func uzLatn(_ name: String) -> String {
        MosqueCatalog.displayName(of: mosque("x", 41, 69, name: name), locale: .uzLatn) ?? "nil"
    }
    checkEqual(uzLatn("Xo'ja Ahror jom'e masjidi"), "Xo\u{02BB}ja Ahror jom\u{02BC}e masjidi", "name: uz-latn o' → oʻ, m' → mʼ")
    checkEqual(uzLatn("bog‘imozor jome’ masjidi"), "Bog\u{02BB}imozor jome\u{02BC} masjidi", "name: uz-latn ‘ ’ + capital")
    checkEqual(uzLatn("O`ZBEKISTON G'ISHT"), "O\u{02BB}ZBEKISTON G\u{02BB}ISHT", "name: uz-latn O` / G' → ʻ")
    checkEqual(uzLatn("O\u{02BC}rta jom\u{02BB}e"), "O\u{02BB}rta jom\u{02BC}e", "name: uz-latn wrong-way marks swapped")
    checkEqual(uzLatn("'nur' masjidi"), "'Nur\u{02BC} masjidi", "name: uz-latn opening quote stays")
    checkEqual(uzLatn("Ўрта жомеъ"), "O\u{02BB}rta jome\u{02BC}", "name: uz-latn Cyrillic keeps ʻ / ʼ")
    let english = mosque("y", 41, 69, name: "jom'e masjid")
    checkEqual(MosqueCatalog.displayName(of: english, locale: .en), "Jom'e masjid", "name: en capitalised, ' untouched")
    let russian = mosque("z", 41, 69, ru: "мечеть «нур»")
    checkEqual(MosqueCatalog.displayName(of: russian, locale: .ru), "Мечеть «нур»", "name: ru capitalises the first letter")
    let quoted = mosque("w", 41, 69, name: "«нур» масжиди")
    checkEqual(MosqueCatalog.displayName(of: quoted, locale: .uzCyrl), "«Нур» масжиди", "name: the first letter after a quote")
    checkEqual(MosqueText.capitalizingFirstLetter("1-boyovut"), "1-Boyovut", "name: digits before the first letter")
}

// MARK: - Section E: straight-line route

func runStraightLineTests() {
    let route = MosqueRoute.straightLine(from: tashkent, to: samarkand, mosqueID: "m1")
    let meters = MosqueCatalog.meters(from: tashkent, to: samarkand)
    check(route.isStraightLine && route.points == [tashkent, samarkand], "route: straight line has the two ends")
    check(abs(route.meters - meters) < 0.001, "route: straight line length is the haversine distance")
    check(abs(route.seconds - meters / 80 * 60 * 1.25) < 0.001, "route: seconds = meters / 80 × 60 × 1.25")
    checkEqual(MosqueRoute.estimatedWalkSeconds(forMeters: 800), 750, "route: 800 m ≈ 12.5 min on foot")
}

// MARK: - Section F: hand-off links

let mosqueAt = GeoPoint(latitude: 41.2995, longitude: 69.2401)
let user = GeoPoint(latitude: 41.3111, longitude: 69.2797)

/// Every Yandex Maps link (app + web) × mode × with / without a start.
func yandexMapsExpectations() -> [(URL?, String, String)] {
    [
        (MapHandoff.yandexMapsAppURL(to: mosqueAt, from: nil, mode: .walking),
         "yandexmaps://maps.yandex.ru/?rtext=~41.299500,69.240100&rtt=pd", "yandex app, walking, no start"),
        (MapHandoff.yandexMapsAppURL(to: mosqueAt, from: user, mode: .walking),
         "yandexmaps://maps.yandex.ru/?rtext=41.311100,69.279700~41.299500,69.240100&rtt=pd", "yandex app, walking, start"),
        (MapHandoff.yandexMapsAppURL(to: mosqueAt, from: nil, mode: .driving),
         "yandexmaps://maps.yandex.ru/?rtext=~41.299500,69.240100&rtt=auto", "yandex app, driving, no start"),
        (MapHandoff.yandexMapsAppURL(to: mosqueAt, from: user, mode: .driving),
         "yandexmaps://maps.yandex.ru/?rtext=41.311100,69.279700~41.299500,69.240100&rtt=auto", "yandex app, driving, start"),
        (MapHandoff.yandexMapsWebURL(to: mosqueAt, from: nil, mode: .walking),
         "https://yandex.uz/maps/?rtext=~41.299500,69.240100&rtt=pd", "yandex web, walking, no start"),
        (MapHandoff.yandexMapsWebURL(to: mosqueAt, from: user, mode: .walking),
         "https://yandex.uz/maps/?rtext=41.311100,69.279700~41.299500,69.240100&rtt=pd", "yandex web, walking, start"),
        (MapHandoff.yandexMapsWebURL(to: mosqueAt, from: nil, mode: .driving),
         "https://yandex.uz/maps/?rtext=~41.299500,69.240100&rtt=auto", "yandex web, driving, no start"),
        (MapHandoff.yandexMapsWebURL(to: mosqueAt, from: user, mode: .driving),
         "https://yandex.uz/maps/?rtext=41.311100,69.279700~41.299500,69.240100&rtt=auto", "yandex web, driving, start")
    ]
}

/// Every Google Maps link (mode × start) and both Yandex Go links.
func googleAndYandexGoExpectations() -> [(URL?, String, String)] {
    [
        (MapHandoff.googleMapsURL(to: mosqueAt, from: nil, mode: .walking),
         "https://www.google.com/maps/dir/?api=1&destination=41.299500%2C69.240100&travelmode=walking",
         "google, walking, no start"),
        (MapHandoff.googleMapsURL(to: mosqueAt, from: user, mode: .walking),
         "https://www.google.com/maps/dir/?api=1&destination=41.299500%2C69.240100&travelmode=walking"
            + "&origin=41.311100%2C69.279700", "google, walking, start"),
        (MapHandoff.googleMapsURL(to: mosqueAt, from: nil, mode: .driving),
         "https://www.google.com/maps/dir/?api=1&destination=41.299500%2C69.240100&travelmode=driving",
         "google, driving, no start"),
        (MapHandoff.googleMapsURL(to: mosqueAt, from: user, mode: .driving),
         "https://www.google.com/maps/dir/?api=1&destination=41.299500%2C69.240100&travelmode=driving"
            + "&origin=41.311100%2C69.279700", "google, driving, start"),
        (MapHandoff.yandexGoURL(to: mosqueAt, from: nil, language: "uz"),
         "https://3.redirect.appmetrica.yandex.com/route?end-lat=41.299500&end-lon=69.240100"
            + "&ref=muallimisoniy&appmetrica_tracking_id=1178268795219780156&lang=uz", "yandex go, no start"),
        (MapHandoff.yandexGoURL(to: mosqueAt, from: user, language: "ru"),
         "https://3.redirect.appmetrica.yandex.com/route?start-lat=41.311100&start-lon=69.279700"
            + "&end-lat=41.299500&end-lon=69.240100&ref=muallimisoniy"
            + "&appmetrica_tracking_id=1178268795219780156&lang=ru", "yandex go, start")
    ]
}

func runHandoffTests() {
    for (url, expected, name) in yandexMapsExpectations() + googleAndYandexGoExpectations() {
        checkEqual(url?.absoluteString ?? "nil", expected, "url: \(name)")
    }
    let languages = AppLocale.allCases.map { MapHandoff.yandexGoLanguage(for: $0) }
    checkEqual(languages, ["uz", "uz", "ru", "en"], "url: yandex go lang for uz-latn / uz-cyrl / ru / en")
    checkEqual(MapHandoff.coordinate(69.24012345), "69.240123", "url: 6 decimals, '.' separator")
    checkEqual(MapHandoff.coordinate(-0.5), "-0.500000", "url: negative coordinate")
    let broken = GeoPoint(latitude: .nan, longitude: 69)
    check(MapHandoff.googleMapsURL(to: broken, from: nil, mode: .walking) == nil, "url: no link to an invalid point")
    let noStart = MapHandoff.yandexMapsAppURL(to: mosqueAt, from: broken, mode: .walking)?.absoluteString
    checkEqual(noStart ?? "nil", "yandexmaps://maps.yandex.ru/?rtext=~41.299500,69.240100&rtt=pd", "url: invalid start dropped")
    checkEqual(MapApp.allCases, [.yandexMaps, .googleMaps, .yandexGo, .appleMaps], "url: hand-off order")
}

/// The app opens every link without a start (`from: nil`, see MapHandoffOpener):
/// only the mosque's position may appear in them, nothing about the user.
func runNoStartTests() {
    let links = [
        MapHandoff.yandexMapsAppURL(to: mosqueAt, from: nil, mode: .walking),
        MapHandoff.yandexMapsWebURL(to: mosqueAt, from: nil, mode: .driving),
        MapHandoff.googleMapsURL(to: mosqueAt, from: nil, mode: .walking),
        MapHandoff.yandexGoURL(to: mosqueAt, from: nil, language: "uz")
    ].map { $0?.absoluteString ?? "nil" }
    check(links.allSatisfy { $0.contains("41.299500") && $0.contains("69.240100") }, "no start: each link has the mosque")
    let startKeys = ["origin=", "start-lat", "start-lon"]
    check(links.allSatisfy { link in startKeys.allSatisfy { !link.contains($0) } }, "no start: no origin / start keys")
    check(links.allSatisfy { !$0.contains("41.311100") && !$0.contains("69.279700") }, "no start: no user coordinates")
    check(links.filter { $0.contains("rtext=") }.allSatisfy { $0.contains("rtext=~") }, "no start: Yandex rtext starts empty")
}

// MARK: - Section H: map clustering

/// iPhone 17 Pro portrait map (402 × 874 pt) and iPad Pro 13" landscape.
let phoneGrid = MosqueClustering.Grid(mapWidth: 402, mapHeight: 874)
let padGrid = MosqueClustering.Grid(mapWidth: 1376, mapHeight: 1032)

/// How many clusters and singles, and how many mosques they stand for.
func tally(_ items: [MosqueMapItem]) -> (clusters: Int, singles: Int, mosques: Int) {
    var result = (clusters: 0, singles: 0, mosques: 0)
    for item in items {
        switch item {
        case .single:
            result.singles += 1
            result.mosques += 1
        case .cluster(let cluster):
            result.clusters += 1
            result.mosques += cluster.count
        }
    }
    return result
}

func clusters(_ items: [MosqueMapItem]) -> [MosqueCluster] {
    items.compactMap { item in
        if case .cluster(let cluster) = item { return cluster }
        return nil
    }
}

/// 21 × 21 mosques 0.005° apart around (41.3, 69.25): a dense city block.
func denseBlock() -> [Mosque] {
    var block: [Mosque] = []
    for row in -10...10 {
        for column in -10...10 {
            block.append(mosque("d\(row)_\(column)", 41.3 + Double(row) * 0.005, 69.25 + Double(column) * 0.005))
        }
    }
    return block
}

let cityView = GeoBounds(minLatitude: 41.18, maxLatitude: 41.42, minLongitude: 69.13, maxLongitude: 69.37)

func runClusteringBasicsTests() {
    let block = denseBlock()
    check(MosqueClustering.items(for: [], in: cityView, grid: phoneGrid).isEmpty, "cluster: no mosques → nothing")
    let upsideDown = GeoBounds(minLatitude: 41.42, maxLatitude: 41.18, minLongitude: 69.13, maxLongitude: 69.37)
    check(MosqueClustering.items(for: block, in: upsideDown, grid: phoneGrid).isEmpty, "cluster: upside-down viewport → nothing")
    let dateLine = GeoBounds(minLatitude: -1, maxLatitude: 1, minLongitude: 170, maxLongitude: -170)
    check(MosqueClustering.items(for: block, in: dateLine, grid: phoneGrid).isEmpty, "cluster: a box across ±180° → nothing")
    let broken = GeoBounds(minLatitude: .nan, maxLatitude: 41.4, minLongitude: 69.1, maxLongitude: .infinity)
    check(MosqueClustering.items(for: block, in: broken, grid: phoneGrid).isEmpty, "cluster: NaN / infinite viewport → nothing")
    let noGrid = MosqueClustering.Grid(columns: 0, rows: 10)
    check(MosqueClustering.items(for: block, in: cityView, grid: noGrid).isEmpty, "cluster: an empty grid → nothing")
    let kept = MosqueClustering.items(for: block, in: upsideDown, grid: phoneGrid, selectedID: "d0_0").map(\.id)
    checkEqual(kept, ["d0_0"], "cluster: the selected mosque survives a bad viewport")
    let unknown = MosqueClustering.items(for: block, in: cityView, grid: phoneGrid, selectedID: "nope")
    checkEqual(tally(unknown).mosques, block.count, "cluster: an unknown selected id changes nothing")
}

func runClusteringZoomTests() {
    let block = denseBlock()
    let city = MosqueClustering.items(for: block, in: cityView, grid: phoneGrid)
    let cityTally = tally(city)
    print("      dense block at city zoom: \(cityTally.clusters) clusters, \(cityTally.singles) singles")
    check(cityTally.clusters >= 3, "cluster: a dense block at city zoom becomes clusters")
    checkEqual(cityTally.mosques, block.count, "cluster: counts add up to every mosque in view")
    check(clusters(city).allSatisfy { $0.count >= 2 && $0.bounds.contains($0.center) }, "cluster: ≥ 2 each, centre inside its box")
    checkEqual(Set(city.map(\.id)).count, city.count, "cluster: ids are unique")
    checkEqual(MosqueClustering.items(for: block, in: cityView, grid: phoneGrid), city, "cluster: same input → same output")

    let street = GeoBounds(minLatitude: 41.293, maxLatitude: 41.307, minLongitude: 69.2425, maxLongitude: 69.2575)
    let streetItems = MosqueClustering.items(for: block, in: street, grid: phoneGrid)
    check(tally(streetItems).clusters == 0 && !streetItems.isEmpty, "cluster: street zoom (< 0.02° across) → singles only")
    let inView = block.filter { street.contains($0.point) }.map(\.id)
    check(Set(inView).isSubset(of: Set(streetItems.map(\.id))), "cluster: street zoom keeps every mosque in view")
}

func runClusteringSelectionTests() {
    let block = denseBlock()
    let plain = MosqueClustering.items(for: block, in: cityView, grid: phoneGrid)
    let chosen = MosqueClustering.items(for: block, in: cityView, grid: phoneGrid, selectedID: "d0_0")
    let singles = chosen.filter { $0.id == "d0_0" }
    check(singles.count == 1 && singles.first.map { if case .single = $0 { return true } else { return false } } == true,
          "cluster: the selected mosque is drawn once, on its own")
    checkEqual(tally(chosen).mosques, block.count, "cluster: nothing lost or counted twice with a selection")
    let shrunk = clusters(plain).contains { before in
        clusters(chosen).contains { $0.id == before.id && $0.count == before.count - 1 }
    }
    check(shrunk, "cluster: its cell's badge counts one less")
    let outside = GeoBounds(minLatitude: 40.0, maxLatitude: 40.2, minLongitude: 68.0, maxLongitude: 68.2)
    let far = MosqueClustering.items(for: block, in: outside, grid: phoneGrid, selectedID: "d0_0").map(\.id)
    checkEqual(far, ["d0_0"], "cluster: the selected mosque stays even out of view")
}

/// Panning by a fraction of a cell must not move any cell edge: every
/// cluster well inside both views keeps its id, count, centre and box.
func runClusteringStabilityTests() {
    let block = denseBlock()
    let before = clusters(MosqueClustering.items(for: block, in: cityView, grid: phoneGrid))
    let shifted = GeoBounds(
        minLatitude: cityView.minLatitude + 0.004, maxLatitude: cityView.maxLatitude + 0.004,
        minLongitude: cityView.minLongitude - 0.019, maxLongitude: cityView.maxLongitude - 0.019
    )
    let after = clusters(MosqueClustering.items(for: block, in: shifted, grid: phoneGrid))
    let afterByID = Dictionary(uniqueKeysWithValues: after.map { ($0.id, $0) })
    let inner = GeoBounds(minLatitude: 41.24, maxLatitude: 41.36, minLongitude: 69.17, maxLongitude: 69.33)
    let inside = before.filter { inner.contains($0.center) }
    let kept = inside.filter { afterByID[$0.id] == $0 }
    print("      pan by ~0.3 cell: \(kept.count) of \(inside.count) inner clusters identical")
    check(!inside.isEmpty && kept.count == inside.count, "cluster: panning keeps every inner cluster identical")
    check(Set(before.map(\.id)).intersection(afterByID.keys).count * 10 >= before.count * 8,
          "cluster: panning keeps (nearly) every cluster id")
}

/// No two drawn items may overlap on screen (except at street zoom, where
/// pins stand alone by design).
func overlapping(_ items: [MosqueMapItem], in viewport: GeoBounds, grid: MosqueClustering.Grid) -> Int {
    let perLatitude = grid.rows * MosqueClustering.cellPoints / viewport.latitudeSpan
    let perLongitude = grid.columns * MosqueClustering.cellPoints / viewport.longitudeSpan
    func reach(_ item: MosqueMapItem) -> Double {
        if case .cluster(let cluster) = item { return MosqueClustering.badgeDiameter(for: cluster.count) / 2 }
        return MosqueClustering.pinReach
    }
    var count = 0
    for (index, first) in items.enumerated() {
        for second in items[(index + 1)...] {
            let north = (first.point.latitude - second.point.latitude) * perLatitude
            let east = (first.point.longitude - second.point.longitude) * perLongitude
            if (north * north + east * east).squareRoot() < reach(first) + reach(second) { count += 1 }
        }
    }
    return count
}

/// More items than the cap → the nearest ones to the centre, selection kept.
func runClusteringCapTests() {
    var crowd: [Mosque] = []
    for index in 0..<2_000 {
        let row = Double(index / 50)
        let column = Double(index % 50)
        crowd.append(mosque("c\(index)", 41.0 + row * 0.002, 69.0 + column * 0.002))
    }
    let box = GeoBounds(minLatitude: 40.99, maxLatitude: 41.09, minLongitude: 68.99, maxLongitude: 69.11)
    let tiny = MosqueClustering.Grid(columns: 400, rows: 400)
    let items = MosqueClustering.items(for: crowd, in: box, grid: tiny, selectedID: "c1999")
    print("      2,000 mosques on a 400 × 400 grid: \(items.count) items")
    check(items.count <= MosqueClustering.maxItems, "cluster: never more than \(MosqueClustering.maxItems) items")
    check(items.contains { $0.id == "c1999" }, "cluster: the cap keeps the selected mosque")
}

func runClusteringDatasetTests(_ mosques: [Mosque]) {
    guard let country = GeoBounds(around: mosques.map(\.point)) else {
        check(false, "dataset clusters: no bounds")
        return
    }
    let phone = MosqueClustering.items(for: mosques, in: country, grid: phoneGrid)
    let phoneTally = tally(phone)
    let pad = tally(MosqueClustering.items(for: mosques, in: country, grid: padGrid))
    print("      country zoom: phone \(phoneTally.clusters) clusters + \(phoneTally.singles) singles, "
          + "iPad \(pad.clusters) clusters + \(pad.singles) singles")
    check((5...60).contains(phoneTally.clusters), "dataset clusters: country zoom → a handful to a few dozen badges")
    checkEqual(overlapping(phone, in: country, grid: phoneGrid), 0, "dataset clusters: no two badges overlap (phone)")
    let padItems = MosqueClustering.items(for: mosques, in: country, grid: padGrid)
    checkEqual(overlapping(padItems, in: country, grid: padGrid), 0, "dataset clusters: no two badges overlap (iPad)")
    let tashkent = GeoBounds(minLatitude: 41.18, maxLatitude: 41.44, minLongitude: 69.13, maxLongitude: 69.43)
    let cityItems = MosqueClustering.items(for: mosques, in: tashkent, grid: phoneGrid)
    print("      Tashkent at city zoom: \(tally(cityItems).clusters) clusters + \(tally(cityItems).singles) singles")
    checkEqual(overlapping(cityItems, in: tashkent, grid: phoneGrid), 0, "dataset clusters: no overlaps at city zoom")
    checkEqual(phoneTally.mosques, mosques.count, "dataset clusters: country counts add up to all \(mosques.count)")
    checkEqual(pad.mosques, mosques.count, "dataset clusters: iPad counts add up too")
    check(pad.clusters > phoneTally.clusters, "dataset clusters: a bigger map splits into more badges")

    let centre = GeoPoint(latitude: 41.3111, longitude: 69.2797)
    let street = GeoBounds(minLatitude: centre.latitude - 0.008, maxLatitude: centre.latitude + 0.008,
                           minLongitude: centre.longitude - 0.009, maxLongitude: centre.longitude + 0.009)
    let streetTally = tally(MosqueClustering.items(for: mosques, in: street, grid: phoneGrid))
    check(streetTally.clusters == 0, "dataset clusters: street zoom in Tashkent → singles only")

    let city = GeoBounds(minLatitude: 41.25, maxLatitude: 41.37, minLongitude: 69.22, maxLongitude: 69.34)
    let nearest = MosqueCatalog(mosques: mosques).nearest(to: centre, limit: 1).first?.mosque.id ?? "missing"
    let chosen = MosqueClustering.items(for: mosques, in: city, grid: phoneGrid, selectedID: nearest)
    check(chosen.contains { item in
        if case .single(let single) = item { return single.id == nearest }
        return false
    }, "dataset clusters: the selected mosque in central Tashkent stays a pin")
    measureClustering(mosques, in: country)
}

/// The cost of one camera stop: clustering every mosque for a full iPad map.
func measureClustering(_ mosques: [Mosque], in viewport: GeoBounds) {
    let rounds = 200
    let elapsed = ContinuousClock().measure {
        for _ in 0..<rounds {
            _ = MosqueClustering.items(for: mosques, in: viewport, grid: padGrid)
        }
    }
    let total = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
    let perStop = total / Double(rounds)
    print("      clustering \(mosques.count) mosques: \(String(format: "%.2f", perStop)) ms per camera stop (unoptimised build)")
    check(perStop < 20, "dataset clusters: one camera stop costs well under 20 ms")
}

// MARK: - Section G: bundled dataset

func runDatasetSection(repoRoot: String) {
    let url = URL(fileURLWithPath: repoRoot).appendingPathComponent("MuallimiSoniy/Resources/mosques-uz.json")
    guard let data = try? Data(contentsOf: url),
          let dataset = try? JSONDecoder().decode(MosqueDataset.self, from: data) else {
        check(false, "dataset: failed to load/decode \(url.path)")
        return
    }
    let mosques = dataset.mosques
    print("      dataset: \(mosques.count) mosques, generated \(dataset.generatedAt ?? "?")")
    check(mosques.count >= 2000, "dataset: decodes with at least 2000 mosques")
    checkEqual(dataset.count ?? -1, mosques.count, "dataset: count field matches the list")
    check(Set(mosques.map(\.id)).count == mosques.count, "dataset: ids are unique")
    let outside = mosques.filter { !(37...46).contains($0.lat) || !(55...74).contains($0.lon) }
    check(outside.isEmpty, "dataset: every point inside lat 37–46 / lon 55–74")
    check(dataset.attribution?.contains("OpenStreetMap") == true, "dataset: carries the OSM attribution")

    let catalog = MosqueCatalog(mosques: mosques)
    let juma = catalog.search("juma", near: nil, limit: 500).map(\.id)
    print("      real search \"juma\": \(juma.count) hits")
    check(juma.count >= 3, "dataset: \"juma\" finds at least 3 mosques")
    checkEqual(catalog.search("жума", near: nil, limit: 500).map(\.id), juma, "dataset: \"жума\" finds the same set")
    let minor = mosques.first { $0.name == "Минор" }?.id ?? "missing"
    check(catalog.search("minor", near: nil, limit: 50).map(\.id).contains(minor), "dataset: \"minor\" finds \"Минор\"")
    let nearest = catalog.nearest(to: GeoPoint(latitude: 41.3111, longitude: 69.2797), limit: 5)
    print("      nearest to Tashkent centre: " + nearest.map { "\($0.id) \(Int($0.meters)) m" }.joined(separator: ", "))
    check(nearest.count == 5 && (nearest.last?.meters ?? .infinity) < 5000, "dataset: 5 mosques within 5 km of Tashkent centre")
    runDatasetRadiusAndNameTests(catalog)
    runClusteringDatasetTests(mosques)
}

/// The 50 km list from inside and outside Uzbekistan, and every uz-latn name
/// the app would show: capitalised, no typed apostrophe left after a letter.
func runDatasetRadiusAndNameTests(_ catalog: MosqueCatalog) {
    let radius = MosqueCatalog.nearbyRadiusMeters
    let tashkentCentre = GeoPoint(latitude: 41.3111, longitude: 69.2797)
    checkEqual(catalog.nearest(to: tashkentCentre, limit: 5, within: radius).count, 5, "dataset: Tashkent has 5 within 50 km")
    let moscow = GeoPoint(latitude: 55.7558, longitude: 37.6173)
    check(catalog.nearest(to: moscow, limit: 5, within: radius).isEmpty, "dataset: from Moscow the 50 km list is empty")

    let typed: Set<Character> = ["'", "`", "‘", "’", "´"]
    var leftovers: [String] = []
    var lowercaseStarts: [String] = []
    for mosque in catalog.mosques {
        guard let name = MosqueCatalog.displayName(of: mosque, locale: .uzLatn) else { continue }
        let characters = Array(name)
        let hasLeftover = characters.indices.dropFirst().contains { typed.contains(characters[$0]) && characters[$0 - 1].isLetter }
        if hasLeftover { leftovers.append(name) }
        if let first = characters.first(where: \.isLetter), first.isLowercase { lowercaseStarts.append(name) }
    }
    print("      uz-latn names: \(leftovers.count) with a typed apostrophe, \(lowercaseStarts.count) lowercase starts")
    check(leftovers.isEmpty, "dataset: uz-latn names use ʻ / ʼ only (e.g. \(leftovers.prefix(2)))")
    check(lowercaseStarts.isEmpty, "dataset: uz-latn names start with a capital (e.g. \(lowercaseStarts.prefix(2)))")
}

// MARK: - Entry point

runDistanceTests()
runNearestTests()
runNearbyRadiusTests()
runBoxTests()
runTransliterationTests()
runSearchTests()
runDisplayNameTests()
runDisplayNameCleanupTests()
runStraightLineTests()
runHandoffTests()
runNoStartTests()
runClusteringBasicsTests()
runClusteringZoomTests()
runClusteringSelectionTests()
runClusteringStabilityTests()
runClusteringCapTests()

let repoRoot = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath
runDatasetSection(repoRoot: repoRoot)

print("")
print("Summary: \(passCount) passed, \(failCount) failed")
exit(failCount == 0 ? 0 : 1)
