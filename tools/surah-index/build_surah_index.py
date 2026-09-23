#!/usr/bin/env python3
"""
build_surah_index.py - build and verify the surah -> ordered-element index for
the Quran pages (book pages 36-47, lesson ls_suralar) of Muallimi Soniy.

Standard library only. It reads MuallimiSoniy/Resources/{book, audio-manifest,
content-manifest}.json, the Swift page views and surah-names.json (next to this
script). It writes only the --bundle-out file, plus raw API answers in .cache/
(next to this script, gitignored) when --online has to fetch something.

Usage (run from the repo root):
  python3 tools/surah-index/build_surah_index.py              # verify only, no network (= --offline)
  python3 tools/surah-index/build_surah_index.py --bundle-out MuallimiSoniy/Resources/surah-index.json
  python3 tools/surah-index/build_surah_index.py --online     # + canonical Quran text check (.cache/ first)
  python3 tools/surah-index/build_surah_index.py --online --refresh          # refetch, ignore .cache/
  python3 tools/surah-index/build_surah_index.py --online --source qurancom  # api.quran.com first
  python3 tools/surah-index/build_surah_index.py --web-public <web repo>/public  # + mp3 sha256 / duration

The report goes to stdout. The bundle is written only when the report has no errors.
Exit code: 0 when there are no ERROR lines, 1 otherwise.
"""

from __future__ import annotations

import argparse
import difflib
import hashlib
import itertools
import json
import re
import subprocess
import sys
import unicodedata
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

TOOL_DIR = Path(__file__).resolve().parent  # tools/surah-index
REPO_ROOT = Path(__file__).resolve().parents[2]
APP_ROOT = REPO_ROOT / "MuallimiSoniy"
BOOK_JSON = APP_ROOT / "Resources/book.json"
AUDIO_MANIFEST = APP_ROOT / "Resources/audio-manifest.json"
CONTENT_MANIFEST = APP_ROOT / "Resources/content-manifest.json"
PAGES_DIR = APP_ROOT / "Features/Reader/Pages"
DISPATCHER = APP_ROOT / "Features/Reader/PageDispatcher.swift"
NAMES_JSON = TOOL_DIR / "surah-names.json"
CACHE_DIR = TOOL_DIR / ".cache"

# Bundle format read by the app (SurahIndexFile). Bump both sides together.
BUNDLE_SCHEMA_VERSION = 1
NAME_LOCALES = ("uz-latn", "uz-cyrl", "ru", "en")

QURAN_PAGES = list(range(36, 48))
QURAN_LESSON = "ls_suralar"
HTTP_TIMEOUT = 20  # seconds per request
MAX_NETWORK_FAILURES = (
    3  # consecutive surahs with both APIs failing -> treat network as down
)
TEXT_RATIO_MIN = 0.90  # difflib ratio below this is reported
DURATION_TOLERANCE = 0.10  # seconds between element.end and the real mp3 duration

# Sajda (prostration) ayat that appear in the book. 84:21 is not in the book.
SAJDA_AYAT = {(96, 19)}

# The 26 sections in book order. `parts` = (book page, element-id regex).
# `bookRange` is set only where the book prints part of a surah (Baqara 1-5).
SECTIONS = [
    dict(
        number=1,
        key="fatiha",
        arabicName="الفاتحة",
        mushaf=7,
        audioDir="56_fotiha_baqara",
        parts=[(36, r"^p36_(taawwudh|fa_\w+)$")],
    ),
    dict(
        number=2,
        key="baqara",
        arabicName="البقرة",
        mushaf=286,
        bookRange=(1, 5),
        audioDir="56_fotiha_baqara",
        parts=[(36, r"^p36_bq_\w+$")],
    ),
    dict(
        number=91,
        key="shams",
        arabicName="الشمس",
        mushaf=15,
        audioDir="58_shams",
        parts=[(37, r"^p37_sh_\w+$")],
    ),
    dict(
        number=92,
        key="layl",
        arabicName="الليل",
        mushaf=21,
        audioDir="59_layl",
        parts=[(37, r"^p37_ll_\w+$"), (38, r"^p38_ll_\w+$")],
    ),
    dict(
        number=93,
        key="duha",
        arabicName="الضحى",
        mushaf=11,
        audioDir="60_zuho",
        parts=[(38, r"^p38_du_\w+$"), (39, r"^p39_duho_\w+$")],
    ),
    dict(
        number=94,
        key="sharh",
        arabicName="الشرح",
        mushaf=8,
        audioDir="61_sharh",
        parts=[(39, r"^p39_sharh_\w+$")],
    ),
    dict(
        number=95,
        key="tin",
        arabicName="التين",
        mushaf=8,
        audioDir="62_tiyn",
        parts=[(39, r"^p39_tin_\w+$")],
    ),
    dict(
        number=96,
        key="alaq",
        arabicName="العلق",
        mushaf=19,
        audioDir="63_alaq",
        parts=[(39, r"^p39_alaq_\w+$"), (40, r"^p40_a\d+$")],
    ),
    dict(
        number=97,
        key="qadr",
        arabicName="القدر",
        mushaf=5,
        audioDir="64_qadr",
        parts=[(40, r"^p40_q(_bism|\d+)$")],
    ),
    dict(
        number=98,
        key="bayyina",
        arabicName="البينة",
        mushaf=8,
        audioDir="65_bayyina",
        parts=[(41, r"^p41_(bism|a\d+)$")],
    ),
    dict(
        number=99,
        key="zalzala",
        arabicName="الزلزلة",
        mushaf=8,
        audioDir="66_zalzala",
        parts=[(42, r"^p42_zz_\w+$")],
    ),
    dict(
        number=100,
        key="adiyat",
        arabicName="العاديات",
        mushaf=11,
        audioDir="67_adiya",
        parts=[(42, r"^p42_ad_\w+$")],
    ),
    dict(
        number=101,
        key="qaria",
        arabicName="القارعة",
        mushaf=11,
        audioDir="68_qoria",
        parts=[(43, r"^p43_qr_\w+$")],
    ),
    dict(
        number=102,
        key="takathur",
        arabicName="التكاثر",
        mushaf=8,
        audioDir="69_takasur",
        parts=[(43, r"^p43_tk_\w+$")],
    ),
    dict(
        number=103,
        key="asr",
        arabicName="العصر",
        mushaf=3,
        audioDir="70_asr",
        parts=[(43, r"^p43_as_\w+$"), (44, r"^p44_as_\w+$")],
    ),
    dict(
        number=104,
        key="humaza",
        arabicName="الهمزة",
        mushaf=9,
        audioDir="71_humaza",
        parts=[(44, r"^p44_hu_\w+$")],
    ),
    dict(
        number=105,
        key="fil",
        arabicName="الفيل",
        mushaf=5,
        audioDir="72_fil",
        parts=[(44, r"^p44_fi_\w+$")],
    ),
    dict(
        number=106,
        key="quraysh",
        arabicName="قريش",
        mushaf=4,
        audioDir="73_quraysh",
        parts=[(45, r"^p45_qu_\w+$")],
    ),
    dict(
        number=107,
        key="maun",
        arabicName="الماعون",
        mushaf=7,
        audioDir="74_mauvn",
        parts=[(45, r"^p45_ma_\w+$")],
    ),
    dict(
        number=108,
        key="kawthar",
        arabicName="الكوثر",
        mushaf=3,
        audioDir="75_kavsar",
        parts=[(45, r"^p45_ka_\w+$")],
    ),
    dict(
        number=109,
        key="kafirun",
        arabicName="الكافرون",
        mushaf=6,
        audioDir="76_kafirun",
        parts=[(45, r"^p45_kf_\w+$"), (46, r"^p46_kf_\w+$")],
    ),
    dict(
        number=110,
        key="nasr",
        arabicName="النصر",
        mushaf=3,
        audioDir="77_nasr",
        parts=[(46, r"^p46_ns_\w+$")],
    ),
    dict(
        number=111,
        key="masad",
        arabicName="المسد",
        mushaf=5,
        audioDir="78_masad",
        parts=[(46, r"^p46_ms_\w+$")],
    ),
    dict(
        number=112,
        key="ikhlas",
        arabicName="الإخلاص",
        mushaf=4,
        audioDir="79_ixlos",
        parts=[(46, r"^p46_ix_\w+$")],
    ),
    dict(
        number=113,
        key="falaq",
        arabicName="الفلق",
        mushaf=5,
        audioDir="80_falaq",
        parts=[(47, r"^p47_fq_\w+$")],
    ),
    dict(
        number=114,
        key="nas",
        arabicName="الناس",
        mushaf=6,
        audioDir="81_nos",
        parts=[(47, r"^p47_ns_\w+$")],
    ),
]

# Mushaf (Hafs/Kufan) ayah counts from Tanzil / api.quran.com, an independent cross-check of the table above.
EXPECTED_MUSHAF_COUNTS = {
    1: 7,
    91: 15,
    92: 21,
    93: 11,
    94: 8,
    95: 8,
    96: 19,
    97: 5,
    98: 8,
    99: 8,
    100: 11,
    101: 11,
    102: 8,
    103: 3,
    104: 9,
    105: 5,
    106: 4,
    107: 7,
    108: 3,
    109: 6,
    110: 3,
    111: 5,
    112: 4,
    113: 5,
    114: 6,
}


# --------------------------------------------------------------------------- report


class Report:
    """Collects report lines and counts errors / warnings."""

    def __init__(self) -> None:
        self.lines: list[str] = []
        self.errors = 0
        self.warnings = 0

    def h(self, title: str) -> None:
        self.lines += ["", f"== {title} =="]

    def ok(self, msg: str) -> None:
        self.lines.append(f"  OK    {msg}")

    def info(self, msg: str) -> None:
        self.lines.append(f"  INFO  {msg}")

    def warn(self, msg: str) -> None:
        self.warnings += 1
        self.lines.append(f"  WARN  {msg}")

    def err(self, msg: str) -> None:
        self.errors += 1
        self.lines.append(f"  ERROR {msg}")

    def raw(self, msg: str = "") -> None:
        self.lines.append(msg)

    def text(self) -> str:
        return "\n".join(self.lines) + "\n"


# --------------------------------------------------------------------------- helpers


def load_json(path: Path):
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def flatten(book: dict) -> list[dict]:
    """Mirror of ContentStore.rebuild(): chapters by order -> lessons by order -> pageMap."""
    pages, global_index = [], 0
    for chapter in sorted(book["chapters"], key=lambda c: c["order"]):
        for lesson in sorted(
            book["lessons"].get(chapter["id"], []), key=lambda ls: ls["order"]
        ):
            for page_number in book["pageMap"].get(lesson["id"], []):
                pages.append(
                    {
                        "globalIndex": global_index,
                        "pageNumber": page_number,
                        "lessonId": lesson["id"],
                    }
                )
                global_index += 1
    return pages


BASMALA_SUFFIX = re.compile(r"(?:^|_)bism(?:i|illah)?$")


def id_suffix(element_id: str) -> str:
    """'p37_sh_a1' -> 'sh_a1' (ids are 'p{page}_{suffix}')."""
    return element_id.split("_", 1)[1] if "_" in element_id else element_id


def classify(element_id: str, surah_number: int) -> tuple[str, int | None]:
    """Role + ayah number from the element id alone (independent signals are checked later)."""
    suffix = id_suffix(element_id)
    if suffix == "taawwudh":
        return "taawwudh", None
    if suffix == "title" or suffix.endswith("_title"):
        return "title", None
    if BASMALA_SUFFIX.search(suffix):
        # Hafs/Kufan count: the basmala is ayah 1 of al-Fatiha only.
        return ("ayah", 1) if surah_number == 1 else ("bismillah", None)
    match = re.search(r"(\d+)$", suffix)
    if match:
        return "ayah", int(match.group(1))
    return "unknown", None


def has_audio(element: dict) -> bool:
    return bool(element.get("audioUrl")) and element.get("end", 0) > element.get(
        "start", 0
    )


def audio_file_ayahs(audio_url: str) -> list[int]:
    """'audio/edit/74_mauvn/p45_ma_a4_a5.mp3' -> [4, 5]; bismillah files -> []."""
    tokens = Path(audio_url).stem.split("_")[1:]
    return [
        int(re.sub(r"^[avq]", "", t)) for t in tokens if re.fullmatch(r"[avq]?\d+", t)
    ]


def label_ayah(uzbek: str) -> int | None:
    match = re.search(r"(\d+)-oyat", uzbek or "")
    return int(match.group(1)) if match else None


# --------------------------------------------------------------------------- Arabic normalisation

# Marks dropped before comparing: harakat, superscript alif, tatweel and Quranic annotation signs.
STRIP_MARKS = re.compile("[\u0610-\u061a\u064b-\u065f\u0670\u0640\u06d6-\u06ed]")
LETTER_MAP = str.maketrans(
    {
        "أ": "ا",
        "إ": "ا",
        "آ": "ا",
        "ٱ": "ا",  # أ إ آ ٱ -> ا
        "ٲ": "ا",
        "ٳ": "ا",
        "ى": "ي",
        "ئ": "ي",
        "ی": "ي",  # ى ئ ی -> ي
        "ة": "ه",
        "ۀ": "ه",
        "ە": "ه",  # ة -> ه
        "ؤ": "و",  # ؤ -> و
        "ک": "ك",  # ک -> ك
    }
)
# Keeps only the basic Arabic letters: drops spaces, digits, punctuation, ZWNJ, ornaments.
NON_LETTER = re.compile("[^\u0621-\u064a]")
BASMALA_TEXT = "بسم الله الرحمن الرحيم"
TAAWWUDH_TEXT = "أعوذ بالله من الشيطان الرجيم"


def norm(text: str) -> str:
    text = unicodedata.normalize("NFKC", text or "")
    text = STRIP_MARKS.sub("", text)
    text = text.translate(LETTER_MAP)
    return NON_LETTER.sub("", text)


def ratio(a: str, b: str) -> float:
    return difflib.SequenceMatcher(None, a, b, autojunk=False).ratio()


BASMALA_N = norm(BASMALA_TEXT)
TAAWWUDH_N = norm(TAAWWUDH_TEXT)


# --------------------------------------------------------------------------- Swift page-view parsing

SUFFIX_LITERAL = re.compile(r"^[a-z][a-z0-9_]*$")
TOKEN = re.compile(r'"((?:[^"\\\n]|\\.)*)"|\bSelf\.(\w+)|\b([A-Za-z_]\w*)\s*\(')


def strip_line_comments(src: str) -> str:
    """Removes // comments that are not inside a string literal (enough for these files)."""
    out = []
    for line in src.splitlines():
        in_string, cut = False, len(line)
        for i, ch in enumerate(line):
            if ch == '"' and (i == 0 or line[i - 1] != "\\"):
                in_string = not in_string
            elif not in_string and line.startswith("//", i):
                cut = i
                break
        out.append(line[:cut])
    return "\n".join(out)


def brace_block(src: str, start: int) -> tuple[int, int]:
    """(open, close) indices of the first {...} block at or after `start`, ignoring braces in strings."""
    open_index = src.index("{", start)
    depth, in_string = 0, False
    for j in range(open_index, len(src)):
        ch = src[j]
        if ch == '"' and src[j - 1] != "\\":
            in_string = not in_string
        elif not in_string:
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return open_index, j
    raise ValueError("unbalanced braces")


def line_at(src: str, index: int) -> tuple[str, str]:
    """(line containing index, following line)."""
    line_start = src.rfind("\n", 0, index) + 1
    line_end = src.find("\n", index)
    line_end = len(src) if line_end == -1 else line_end
    next_end = src.find("\n", line_end + 1)
    next_end = len(src) if next_end == -1 else next_end
    return src[line_start:line_end], src[line_end + 1 : next_end]


def view_role_of(line: str, next_line: str) -> str:
    """How a page view renders the literal on this line (title / bismillah / unnumbered verse / ayah)."""
    for text in (line, next_line):
        if re.search(r"\b(title|flowerTitle|TappableSurahTitle)\s*\(", text):
            return "title"
        if re.search(r"\b(bism|bismillah|WordRow)\s*\(", text):
            return "bismillah"
        if re.search(r"\blinkedPair\s*\(", text):
            return "ayah"
        if re.search(r"\bverse\s*\(", text):
            return "ayah" if re.search(r"\bayah:\s*\d", text) else "unnumbered"
        if re.search(r"\b(ayah|AyahRow|SajdaRow)\s*\(", text) or re.search(
            r"\bstatic let \w*ayah\w*", text, re.I
        ):
            return "ayah"
    return "unknown"


def view_ayah_numbers(line: str) -> dict[str, int]:
    """Explicit ayah numbers a view passes: verse(c, "x", ayah: N) and linkedPair(c, ("x", N), ...)."""
    found = {
        m.group(1): int(m.group(2))
        for m in re.finditer(r'"(\w+)"[^"\n]*?\bayah:\s*(\d+)', line)
    }
    found.update(
        {
            m.group(1): int(m.group(2))
            for m in re.finditer(r'\(\s*"(\w+)"\s*,\s*(\d+)\s*\)', line)
        }
    )
    return found


def parse_page_view(path: Path) -> list[dict]:
    """Suffix literals in render order: expands the calls made from `var body` into this file's funcs."""
    src = strip_line_comments(path.read_text(encoding="utf-8"))
    funcs: dict[str, tuple[int, int]] = {}
    for match in re.finditer(r"\bfunc\s+(\w+)\s*\(", src):
        try:
            funcs.setdefault(match.group(1), brace_block(src, match.end()))
        except ValueError:
            continue
    statics: dict[str, list[dict]] = {}
    for match in re.finditer(r"static\s+let\s+(\w+)\s*=\s*\[([^\]]*)\]", src):
        line, next_line = line_at(src, match.start())
        role = view_role_of(line, next_line)
        statics[match.group(1)] = [
            {"literal": lit, "viewRole": role, "viewAyah": None}
            for lit in re.findall(r'"([^"]+)"', match.group(2))
            if SUFFIX_LITERAL.match(lit)
        ]
    body_match = re.search(r"var\s+body\s*:\s*some\s+View\s*\{", src)
    if not body_match:
        return []

    def expand(block: tuple[int, int], depth: int) -> list[dict]:
        out: list[dict] = []
        text_start, text_end = block[0] + 1, block[1]
        for tok in TOKEN.finditer(src, text_start, text_end):
            if tok.group(1) is not None:
                literal = tok.group(1)
                if SUFFIX_LITERAL.match(literal):
                    line, next_line = line_at(src, tok.start())
                    out.append(
                        {
                            "literal": literal,
                            "viewRole": view_role_of(line, next_line),
                            "viewAyah": view_ayah_numbers(line).get(literal),
                        }
                    )
            elif tok.group(2) is not None:
                out.extend(statics.get(tok.group(2), []))
            elif tok.group(3) in funcs and depth < 8:
                out.extend(expand(funcs[tok.group(3)], depth + 1))
        return out

    return expand(brace_block(src, body_match.start()), 0)


# --------------------------------------------------------------------------- Quran text APIs


def http_json(url: str):
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "MuallimiSoniy-surah-index-verifier/1.0",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch_alquran(number: int) -> dict:
    data = http_json(f"https://api.alquran.cloud/v1/surah/{number}/quran-simple-clean")
    if data.get("code") != 200:
        raise ValueError(f"alquran.cloud code {data.get('code')}")
    surah = data["data"]
    return {
        "source": "alquran.cloud/quran-simple-clean",
        "name": surah.get("name"),
        "numberOfAyahs": surah.get("numberOfAyahs"),
        "ayahs": {int(a["numberInSurah"]): a["text"] for a in surah["ayahs"]},
    }


def fetch_qurancom(number: int) -> dict:
    ayahs: dict[int, str] = {}
    page, total = 1, None
    for _ in range(10):  # hard cap on pagination
        data = http_json(
            f"https://api.quran.com/api/v4/verses/by_chapter/{number}"
            f"?fields=text_imlaei_simple&per_page=300&page={page}"
        )
        for verse in data.get("verses", []):
            ayahs[int(verse["verse_number"])] = verse["text_imlaei_simple"]
        pagination = data.get("pagination") or {}
        total = pagination.get("total_records", total)
        if not pagination.get("next_page"):
            break
        page = pagination["next_page"]
    return {
        "source": "api.quran.com/v4 text_imlaei_simple",
        "name": None,
        "numberOfAyahs": total,
        "ayahs": ayahs,
    }


def get_surah_text(
    number: int, source: str, cache_dir: Path, refresh: bool
) -> tuple[dict | None, str]:
    """Returns (surah dict | None, note). Tries the primary source, then the fallback; caches answers."""
    order = [("alquran", fetch_alquran), ("qurancom", fetch_qurancom)]
    if source == "qurancom":
        order.reverse()
    errors = []
    for name, fetch in order:
        cache = cache_dir / f"{name}-{number}.json"
        if cache.exists() and not refresh:
            try:
                cached = load_json(cache)
                cached["ayahs"] = {int(k): v for k, v in cached["ayahs"].items()}
                return cached, f"{name} (cache)"
            except (OSError, ValueError, KeyError) as exc:
                errors.append(f"{name} cache unreadable: {exc}")
        try:
            result = fetch(number)
            cache_dir.mkdir(parents=True, exist_ok=True)
            cache.write_text(
                json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8"
            )
            return result, name
        except (
            urllib.error.URLError,
            TimeoutError,
            OSError,
            ValueError,
            KeyError,
        ) as exc:
            errors.append(f"{name}: {exc!r}")
    return None, "; ".join(errors)


# --------------------------------------------------------------------------- local audio (optional)


def afinfo_duration(path: Path) -> float | None:
    try:
        result = subprocess.run(
            ["afinfo", str(path)], capture_output=True, text=True, timeout=15
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    match = re.search(r"estimated duration:\s*([\d.]+)\s*sec", result.stdout)
    return float(match.group(1)) if match else None


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


# --------------------------------------------------------------------------- names + bundle

# Names hold only the primary form: no "(alternates)", verse ranges or the research table's marks.
NAME_FORBIDDEN = re.compile("[()\\[\\]0-9†‡]")
# Uzbek Latin writes oʻ/gʻ with U+02BB and the tutuq belgisi with U+02BC, never these quotes.
UZ_LATN_BAD_QUOTES = re.compile("['`‘’]")
# Cyrillic names must not mix in Latin letters or any apostrophe (Uzbek Cyrillic uses ъ).
CYRILLIC_BAD = re.compile("[A-Za-z'`‘’ʻʼ]")


def check_names(raw, report: Report) -> dict[int, dict[str, str]]:
    """Validates surah-names.json; returns {surah number: {locale: name}} for complete entries."""
    if not isinstance(raw, dict):
        report.err(f"{NAMES_JSON.name} must be an object keyed by surah number")
        return {}
    errors_before = report.errors
    numbers = [spec["number"] for spec in SECTIONS]
    unknown = sorted(set(raw) - {str(n) for n in numbers})
    if unknown:
        report.err(f"{NAMES_JSON.name}: keys that are not book surahs: {unknown}")
    names: dict[int, dict[str, str]] = {}
    for number in numbers:
        entry = raw.get(str(number))
        if not isinstance(entry, dict):
            report.err(f"{NAMES_JSON.name}: no names for surah {number}")
            continue
        extra = sorted(set(entry) - set(NAME_LOCALES))
        if extra:
            report.err(f"surah {number}: unknown locale keys {extra}")
        clean = {}
        for locale in NAME_LOCALES:
            value = entry.get(locale)
            if not isinstance(value, str) or not value.strip():
                report.err(f"surah {number}: missing or empty '{locale}' name")
                continue
            if value != value.strip() or NAME_FORBIDDEN.search(value):
                report.err(
                    f"surah {number} {locale}: {value!r} is not a bare primary form"
                )
            if locale == "uz-latn" and UZ_LATN_BAD_QUOTES.search(value):
                report.err(
                    f"surah {number} uz-latn: {value!r} uses a plain/curly quote; "
                    "use ʻ (U+02BB) or ʼ (U+02BC)"
                )
            if locale in ("uz-cyrl", "ru") and CYRILLIC_BAD.search(value):
                report.err(
                    f"surah {number} {locale}: {value!r} has Latin letters or an apostrophe"
                )
            clean[locale] = value
        if len(clean) == len(NAME_LOCALES):
            names[number] = clean
    if report.errors == errors_before:
        report.ok(
            f"{len(names)} surahs x {len(NAME_LOCALES)} locales, all non-empty primary forms; "
            "uz-latn apostrophes are ʻ/ʼ only; no Latin letters in uz-cyrl/ru"
        )
    return names


def read_content_version(report: Report) -> str | None:
    """contentVersion of the bundled content package (the index is built against it)."""
    try:
        version = load_json(CONTENT_MANIFEST).get("contentVersion")
    except (OSError, ValueError, AttributeError) as exc:
        report.err(f"cannot read {CONTENT_MANIFEST.name}: {exc}")
        return None
    if not isinstance(version, str) or not version:
        report.err(f"{CONTENT_MANIFEST.name} has no contentVersion")
        return None
    return version


def build_bundle(
    sections: list[dict], names: dict[int, dict[str, str]], content_version: str
) -> dict:
    """The wrapped file the app decodes (SurahIndexFile), keys in schema order."""
    return {
        "schemaVersion": BUNDLE_SCHEMA_VERSION,
        "contentVersion": content_version,
        "surahs": [
            {
                "number": s["number"],
                "key": s["key"],
                "arabicName": s["arabicName"],
                "name": names[s["number"]],
                "ayahCount": s["ayahCount"],
                "mushafAyahCount": s["mushafAyahCount"],
                "isPartial": s["isPartial"],
                "pages": s["pages"],
                "items": s["items"],
            }
            for s in sections
        ],
    }


def shown(path: Path) -> str:
    """Repo-relative path for the report when the file is inside the repo."""
    try:
        return str(path.resolve().relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


# --------------------------------------------------------------------------- main build


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    network = parser.add_mutually_exclusive_group()
    network.add_argument(
        "--offline",
        dest="online",
        action="store_false",
        help="(default) never touch the network; the canonical text check is skipped",
    )
    network.add_argument(
        "--online",
        dest="online",
        action="store_true",
        help="run the canonical text check: answers in .cache/ first, then the API",
    )
    parser.set_defaults(online=False)
    parser.add_argument(
        "--source",
        choices=["alquran", "qurancom"],
        help="API asked first by --online (default: alquran)",
    )
    parser.add_argument(
        "--refresh", action="store_true", help="with --online: ignore .cache/"
    )
    parser.add_argument(
        "--web-public",
        type=Path,
        default=None,
        help="web repo public/ dir; checks the mp3s (sha256, duration). Skipped if unset",
    )
    parser.add_argument(
        "--bundle-out",
        type=Path,
        default=None,
        help="write the app bundle JSON here (only when the report has no errors)",
    )
    args = parser.parse_args()
    if (args.refresh or args.source) and not args.online:
        parser.error("--refresh and --source need --online")

    report = Report()
    report.raw("Muallimi Soniy - surah index build + verification (pages 36-47)")

    try:
        book = load_json(BOOK_JSON)
        manifest = load_json(AUDIO_MANIFEST)
    except (OSError, ValueError) as exc:
        print(f"FATAL: cannot read inputs: {exc}", file=sys.stderr)
        return 1

    # ---- 1. flatten + global indices -------------------------------------------------
    report.h("1. Global page order (mirror of ContentStore.rebuild)")
    flat = flatten(book)
    report.info(f"{len(flat)} global pages")
    page_globals: dict[int, list[int]] = defaultdict(list)
    for entry in flat:
        page_globals[entry["pageNumber"]].append(entry["globalIndex"])
    for page_number in QURAN_PAGES:
        indices = page_globals.get(page_number, [])
        if len(indices) != 1:
            report.err(
                f"page {page_number} appears {len(indices)}x in the flattened book: {indices}"
            )
    lesson_pages = book["pageMap"].get(QURAN_LESSON, [])
    if lesson_pages == QURAN_PAGES:
        span = [page_globals[p][0] for p in QURAN_PAGES]
        report.ok(
            f"{QURAN_LESSON} = book pages {QURAN_PAGES[0]}-{QURAN_PAGES[-1]} = global indices {span[0]}-{span[-1]} "
            f"(each page exactly once)"
        )
    else:
        report.err(f"pageMap[{QURAN_LESSON}] = {lesson_pages}, expected {QURAN_PAGES}")
    global_of = {p: page_globals[p][0] for p in QURAN_PAGES if page_globals.get(p)}

    # ---- 2. assign every element of pages 36-47 to exactly one section ----------------
    report.h("2. Coverage: every element of pages 36-47 assigned exactly once")
    compiled = [[(page, re.compile(rx)) for page, rx in s["parts"]] for s in SECTIONS]
    reading_order = sorted(QURAN_PAGES, key=lambda p: global_of.get(p, 10**6))
    all_ids = Counter(e["id"] for elements in book["pages"].values() for e in elements)
    assigned: list[tuple[int, dict, int]] = []  # (section index, element, pageNumber)
    total_elements = 0
    for page_number in reading_order:
        for element in book["pages"].get(str(page_number), []):
            total_elements += 1
            hits = [
                i
                for i, parts in enumerate(compiled)
                if any(
                    page == page_number and rx.match(element["id"])
                    for page, rx in parts
                )
            ]
            if len(hits) == 1:
                assigned.append((hits[0], element, page_number))
            elif not hits:
                report.err(f"unassigned element {element['id']} (page {page_number})")
            else:
                report.err(
                    f"{element['id']} matches several sections: {[SECTIONS[i]['key'] for i in hits]}"
                )
    duplicates = [i for i, n in all_ids.items() if n > 1]
    if duplicates:
        report.err(f"duplicate element ids in book.json: {duplicates}")
    if len(assigned) == total_elements and not duplicates:
        report.ok(
            f"{total_elements} elements, {len(assigned)} assigned, 0 unassigned, 0 duplicate ids (whole book)"
        )

    # Sections must be contiguous and in book order == ascending Mushaf order.
    sequence = [i for i, _, _ in assigned]
    runs = [k for k, _ in itertools.groupby(sequence)]
    if runs == list(range(len(SECTIONS))):
        report.ok("sections are contiguous, appear once each, in spec order")
    else:
        report.err(f"section order/contiguity broken: run sequence {runs}")
    numbers = [s["number"] for s in SECTIONS]
    if numbers == sorted(numbers) and len(set(numbers)) == len(numbers):
        report.ok(
            "book order == Mushaf order (strictly ascending surah numbers): "
            + " ".join(str(n) for n in numbers)
        )
    else:
        report.err(f"book order is not ascending Mushaf order: {numbers}")

    # ---- 3. build items ----------------------------------------------------------------
    shared_groups: dict[tuple, list[str]] = defaultdict(list)
    for _, element, _ in assigned:
        if has_audio(element):
            shared_groups[
                (element["audioUrl"], element["start"], element["end"])
            ].append(element["id"])
    # The bundle names one partner per item, so only pairs fit (bigger groups: section 6 error).
    shared_with = {}
    for ids in shared_groups.values():
        if len(ids) == 2:
            shared_with[ids[0]], shared_with[ids[1]] = ids[1], ids[0]

    sections_out = []
    element_by_id = {}
    for index, spec in enumerate(SECTIONS):
        items = []
        for sec_index, element, page_number in assigned:
            if sec_index != index:
                continue
            element_by_id[element["id"]] = element
            role, ayah = classify(element["id"], spec["number"])
            item = {
                "elementId": element["id"],
                "pageNumber": page_number,
                "globalIndex": global_of.get(page_number),
                "role": role,
                "ayah": ayah,
                "hasAudio": has_audio(element),
            }
            if element["id"] in shared_with:
                item["sharedAudioWith"] = shared_with[element["id"]]
            if (
                spec["number"] == 1
                and role == "ayah"
                and BASMALA_SUFFIX.search(id_suffix(element["id"]))
            ):
                item["basmalaAsAyah"] = True
            if (spec["number"], ayah) in SAJDA_AYAT and role == "ayah":
                item["sajda"] = True
            items.append(item)
        ayah_items = [it for it in items if it["role"] == "ayah"]
        pages = sorted(
            {it["pageNumber"] for it in items}, key=lambda p: global_of.get(p, 0)
        )
        sections_out.append(
            {
                "number": spec["number"],
                "key": spec["key"],
                "arabicName": spec["arabicName"],
                "ayahCount": len(ayah_items),
                "mushafAyahCount": spec["mushaf"],
                "isPartial": "bookRange" in spec,
                "pages": pages,
                "items": items,
            }
        )

    # ---- 4. ayah numbering + roles ------------------------------------------------------
    report.h("3. Ayah numbering (contiguous 1..N) and Mushaf counts")
    for spec, section in zip(SECTIONS, sections_out):
        expected_mushaf = EXPECTED_MUSHAF_COUNTS.get(spec["number"])
        if expected_mushaf is not None and expected_mushaf != spec["mushaf"]:
            report.err(
                f"{spec['key']}: spec mushaf count {spec['mushaf']} != cross-check table {expected_mushaf}"
            )
        low, high = spec.get("bookRange", (1, spec["mushaf"]))
        got = [it["ayah"] for it in section["items"] if it["role"] == "ayah"]
        if got == list(range(low, high + 1)):
            suffix = (
                f" (partial: ayat {low}-{high} of {spec['mushaf']})"
                if "bookRange" in spec
                else ""
            )
            report.ok(
                f"{spec['number']:>3} {spec['key']:<9} ayat {low}..{high} contiguous, count {len(got)}{suffix}"
            )
        else:
            report.err(
                f"{spec['key']}: ayah sequence {got} != {list(range(low, high + 1))}"
            )
        unknown = [
            it["elementId"] for it in section["items"] if it["role"] == "unknown"
        ]
        if unknown:
            report.err(f"{spec['key']}: unclassifiable elements {unknown}")

    report.h("4. Roles (taawwudh / title / basmala placement)")
    role_counts = Counter(it["role"] for s in sections_out for it in s["items"])
    report.info(
        "role totals: " + ", ".join(f"{k}={v}" for k, v in sorted(role_counts.items()))
    )
    errors_before_roles = report.errors
    for spec, section in zip(SECTIONS, sections_out):
        items = section["items"]
        roles = [it["role"] for it in items]
        basmala = [
            i
            for i, it in enumerate(items)
            if it["role"] == "bismillah" or it.get("basmalaAsAyah")
        ]
        first_ayah = next(
            (
                i
                for i, it in enumerate(items)
                if it["role"] == "ayah" and not it.get("basmalaAsAyah")
            ),
            None,
        )
        if len(basmala) != 1:
            report.err(f"{spec['key']}: {len(basmala)} basmala items")
        elif first_ayah is not None and basmala[0] > first_ayah:
            report.err(f"{spec['key']}: basmala after the first ayah")
        if "title" in roles and roles.index("title") != 0:
            report.err(f"{spec['key']}: title is not the first item")
        if "taawwudh" in roles and (
            spec["number"] != 1 or roles.index("taawwudh") != 0
        ):
            report.err(f"{spec['key']}: unexpected taawwudh position")
    if report.errors == errors_before_roles:
        report.ok(
            "each section has exactly one basmala, before its first ayah; titles/taawwudh lead their section"
        )
    report.info(
        "Fatiha basmala p36_fa_bismi -> role=ayah, ayah=1, basmalaAsAyah=true (Hafs/Kufan count; "
        "print shows (1) on it, view passes ayah: 1, label 'Fotiha 1-oyat')"
    )
    titles = [
        (it["elementId"], it["hasAudio"])
        for s in sections_out
        for it in s["items"]
        if it["role"] == "title"
    ]
    report.info(
        "title elements (hasAudio): " + ", ".join(f"{e}={h}" for e, h in titles)
    )
    no_audio = [
        it["elementId"] for s in sections_out for it in s["items"] if not it["hasAudio"]
    ]
    report.info(f"items without audio: {len(no_audio)} -> {no_audio}")

    # ---- 5. cross-page splits -----------------------------------------------------------
    report.h("5. Cross-page splits")
    for section in sections_out:
        if len(section["pages"]) < 2:
            continue
        parts = []
        for page_number in section["pages"]:
            page_items = [
                it for it in section["items"] if it["pageNumber"] == page_number
            ]
            ayat = [it["ayah"] for it in page_items if it["role"] == "ayah"]
            other = [it["role"] for it in page_items if it["role"] != "ayah"]
            desc = "+".join(other)
            if ayat:
                desc = (desc + " + " if desc else "") + f"ayat {ayat[0]}-{ayat[-1]}"
            parts.append(f"p{page_number}(g{global_of[page_number]}) [{desc}]")
        report.info(f"{section['number']:>3} {section['key']:<8} " + " -> ".join(parts))

    # ---- 6. audio -------------------------------------------------------------------------
    report.h("6. Audio: directory per surah, file naming, shared clips, manifest")
    dir_mismatch = 0
    naming = []
    for spec, section in zip(SECTIONS, sections_out):
        for it in section["items"]:
            element = element_by_id[it["elementId"]]
            url = element.get("audioUrl")
            if not url:
                continue
            parts = url.split("/")
            directory = (
                parts[2]
                if len(parts) >= 4 and parts[0] == "audio" and parts[1] == "edit"
                else None
            )
            if directory != spec["audioDir"]:
                dir_mismatch += 1
                report.err(
                    f"{it['elementId']} audio dir {directory!r} != {spec['audioDir']!r} ({url})"
                )
            if Path(url).stem != it["elementId"]:
                naming.append(f"{it['elementId']}->{Path(url).name}")
            file_ayahs = audio_file_ayahs(url)
            if it["role"] == "ayah" and file_ayahs and it["ayah"] not in file_ayahs:
                report.err(
                    f"{it['elementId']} ayah {it['ayah']} but audio file {Path(url).name} says {file_ayahs}"
                )
            if element.get("start", 0) != 0:
                report.warn(
                    f"{it['elementId']} segment starts at {element['start']} (not a whole-file chunk)"
                )
    if dir_mismatch == 0:
        report.ok(
            "every audio item lives in its own surah directory (fatiha+baqara+taawwudh share 56_fotiha_baqara)"
        )
    report.info(
        f"file name != element id ({len(naming)}; cosmetic): " + ", ".join(naming)
    )
    # The app merges consecutive items with the same clip into one unit, so a shared
    # clip must sit on neighbouring items of one surah.
    position = {
        it["elementId"]: (s_index, i_index)
        for s_index, s in enumerate(sections_out)
        for i_index, it in enumerate(s["items"])
    }
    for (url, start, end), ids in shared_groups.items():
        if len(ids) > 2:
            report.err(
                f"clip {Path(url).name} is used by {len(ids)} elements {ids}; "
                "sharedAudioWith can name only one partner"
            )
        elif len(ids) == 2:
            (s1, i1), (s2, i2) = position[ids[0]], position[ids[1]]
            if s1 != s2 or abs(i1 - i2) != 1:
                report.err(
                    f"shared clip {Path(url).name} is on non-adjacent items {ids}"
                )
            report.warn(
                f"SHARED CLIP {Path(url).name} [{start}-{end}s] is used by {ids} -> "
                f"cannot play one of these ayat alone; sequential players must play it once"
            )
    pack_files = {
        f["path"]: f
        for p in manifest.get("packs", [])
        if p.get("lessonId") == QURAN_LESSON
        for f in p.get("files", [])
    }
    used_urls = {
        element_by_id[it["elementId"]]["audioUrl"]
        for s in sections_out
        for it in s["items"]
        if element_by_id[it["elementId"]].get("audioUrl")
    }
    missing = sorted(used_urls - set(pack_files))
    extra = sorted(set(pack_files) - used_urls)
    if missing:
        report.err(
            f"audioUrls missing from the {QURAN_LESSON} manifest pack: {missing}"
        )
    else:
        report.ok(
            f"all {len(used_urls)} distinct audioUrls are in the {QURAN_LESSON} pack "
            f"({len(pack_files)} files; extra/unreferenced in pack: {len(extra)})"
        )
    if extra:
        report.warn(f"pack files not referenced by pages 36-47: {extra}")

    # ---- 7. independent signals: uzbek label + Swift page views ---------------------------
    report.h(
        "7. Cross-check vs uzbek labels and the Swift page views (render order, role, ayah args)"
    )
    label_mismatch = 0
    for section in sections_out:
        for it in section["items"]:
            number = label_ayah(element_by_id[it["elementId"]].get("uzbek", ""))
            if number is not None and number != it["ayah"]:
                label_mismatch += 1
                report.err(
                    f"{it['elementId']}: label says {number}-oyat, index says {it['ayah']}"
                )
            if it["role"] == "ayah" and number is None:
                report.info(f"{it['elementId']}: label has no 'N-oyat'")
    if label_mismatch == 0:
        report.ok("every 'N-oyat' in the uzbek labels agrees with the index")

    try:
        dispatcher_src = DISPATCHER.read_text(encoding="utf-8")
        routes = {
            int(a): int(b)
            for a, b in re.findall(
                r"case\s+(\d+)\s*:\s*Page(\d+)View\(", dispatcher_src
            )
        }
        wrong = [p for p in QURAN_PAGES if routes.get(p) != p]
        if wrong:
            report.err(
                f"PageDispatcher does not route pages {wrong} to their bespoke views"
            )
        else:
            report.ok("PageDispatcher routes 36..47 -> Page36View..Page47View")
    except OSError as exc:
        report.warn(f"cannot read PageDispatcher: {exc}")

    index_items = {it["elementId"]: it for s in sections_out for it in s["items"]}
    view_ok = True
    for page_number in QURAN_PAGES:
        path = PAGES_DIR / f"Page{page_number}View.swift"
        try:
            literals = parse_page_view(path)
        except (OSError, ValueError) as exc:
            report.warn(f"p{page_number}: cannot parse {path.name}: {exc}")
            view_ok = False
            continue
        elements = book["pages"].get(str(page_number), [])
        rendered = []
        for lit in literals:
            matches = [
                e["id"] for e in elements if e["id"].endswith("_" + lit["literal"])
            ]
            if len(matches) != 1:
                view_ok = False
                report.err(
                    f"p{page_number}: view suffix '{lit['literal']}' matches {len(matches)} elements {matches}"
                )
            if matches:
                rendered.append((matches[0], lit))
        json_order = [e["id"] for e in elements]
        view_order = [eid for eid, _ in rendered]
        if view_order != json_order:
            view_ok = False
            missing_in_view = [e for e in json_order if e not in view_order]
            report.err(
                f"p{page_number}: render order != JSON order; not rendered: {missing_in_view}; "
                f"view={view_order}"
            )
        for eid, lit in rendered:
            item = index_items.get(eid)
            if not item:
                continue
            expected_view_roles = {
                "title": {"title"},
                "bismillah": {"bismillah", "unnumbered"},
                "taawwudh": {"unnumbered"},
                "ayah": {"ayah"},
            }[item["role"]]
            if lit["viewRole"] not in expected_view_roles:
                view_ok = False
                report.err(
                    f"{eid}: view renders it as '{lit['viewRole']}', index role '{item['role']}'"
                )
            if lit["viewAyah"] is not None and lit["viewAyah"] != item["ayah"]:
                view_ok = False
                report.err(
                    f"{eid}: view passes ayah {lit['viewAyah']}, index says {item['ayah']}"
                )
    if view_ok:
        report.ok(
            "all 12 views render every element exactly once, in JSON order; view roles and explicit "
            "ayah: N args (pages 36, 45-47) agree with the index"
        )

    # ---- 8. text-level check vs a canonical Quran text ------------------------------------
    report.h("8. Text-level 1:1 check vs canonical text (normalised, difflib ratio)")
    text_summary = {}
    basmala_checked, basmala_bad = 0, 0
    for section in sections_out:
        for it in section["items"]:
            arabic = element_by_id[it["elementId"]].get("arabic", "")
            if it["role"] == "bismillah" or it.get("basmalaAsAyah"):
                basmala_checked += 1
                r = ratio(norm(arabic), BASMALA_N)
                if r < 1.0:
                    basmala_bad += 1
                    report.warn(f"{it['elementId']} basmala text ratio {r:.3f}")
            elif it["role"] == "taawwudh":
                r = ratio(norm(arabic), TAAWWUDH_N)
                (report.ok if r == 1.0 else report.warn)(
                    f"{it['elementId']} isti'adha text ratio {r:.3f}"
                )
            elif it["role"] == "title":
                name = norm(
                    next(s["arabicName"] for s in sections_out if it in s["items"])
                )
                if name not in norm(arabic):
                    report.err(
                        f"{it['elementId']} title '{arabic}' does not contain the surah name"
                    )
    if basmala_bad == 0:
        report.ok(
            f"all {basmala_checked} basmala texts (Fatiha ayah 1 + {basmala_checked - 1} surah-opening "
            "bismillahs) == canonical basmala, ratio 1.000"
        )

    if not args.online:
        report.info(
            "canonical text check skipped (offline is the default; --online runs it, "
            "reading .cache/ first)"
        )
    else:
        source = args.source or "alquran"
        consecutive_failures = 0
        stripped_prefix = []
        flagged = 0
        for section in sections_out:
            number = section["number"]
            if consecutive_failures >= MAX_NETWORK_FAILURES:
                text_summary[number] = "skipped (network down)"
                continue
            surah, note = get_surah_text(number, source, CACHE_DIR, args.refresh)
            if surah is None:
                consecutive_failures += 1
                text_summary[number] = f"skipped ({note})"
                report.warn(f"{number}: no canonical text ({note})")
                continue
            consecutive_failures = 0
            api = {k: norm(v) for k, v in surah["ayahs"].items()}
            if (
                number != 1
                and api.get(1, "").startswith(BASMALA_N)
                and len(api[1]) > len(BASMALA_N)
            ):
                api[1] = api[1][len(BASMALA_N) :]
                stripped_prefix.append(number)
            if surah.get("numberOfAyahs") not in (None, section["mushafAyahCount"]):
                report.err(
                    f"{number}: API numberOfAyahs {surah['numberOfAyahs']} != {section['mushafAyahCount']}"
                )
            if surah.get("name") and norm(section["arabicName"]) not in norm(
                surah["name"]
            ):
                report.warn(
                    f"{number}: API name {surah['name']} vs {section['arabicName']}"
                )
            ratios = []
            for it in section["items"]:
                if it["role"] != "ayah":
                    continue
                book_text = norm(element_by_id[it["elementId"]]["arabic"])
                k = it["ayah"]
                if k not in api:
                    report.err(f"{it['elementId']}: API has no ayah {k}")
                    continue
                r = ratio(book_text, api[k])
                ratios.append(r)
                best_k, best_r = max(
                    ((n, ratio(book_text, t)) for n, t in api.items()),
                    key=lambda x: x[1],
                )
                if r < TEXT_RATIO_MIN or (best_k != k and best_r > r + 0.05):
                    flagged += 1
                    merge_next = (
                        ratio(book_text, api[k] + api.get(k + 1, ""))
                        if k + 1 in api
                        else 0.0
                    )
                    merge_prev = (
                        ratio(book_text, api.get(k - 1, "") + api[k])
                        if k - 1 in api
                        else 0.0
                    )
                    # Quran text drift (split / merge / offset) is an error, not a warning.
                    report.err(
                        f"{it['elementId']} (ayah {k}) ratio {r:.3f}; best match ayah {best_k} ({best_r:.3f}); "
                        f"vs {k}+{k + 1}: {merge_next:.3f}; vs {k - 1}+{k}: {merge_prev:.3f}"
                    )
            if ratios:
                text_summary[number] = (
                    f"{len(ratios)} ayat, min {min(ratios):.3f}, mean {sum(ratios) / len(ratios):.3f} [{note}]"
                )
        for section in sections_out:
            report.info(
                f"{section['number']:>3} {section['key']:<9} {text_summary.get(section['number'], '-')}"
            )
        if stripped_prefix:
            report.info(
                f"API ayah 1 carried a basmala prefix for {len(stripped_prefix)} surahs -> stripped before "
                f"comparing: {stripped_prefix}"
            )
        if flagged == 0 and all(
            not v.startswith("skipped") for v in text_summary.values()
        ):
            report.ok(
                f"every ayah item matches the canonical ayah with the same number (ratio >= {TEXT_RATIO_MIN}); "
                "no split / merge / offset detected"
            )

    # ---- 9. local mp3s (sha256 == manifest, duration vs element.end) ----------------------
    report.h(
        "9. Local mp3 check (web repo public/audio: sha256 vs manifest, duration vs element.end)"
    )
    web_public = args.web_public
    if web_public is None:
        report.info("skipped (pass --web-public <web repo>/public to check the mp3s)")
    elif not web_public.is_dir():
        report.err(f"--web-public {web_public} is not a directory")
    else:
        durations: dict[str, float | None] = {}
        sha_bad, sha_ok, absent = [], 0, []
        for url in sorted(used_urls):
            path = web_public / url
            if not path.exists():
                absent.append(url)
                continue
            expected_sha = pack_files.get(url, {}).get("sha256")
            if expected_sha and sha256_of(path) != expected_sha:
                sha_bad.append(url)
            else:
                sha_ok += 1
            durations[url] = afinfo_duration(path)
        report.info(
            f"sha256 matches manifest: {sha_ok}/{len(used_urls)}; mismatches: {sha_bad or 'none'}; "
            f"absent locally: {absent or 'none'}"
        )
        diffs = []
        for section in sections_out:
            for it in section["items"]:
                element = element_by_id[it["elementId"]]
                duration = durations.get(element.get("audioUrl") or "")
                if duration is None:
                    continue
                diff = element["end"] - duration
                diffs.append(abs(diff))
                if diff < -DURATION_TOLERANCE:
                    report.warn(
                        f"{it['elementId']}: end {element['end']}s < file {duration:.2f}s "
                        f"-> last {-diff:.2f}s of the clip is never played"
                    )
                elif diff > DURATION_TOLERANCE:
                    report.info(
                        f"{it['elementId']}: end {element['end']}s > file {duration:.2f}s (EOF ends it; harmless)"
                    )
        if diffs:
            report.info(
                f"|end - duration| over {len(diffs)} audio items: max {max(diffs):.3f}s, "
                f"mean {sum(diffs) / len(diffs):.3f}s"
            )
        # clips on disk for these surahs that book.json does not reference (e.g. solo takes of merged ayat)
        for spec in SECTIONS:
            directory = web_public / "audio/edit" / spec["audioDir"]
            if not directory.is_dir():
                continue
            unreferenced = sorted(
                f"audio/edit/{spec['audioDir']}/{p.name}"
                for p in directory.glob("*.mp3")
                if f"audio/edit/{spec['audioDir']}/{p.name}" not in used_urls
            )
            for url in unreferenced:
                if spec["key"] == "baqara":  # shared dir with fatiha: report once
                    break
                dur = afinfo_duration(web_public / url)
                report.info(
                    f"unreferenced local clip (not in book.json / not in pack): {url} "
                    f"({dur:.2f}s)"
                    if dur
                    else f"unreferenced local clip: {url}"
                )

    # ---- 10. surah names + bundle metadata ------------------------------------------------
    report.h("10. Surah names (surah-names.json) + bundle metadata")
    names: dict[int, dict[str, str]] = {}
    try:
        names = check_names(load_json(NAMES_JSON), report)
    except (OSError, ValueError) as exc:
        report.err(f"cannot read {shown(NAMES_JSON)}: {exc}")
    content_version = read_content_version(report)
    if content_version:
        report.ok(
            f"contentVersion {content_version} (from {CONTENT_MANIFEST.name}), "
            f"schemaVersion {BUNDLE_SCHEMA_VERSION}"
        )
    bundle_text = None
    if content_version and len(names) == len(SECTIONS):
        bundle = build_bundle(sections_out, names, content_version)
        bundle_text = json.dumps(bundle, ensure_ascii=False, indent=1) + "\n"
        if json.loads(bundle_text) == bundle:
            report.ok(f"bundle JSON round-trips ({len(bundle_text.encode())} bytes)")
        else:
            report.err("bundle JSON does not round-trip")
    else:
        report.info("bundle not built (names or contentVersion missing, see above)")

    # ---- report ------------------------------------------------------------------------------
    report.h("Compact table")
    report.raw(
        "| # | key | pages | first elementId | last elementId | ayahCount | cross-page? |"
    )
    report.raw("|---|---|---|---|---|---|---|")
    for section in sections_out:
        pages = section["pages"]
        page_text = f"{pages[0]}" if len(pages) == 1 else f"{pages[0]}-{pages[-1]}"
        count = f"{section['ayahCount']}" + (
            f" (of {section['mushafAyahCount']})" if section["isPartial"] else ""
        )
        report.raw(
            f"| {section['number']} | {section['key']} | {page_text} | {section['items'][0]['elementId']} | "
            f"{section['items'][-1]['elementId']} | {count} | {'yes' if len(pages) > 1 else 'no'} |"
        )

    report.h("Summary")
    # Write before the counts line so a failed write is counted as an error too.
    if args.bundle_out is None:
        written = "bundle not written (pass --bundle-out PATH to write it)"
    elif report.errors or bundle_text is None:
        written = (
            f"bundle NOT written to {shown(args.bundle_out)} (fix the errors above)"
        )
    else:
        try:
            args.bundle_out.parent.mkdir(parents=True, exist_ok=True)
            args.bundle_out.write_text(bundle_text, encoding="utf-8")
            written = f"wrote {shown(args.bundle_out)}"
        except OSError as exc:
            report.err(f"cannot write {shown(args.bundle_out)}: {exc}")
            written = "bundle NOT written"
    report.raw(
        f"  sections={len(sections_out)} items={sum(len(s['items']) for s in sections_out)} "
        f"ayahItems={sum(s['ayahCount'] for s in sections_out)} errors={report.errors} warnings={report.warnings}"
    )
    report.raw(f"  {written}")
    sys.stdout.write(report.text())
    return 0 if report.errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
