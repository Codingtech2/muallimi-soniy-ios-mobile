import Foundation

/// Name (and optional chig'atoy note) a surah banner shows when the page has no
/// title element of its own for that surah.
nonisolated struct MushafBannerText: Sendable, Hashable {
    let text: String
    var sub: String?
}

/// One block of a surah page in the Mushaf view — the port of the web `Block`
/// type in `MushafPage.tsx`.
nonisolated enum MushafBlock: Hashable, Sendable, Identifiable {
    /// A surah's name frame, drawn right before its bismillah. `lead` is the
    /// page's own title element for that surah, when the book has one.
    case banner(surah: Int, lead: Element?)
    /// The isti'adha or a bismillah, centred on its own line.
    case line(MushafFlowItem)
    /// The ayat of one surah on this page, as one flowing paragraph.
    case flow(surah: Int, items: [MushafFlowItem])

    var id: String {
        switch self {
        case .banner(let surah, _): return "banner-\(surah)"
        case .line(let item): return item.id
        case .flow(let surah, let items): return "flow-\(items.first?.id ?? String(surah))"
        }
    }

    var isBanner: Bool {
        if case .banner = self { return true }
        return false
    }
}

/// Pure helpers behind `MushafPageView` — a straight port of `buildBlocks`,
/// `BANNERS` and `sameAudio` from the web `MushafPage.tsx`, kept free of any
/// view code so the grouping rules read (and check) on their own.
nonisolated enum MushafBlocks {

    /// Banner text for surahs whose page has no title element — the web
    /// `BANNERS` table (spec Appendix B), copied character for character
    /// (the notes keep their zero-width non-joiner). Shams, Layl, Duha, Humaza
    /// and Fil are missing on purpose: their banner shows the title element.
    static let banners: [Int: MushafBannerText] = [
        1: MushafBannerText(text: "سُورَةُ الْفَاتِحَة"),
        2: MushafBannerText(text: "اَوَّلُ سُورَةِ الْبَقَرَة"),
        94: MushafBannerText(text: "سورة الشرح", sub: "شرح سوره\u{200C}سی"),
        95: MushafBannerText(text: "سورة التين", sub: "تین سوره\u{200C}سی"),
        96: MushafBannerText(text: "سورة العلق", sub: "علق سوره\u{200C}سی"),
        97: MushafBannerText(text: "سورة القدر", sub: "قدر سوره\u{200C}سی"),
        98: MushafBannerText(text: "سورة البينة", sub: "بیّنه سوره\u{200C}سی"),
        99: MushafBannerText(text: "سورة الزلزلة", sub: "زلزله سوره\u{200C}سی"),
        100: MushafBannerText(text: "سورة العاديات", sub: "عادیات سوره\u{200C}سی"),
        101: MushafBannerText(text: "سورة القارعة", sub: "قارعه سوره\u{200C}سی"),
        102: MushafBannerText(text: "سورة التكاثر", sub: "تکاثر سوره\u{200C}سی"),
        103: MushafBannerText(text: "سورة العصر", sub: "عصر سوره\u{200C}سی"),
        106: MushafBannerText(text: "سُورَةُ قُرَيْشٍ"),
        107: MushafBannerText(text: "سُورَةُ الْمَاعُونِ"),
        108: MushafBannerText(text: "سُورَةُ الْكَوْثَرِ"),
        109: MushafBannerText(text: "سُورَةُ الْكَافِرُونَ"),
        110: MushafBannerText(text: "سُورَةُ النَّصْرِ"),
        111: MushafBannerText(text: "سُورَةُ الْمَسَدِ"),
        112: MushafBannerText(text: "سُورَةُ الْإِخْلَاصِ"),
        113: MushafBannerText(text: "سُورَةُ الْفَلَقِ"),
        114: MushafBannerText(text: "سُورَةُ النَّاسِ")
    ]

    /// Splits a page's elements (book order) into blocks, like web `buildBlocks`:
    /// - not in `verses` (a `*_title`) → remembered as the next banner's `lead`;
    /// - the isti'adha (surah 0) → a centred line, no number;
    /// - a bismillah (ayah 0, or al-Fatiha's ayah 1) → banner, then a centred
    ///   line (numbered only in al-Fatiha);
    /// - any other ayah → joins the current paragraph of its surah, or opens a
    ///   new one — so a surah carried over from the previous page starts with
    ///   no banner, like the printed book.
    static func build(elements: [Element], verses: [String: MushafVerseRef]) -> [MushafBlock] {
        var blocks: [MushafBlock] = []
        var lead: Element?
        for element in elements {
            guard let verse = verses[element.id] else {
                lead = element
                continue
            }
            if verse.surah == 0 {
                blocks.append(.line(MushafFlowItem(element: element, number: nil, sajda: false)))
                continue
            }
            if verse.ayah == 0 || (verse.surah == 1 && verse.ayah == 1) {
                blocks.append(.banner(surah: verse.surah, lead: lead))
                lead = nil
                let number = verse.ayah == 0 ? nil : verse.ayah
                blocks.append(.line(MushafFlowItem(element: element, number: number, sajda: false)))
                continue
            }
            let item = MushafFlowItem(element: element, number: verse.ayah, sajda: verse.sajda)
            if case .flow(let surah, let items)? = blocks.last, surah == verse.surah {
                blocks[blocks.count - 1] = .flow(surah: surah, items: items + [item])
            } else {
                blocks.append(.flow(surah: verse.surah, items: [item]))
            }
        }
        return blocks
    }

    /// What a banner shows: the title element's text when the page has one,
    /// otherwise the `banners` table (web `lead?.arabic ?? text`). The note
    /// always comes from the table.
    static func bannerText(surah: Int, lead: Element?) -> MushafBannerText {
        let table = banners[surah]
        return MushafBannerText(text: lead?.arabic ?? table?.text ?? "", sub: table?.sub)
    }

    /// Two elements recorded as one audio take (Ma'un 4+5, Ikhlas 3+4) light
    /// up together. Decided by the audio fields, never by id (web `sameAudio`).
    static func sameAudio(_ lhs: Element, _ rhs: Element) -> Bool {
        guard let url = lhs.audioUrl, !url.isEmpty else { return false }
        return url == rhs.audioUrl && lhs.start == rhs.start && lhs.end == rhs.end
    }

    /// The ids to highlight on a page: the active element plus every element on
    /// the page that shares its audio take (web `isActive`).
    static func highlightedIds(activeId: String?, elements: [Element]) -> Set<String> {
        guard let activeId else { return [] }
        var ids: Set<String> = [activeId]
        if let active = elements.first(where: { $0.id == activeId }) {
            for element in elements where sameAudio(element, active) {
                ids.insert(element.id)
            }
        }
        return ids
    }
}

#if DEBUG
extension MushafBlocks {
    /// There is no unit-test target, so DEBUG builds run the grouping rules once
    /// on a tiny made-up page and log any mismatch (`MushafPageView` calls it).
    nonisolated static func selfCheckFailures() -> [String] {
        func element(_ id: String, audio: String? = nil, start: Double = 0, end: Double = 0) -> Element {
            Element(id: id, type: .jumla, arabic: id, uzbek: "", audioUrl: audio, start: start, end: end,
                    x: 0, y: 0, width: 0, height: 0)
        }
        func ref(_ surah: Int, _ ayah: Int, sajda: Bool = false) -> MushafVerseRef {
            let role: MushafVerseRef.Role = surah == 0 ? .taawwudh : (ayah == 0 ? .bismillah : .ayah)
            return MushafVerseRef(surah: surah, ayah: ayah, role: role, sajda: sajda)
        }
        let page = [
            element("taawwudh"), element("fa_bismi"), element("fa_2"), element("fa_3"),
            element("ll_8"), element("du_title"), element("du_bism"), element("du_1", audio: "a", end: 2),
            element("du_2", audio: "a", end: 2), element("al_19")
        ]
        let verses: [String: MushafVerseRef] = [
            "taawwudh": ref(0, 0), "fa_bismi": ref(1, 1), "fa_2": ref(1, 2), "fa_3": ref(1, 3),
            "ll_8": ref(92, 8), "du_bism": ref(93, 0), "du_1": ref(93, 1), "du_2": ref(93, 2),
            "al_19": ref(96, 19, sajda: true)
        ]
        let shape = build(elements: page, verses: verses).map(describe)
        let expected = [
            "line taawwudh", "banner 1 -", "line fa_bismi#1", "flow 1 fa_2#2 fa_3#3", "flow 92 ll_8#8",
            "banner 93 du_title", "line du_bism", "flow 93 du_1#1 du_2#2", "flow 96 al_19#19۩"
        ]
        var failures: [String] = []
        if shape != expected {
            failures.append("buildBlocks: got \(shape), expected \(expected)")
        }
        let paired = highlightedIds(activeId: "du_2", elements: page)
        if paired != ["du_1", "du_2"] {
            failures.append("sameAudio pair: got \(paired.sorted())")
        }
        if sameAudio(page[0], page[1]) {
            failures.append("sameAudio: elements without audio must never pair")
        }
        return failures
    }

    /// One-line summary of a block for `selfCheckFailures`.
    nonisolated private static func describe(_ block: MushafBlock) -> String {
        func item(_ item: MushafFlowItem) -> String {
            item.id + (item.number.map { "#\($0)" } ?? "") + (item.sajda ? "۩" : "")
        }
        switch block {
        case .banner(let surah, let lead): return "banner \(surah) \(lead?.id ?? "-")"
        case .line(let line): return "line \(item(line))"
        case .flow(let surah, let items): return "flow \(surah) " + items.map(item).joined(separator: " ")
        }
    }
}
#endif
