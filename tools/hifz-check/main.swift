import Foundation

// Standalone regression harness for the pure hifz layer (Models/HifzModels.swift
// + Models/HifzCatalog.swift). This file is NOT part of the app target. Run it
// from the repo root (argv[1] = repo root):
//   M=MuallimiSoniy/Models
//   xcrun swiftc -swift-version 5 -default-isolation MainActor \
//     $M/LocalizedString.swift $M/AppEnums.swift $M/BookModels.swift \
//     $M/ContentModels.swift $M/HifzModels.swift $M/HifzCatalog.swift \
//     tools/hifz-check/main.swift -o /tmp/hifz-check && /tmp/hifz-check "$PWD"

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

/// Runs a sequence from `first()` to completion (or `maxSteps`, for `.forever`
/// cases that never stop on their own), returning every cursor played.
func playAll(_ sequence: HifzSequence, maxSteps: Int = 10_000) -> [HifzCursor] {
    var steps: [HifzCursor] = []
    var current = sequence.first()
    while let step = current, steps.count < maxSteps {
        steps.append(step)
        current = sequence.next(after: step)
    }
    return steps
}

// MARK: - Section A: HifzSequence

func testAyahTimesThree() {
    let seq = HifzSequence(unitCount: 1, eachAyah: .times(3), rounds: .times(1), firstRoundOnlyCount: 0)
    let steps = playAll(seq)
    check(steps.count == 3, "sequence: ayah .times(3) plays exactly 3 times")
    check(steps.allSatisfy { $0.unitIndex == 0 }, "sequence: ayah .times(3) stays on unit 0")
}

func testAyahForever() {
    let seq = HifzSequence(unitCount: 1, eachAyah: .forever, rounds: .times(1), firstRoundOnlyCount: 0)
    let steps = playAll(seq, maxSteps: 1000)
    check(steps.count == 1000, "sequence: ayah .forever runs past 1000 steps without stopping")
    check(steps.allSatisfy { $0.unitIndex == 0 }, "sequence: ayah .forever unitIndex always 0")
}

func testFourUnitsThreeRounds() {
    let seq = HifzSequence(unitCount: 4, eachAyah: .times(1), rounds: .times(3), firstRoundOnlyCount: 0)
    let indices = playAll(seq).map(\.unitIndex)
    check(indices == [0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3], "sequence: 4 units x rounds 3 = 12 plays in order")
}

func testFatihaShapedFirstRoundOnly() {
    let seq = HifzSequence(unitCount: 8, eachAyah: .times(1), rounds: .times(2), firstRoundOnlyCount: 1)
    var perRound: [Int: Int] = [:]
    for step in playAll(seq) {
        perRound[step.roundIndex, default: 0] += 1
    }
    check(perRound[0] == 8, "sequence: fatiha-shaped round 1 has 8 plays (incl. isti'adha)")
    check(perRound[1] == 7, "sequence: fatiha-shaped round 2 has 7 plays (isti'adha skipped)")
}

func testEachTwoRoundsTwoThreeUnits() {
    let seq = HifzSequence(unitCount: 3, eachAyah: .times(2), rounds: .times(2), firstRoundOnlyCount: 0)
    let indices = playAll(seq).map(\.unitIndex)
    check(indices == [0, 0, 1, 1, 2, 2, 0, 0, 1, 1, 2, 2], "sequence: each 2 x rounds 2 x 3 units pattern")
}

func testSkipClampsAtBoundaries() {
    let seq = HifzSequence(unitCount: 5, eachAyah: .times(1), rounds: .times(1), firstRoundOnlyCount: 0)
    let mid = HifzCursor(unitIndex: 2, playIndex: 0, roundIndex: 0)

    let below = seq.skip(from: mid, by: -10)
    check(below.unitIndex == 0 && below.playIndex == 0, "sequence: skip clamps below the first unit")

    let above = seq.skip(from: mid, by: 10)
    check(above.unitIndex == 4 && above.playIndex == 0, "sequence: skip clamps above the last unit")

    let forward = seq.skip(from: mid, by: 1)
    check(forward.unitIndex == 3 && forward.playIndex == 0, "sequence: skip +1 moves forward and resets playIndex")
}

func runSequenceTests() {
    testAyahTimesThree()
    testAyahForever()
    testFourUnitsThreeRounds()
    testFatihaShapedFirstRoundOnly()
    testEachTwoRoundsTwoThreeUnits()
    testSkipClampsAtBoundaries()
}

// MARK: - Section B: HifzRepeat / HifzTiming

func runRepeatAndTimingTests() {
    check(HifzRepeat.count(0) == .times(1), "HifzRepeat.count(0) clamps up to 1")
    check(HifzRepeat.count(99) == .times(10), "HifzRepeat.count(99) clamps down to 10")
    check(HifzRepeat.count(5) == .times(5), "HifzRepeat.count(5) passes through unchanged")

    check(HifzTiming.gapSeconds(unitSeconds: 1, playbackRate: 1) == 2, "gapSeconds(1, 1) clamps up to 2")
    check(HifzTiming.gapSeconds(unitSeconds: 4, playbackRate: 1) == 4, "gapSeconds(4, 1) = 4")
    check(HifzTiming.gapSeconds(unitSeconds: 30, playbackRate: 1) == 10, "gapSeconds(30, 1) clamps down to 10")
    check(HifzTiming.gapSeconds(unitSeconds: 4, playbackRate: 0.5) == 8, "gapSeconds(4, 0.5) = 8")
    check(HifzTiming.gapSeconds(unitSeconds: 4, playbackRate: 0) == 4, "gapSeconds rate<=0 falls back to rate 1")
}

// MARK: - Section C: HifzCatalog.build fixtures

/// A minimal `Element` fixture — only `audioUrl`/`start`/`end` matter to the
/// builder; the rest are unused placeholder values.
func fixtureElement(id: String, audioUrl: String?, start: Double, end: Double) -> Element {
    Element(
        id: id, type: .jumla, arabic: "", uzbek: "", audioUrl: audioUrl,
        start: start, end: end, x: 0, y: 0, width: 0, height: 0
    )
}

/// A minimal `SurahIndexItem` fixture. `pageNumber`/`globalIndex` are never
/// read by the builder (it trusts the `lookup` table instead), so both are
/// fixed at 0 here — irrelevant to what's being tested.
func fixtureItem(_ id: String, role: String, ayah: Int?, hasAudio: Bool) -> SurahIndexItem {
    SurahIndexItem(
        elementId: id, pageNumber: 0, globalIndex: 0, role: role, ayah: ayah,
        hasAudio: hasAudio, sharedAudioWith: nil, basmalaAsAyah: nil, sajda: nil
    )
}

func fixtureLookup() -> [String: HifzElementRef] {
    var lookup: [String: HifzElementRef] = [:]
    lookup["t_title"] = HifzElementRef(
        element: fixtureElement(id: "t_title", audioUrl: nil, start: 0, end: 0), globalIndex: 1
    )
    lookup["t_a1"] = HifzElementRef(
        element: fixtureElement(id: "t_a1", audioUrl: "a.mp3", start: 0, end: 2), globalIndex: 1
    )
    lookup["s_a1"] = HifzElementRef(
        element: fixtureElement(id: "s_a1", audioUrl: "b.mp3", start: 0, end: 3), globalIndex: 2
    )
    lookup["s_a2"] = HifzElementRef(
        element: fixtureElement(id: "s_a2", audioUrl: "c.mp3", start: 3, end: 6), globalIndex: 2
    )
    // s_a3 shares s_a2's exact audioUrl/start/end -> the builder must merge them.
    lookup["s_a3"] = HifzElementRef(
        element: fixtureElement(id: "s_a3", audioUrl: "c.mp3", start: 3, end: 6), globalIndex: 2
    )
    // "m_a1" deliberately absent -> surah 203 must be dropped whole.
    return lookup
}

func fixtureIndexFile() -> SurahIndexFile {
    let name = LocalizedString(uzLatn: "Test", uzCyrl: "Тест", ru: "Тест", en: "Test")
    let titleTest = SurahIndexEntry(
        number: 201, key: "titletest", arabicName: "ت", name: name,
        ayahCount: 1, mushafAyahCount: 1, isPartial: false, pages: [1],
        items: [
            fixtureItem("t_title", role: "title", ayah: nil, hasAudio: false),
            fixtureItem("t_a1", role: "ayah", ayah: 1, hasAudio: true)
        ]
    )
    let sharedTest = SurahIndexEntry(
        number: 202, key: "sharedtest", arabicName: "ش", name: name,
        ayahCount: 3, mushafAyahCount: 3, isPartial: false, pages: [2],
        items: [
            fixtureItem("s_a1", role: "ayah", ayah: 1, hasAudio: true),
            fixtureItem("s_a2", role: "ayah", ayah: 2, hasAudio: true),
            fixtureItem("s_a3", role: "ayah", ayah: 3, hasAudio: true)
        ]
    )
    let missingTest = SurahIndexEntry(
        number: 203, key: "missingtest", arabicName: "م", name: name,
        ayahCount: 1, mushafAyahCount: 1, isPartial: false, pages: [3],
        items: [fixtureItem("m_a1", role: "ayah", ayah: 1, hasAudio: true)]
    )
    return SurahIndexFile(schemaVersion: 1, contentVersion: "test", surahs: [titleTest, sharedTest, missingTest])
}

func testCatalogBuilderMergingAndDropping() {
    let (catalog, problems) = HifzCatalog.build(from: fixtureIndexFile(), lookup: fixtureLookup())

    check(catalog.surah(number: 201)?.units.count == 1, "builder: title item skipped, 1 unit remains")
    check(catalog.surah(number: 202)?.units.count == 2, "builder: shared-audio pair merges into 1 unit")

    let mergedUnit = catalog.unit(containing: "s_a3")
    check(mergedUnit?.id == "s_a2", "builder: unit(containing: second-half-id).id == first-half-id")
    check(mergedUnit?.ayahFrom == 2 && mergedUnit?.ayahTo == 3, "builder: merged unit keeps ayahFrom/ayahTo")

    check(catalog.surah(number: 203) == nil, "builder: surah with an unresolvable id is dropped entirely")
    check(problems.contains { $0.contains("203") }, "builder: a problem is recorded for the dropped surah")
    check(catalog.surahs.count == 2, "builder: only the 2 resolvable surahs remain in the catalog")
}

func testCatalogBuilderDegradesGracefully() {
    check(HifzCatalog.build(from: nil, lookup: [:]).catalog.isEmpty, "builder: nil index file -> empty catalog")

    let wrongVersion = SurahIndexFile(schemaVersion: 2, contentVersion: nil, surahs: [])
    let result = HifzCatalog.build(from: wrongVersion, lookup: [:])
    check(result.catalog.isEmpty, "builder: unsupported schemaVersion -> empty catalog")
}

func runCatalogBuilderTests() {
    testCatalogBuilderMergingAndDropping()
    testCatalogBuilderDegradesGracefully()
}

// MARK: - Section D: real data (book.json + surah-index.json), if ready yet

func flattenLookup(from book: Book) -> [String: HifzElementRef] {
    var lookup: [String: HifzElementRef] = [:]
    var globalIndex = 0
    // Mirrors ContentStore.rebuild: chapters by order -> lessons by order -> pageMap order.
    for chapter in book.chapters.sorted(by: { $0.order < $1.order }) {
        let chapterLessons = (book.lessons[chapter.id] ?? []).sorted { $0.order < $1.order }
        for lesson in chapterLessons {
            let pageNumbers = book.pageMap[lesson.id] ?? []
            for pageNumber in pageNumbers {
                let elements = book.pages[String(pageNumber)] ?? []
                for element in elements {
                    lookup[element.id] = HifzElementRef(element: element, globalIndex: globalIndex)
                }
                globalIndex += 1
            }
        }
    }
    return lookup
}

func checkRealDataExpectations(catalog: HifzCatalog, problems: [String]) {
    check(catalog.surahs.count == 26, "real-data: 26 surahs (got \(catalog.surahs.count))")

    let totalUnits = catalog.surahs.reduce(0) { $0 + $1.units.count }
    check(totalUnits == 229, "real-data: 229 units total (got \(totalUnits))")

    let expectedNumbers = [1, 2] + Array(91...114)
    let gotNumbers = catalog.surahs.map(\.number)
    check(gotNumbers == expectedNumbers, "real-data: surah numbers in Mushaf order [1, 2, 91...114]")

    let firstUnitID = catalog.surahs.first?.units.first?.id
    check(firstUnitID == "p36_taawwudh", "real-data: continuous-from-start first unit is p36_taawwudh")

    let lastUnitID = catalog.surahs.last?.units.last?.id
    check(lastUnitID == "p47_ns_a6", "real-data: last unit is p47_ns_a6")

    let allInRange = catalog.surahs.allSatisfy { surah in
        surah.units.allSatisfy { (37...48).contains($0.globalIndex) }
    }
    check(allInRange, "real-data: every unit's globalIndex is in 37...48")

    check(catalog.surah(number: 2)?.isPartial == true, "real-data: Baqara is marked isPartial")

    let problemSummary = problems.joined(separator: "; ")
    check(problems.isEmpty, "real-data: no problems reported (\(problems.count): \(problemSummary))")
}

func runRealDataSection(repoRoot: String) {
    let resourcesURL = URL(fileURLWithPath: repoRoot).appendingPathComponent("MuallimiSoniy/Resources")
    let indexURL = resourcesURL.appendingPathComponent("surah-index.json")
    let bookURL = resourcesURL.appendingPathComponent("book.json")

    guard let indexData = try? Data(contentsOf: indexURL),
          let indexFile = try? JSONDecoder().decode(SurahIndexFile.self, from: indexData)
    else {
        let reason = "missing or not the wrapped {schemaVersion,surahs} shape (regenerate with tools/surah-index)"
        print("SKIP  real-data section: \(indexURL.path) \(reason)")
        return
    }

    guard let bookData = try? Data(contentsOf: bookURL),
          let book = try? JSONDecoder().decode(Book.self, from: bookData)
    else {
        check(false, "real-data: failed to load/decode book.json at \(bookURL.path)")
        return
    }

    let lookup = flattenLookup(from: book)
    let (catalog, problems) = HifzCatalog.build(from: indexFile, lookup: lookup)
    checkRealDataExpectations(catalog: catalog, problems: problems)
}

// MARK: - Entry point

runSequenceTests()
runRepeatAndTimingTests()
runCatalogBuilderTests()

let repoRoot = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath
runRealDataSection(repoRoot: repoRoot)

print("")
print("Summary: \(passCount) passed, \(failCount) failed")
exit(failCount == 0 ? 0 : 1)
