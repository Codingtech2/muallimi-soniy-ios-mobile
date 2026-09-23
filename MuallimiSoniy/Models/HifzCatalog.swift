import Foundation

/// A resolved book element plus its position in the flattened book — the
/// only two facts `HifzCatalog.build` needs about an element. Keeping this
/// separate from `BookPage`/`ContentStore` is what lets `HifzModels.swift` +
/// `HifzCatalog.swift` compile standalone in the `tools/hifz-check` harness.
nonisolated struct HifzElementRef: Sendable {
    let element: Element
    let globalIndex: Int
}

/// Everything needed to drive one hifz playback run.
///
/// `sequence` already has the right `unitCount` and `firstRoundOnlyCount` for
/// `units`, but its `eachAyah`/`rounds` are neutral `.times(1)` placeholders
/// — the caller (`HifzController.start`) combines them with the user's
/// `HifzPlan.eachAyah`/`HifzPlan.rounds` to build the sequence it actually
/// steps through, e.g.:
/// `HifzSequence(unitCount: session.sequence.unitCount, eachAyah: plan.eachAyah,`
/// `rounds: plan.rounds, firstRoundOnlyCount: session.sequence.firstRoundOnlyCount)`
nonisolated struct HifzSession: Sendable {
    let units: [HifzUnit]
    let sequence: HifzSequence
}

/// Resolved, lookup-ready hifz content: every surah's memorizable units plus
/// fast indices for the reader/UI. Built once by `build(from:lookup:)`
/// (`ContentStore.load()`) and never mutated afterwards.
nonisolated struct HifzCatalog: Sendable {
    /// All surahs, in Qur'an/Mushaf order (same order as the index file).
    let surahs: [HifzSurah]

    private let surahByNumber: [Int: HifzSurah]
    /// Both element ids of a merged pair (e.g. Ikhlas 3-4) map to the same
    /// unit, so a tap on either half resolves the whole unit.
    private let unitByElementId: [String: HifzUnit]
    private let surahNumberByElementId: [String: Int]
    /// Global page index -> surah numbers with at least one unit there, in
    /// `surahs` order (stable for UI lists).
    private let surahNumbersByGlobalIndex: [Int: [Int]]

    static let empty = HifzCatalog(surahs: [])

    private init(surahs: [HifzSurah]) {
        self.surahs = surahs

        var byNumber: [Int: HifzSurah] = [:]
        var byElementId: [String: HifzUnit] = [:]
        var surahNumberByElementId: [String: Int] = [:]
        var numbersByGlobalIndex: [Int: [Int]] = [:]

        for surah in surahs {
            byNumber[surah.number] = surah
            var seenPagesForSurah: Set<Int> = []
            for unit in surah.units {
                for elementId in unit.elementIds {
                    byElementId[elementId] = unit
                    surahNumberByElementId[elementId] = surah.number
                }
                if seenPagesForSurah.insert(unit.globalIndex).inserted {
                    numbersByGlobalIndex[unit.globalIndex, default: []].append(surah.number)
                }
            }
        }

        self.surahByNumber = byNumber
        self.unitByElementId = byElementId
        self.surahNumberByElementId = surahNumberByElementId
        self.surahNumbersByGlobalIndex = numbersByGlobalIndex
    }

    var isEmpty: Bool { surahs.isEmpty }

    func surah(number: Int) -> HifzSurah? {
        surahByNumber[number]
    }

    func unit(containing elementId: String) -> HifzUnit? {
        unitByElementId[elementId]
    }

    func surah(containing elementId: String) -> HifzSurah? {
        surahNumberByElementId[elementId].flatMap { surahByNumber[$0] }
    }

    func surahs(onGlobalPage globalIndex: Int) -> [HifzSurah] {
        (surahNumbersByGlobalIndex[globalIndex] ?? []).compactMap { surahByNumber[$0] }
    }

    func hasUnits(onGlobalPage globalIndex: Int) -> Bool {
        !(surahNumbersByGlobalIndex[globalIndex] ?? []).isEmpty
    }

    /// The global page of a surah's first unit — e.g. to open the reader for
    /// DEBUG `-MSHifz surah:N` or a surah-list row's play button.
    func startGlobalIndex(for surahNumber: Int) -> Int? {
        surahByNumber[surahNumber]?.startGlobalIndex
    }

    /// Builds a ready-to-play session for the given scope, or nil if its
    /// target can't be resolved in this catalog (stale/unknown unit id).
    func session(for scope: HifzScope) -> HifzSession? {
        switch scope {
        case .ayah(let unitID):
            guard let unit = unitByElementId[unitID] else { return nil }
            let sequence = HifzSequence(unitCount: 1, eachAyah: .times(1), rounds: .times(1), firstRoundOnlyCount: 0)
            return HifzSession(units: [unit], sequence: sequence)

        case .surah(let number):
            guard let surah = surahByNumber[number], !surah.units.isEmpty else { return nil }
            let firstRoundOnly = surah.units.first?.role == .taawwudh ? 1 : 0
            let sequence = HifzSequence(
                unitCount: surah.units.count, eachAyah: .times(1),
                rounds: .times(1), firstRoundOnlyCount: firstRoundOnly
            )
            return HifzSession(units: surah.units, sequence: sequence)

        case .continuous(let fromUnitID):
            guard let anchor = unitByElementId[fromUnitID] else { return nil }
            let flattened = surahs.flatMap(\.units)
            guard let startPosition = flattened.firstIndex(where: { $0.id == anchor.id }) else { return nil }
            let remaining = Array(flattened[startPosition...])
            let sequence = HifzSequence(
                unitCount: remaining.count, eachAyah: .times(1), rounds: .times(1), firstRoundOnlyCount: 0
            )
            return HifzSession(units: remaining, sequence: sequence)
        }
    }

    // MARK: - Building from the index file

    /// Resolves the index file into a catalog against `lookup` (every
    /// element id in the book, keyed by id, from `ContentStore`'s flattened
    /// pages). Never crashes on bad content: an unresolvable index just
    /// drops that one surah (or the whole file) and explains why in
    /// `problems`, which the caller logs.
    static func build(
        from indexFile: SurahIndexFile?,
        lookup: [String: HifzElementRef]
    ) -> (catalog: HifzCatalog, problems: [String]) {
        guard let indexFile else {
            return (.empty, ["hifz: surah index file is missing or failed to decode"])
        }
        guard indexFile.schemaVersion == 1 else {
            return (.empty, ["hifz: unsupported surah index schemaVersion \(indexFile.schemaVersion), expected 1"])
        }

        var problems: [String] = []
        var surahs: [HifzSurah] = []
        for entry in indexFile.surahs {
            if let units = resolveUnits(for: entry, lookup: lookup, problems: &problems) {
                surahs.append(HifzSurah(
                    number: entry.number,
                    key: entry.key,
                    arabicName: entry.arabicName,
                    name: entry.name,
                    ayahCount: entry.ayahCount,
                    isPartial: entry.isPartial,
                    units: units
                ))
            }
        }
        return (HifzCatalog(surahs: surahs), problems)
    }

    /// Resolves one surah's raw items into units, or nil (with a problem
    /// appended) if anything playable can't be resolved — a surah is
    /// included whole or not at all, never partially.
    private static func resolveUnits(
        for entry: SurahIndexEntry,
        lookup: [String: HifzElementRef],
        problems: inout [String]
    ) -> [HifzUnit]? {
        var resolved: [ResolvedHifzItem] = []
        for item in entry.items {
            guard item.hasAudio, let role = HifzUnitRole(rawValue: item.role) else {
                if item.hasAudio, item.role != "title" {
                    let name = entry.key
                    let reason = "unknown role '\(item.role)' for \(item.elementId), skipped"
                    problems.append("hifz surah \(entry.number) (\(name)): \(reason)")
                }
                continue
            }
            guard let ref = lookup[item.elementId],
                  let audioUrl = ref.element.audioUrl, !audioUrl.isEmpty,
                  ref.element.start < ref.element.end
            else {
                problems.append(
                    "hifz surah \(entry.number) (\(entry.key)): \(item.elementId) has no usable audio, surah dropped"
                )
                return nil
            }
            resolved.append(ResolvedHifzItem(
                elementId: item.elementId, role: role, ayah: item.ayah,
                audioUrl: audioUrl, start: ref.element.start, end: ref.element.end,
                globalIndex: ref.globalIndex
            ))
        }

        guard !resolved.isEmpty else {
            problems.append("hifz surah \(entry.number) (\(entry.key)): no playable units, surah dropped")
            return nil
        }
        return mergeUnits(from: resolved, surahNumber: entry.number)
    }

    /// Merges consecutive items that share one audio take (same file, same
    /// start/end — the qori recorded 2 ayat in one clip) into a single unit.
    private static func mergeUnits(from resolved: [ResolvedHifzItem], surahNumber: Int) -> [HifzUnit] {
        var units: [HifzUnit] = []
        var index = 0
        while index < resolved.count {
            let current = resolved[index]
            let next = index + 1 < resolved.count ? resolved[index + 1] : nil
            if let next, next.audioUrl == current.audioUrl, next.start == current.start, next.end == current.end {
                units.append(HifzUnit(
                    id: current.elementId, elementIds: [current.elementId, next.elementId],
                    surahNumber: surahNumber, role: current.role,
                    ayahFrom: current.ayah, ayahTo: next.ayah,
                    globalIndex: current.globalIndex, audioPath: current.audioUrl,
                    start: current.start, end: current.end
                ))
                index += 2
            } else {
                units.append(HifzUnit(
                    id: current.elementId, elementIds: [current.elementId],
                    surahNumber: surahNumber, role: current.role,
                    ayahFrom: current.ayah, ayahTo: current.ayah,
                    globalIndex: current.globalIndex, audioPath: current.audioUrl,
                    start: current.start, end: current.end
                ))
                index += 1
            }
        }
        return units
    }
}

/// One index-file item after its audio has been resolved against the book —
/// an internal stepping stone between `SurahIndexItem` (raw JSON) and
/// `HifzUnit` (final, possibly-merged), used only while building a catalog.
private struct ResolvedHifzItem {
    let elementId: String
    let role: HifzUnitRole
    let ayah: Int?
    let audioUrl: String
    let start: Double
    let end: Double
    let globalIndex: Int
}
