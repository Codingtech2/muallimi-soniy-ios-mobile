#!/usr/bin/env python3
"""
build_translations.py - build MuallimiSoniy/Resources/translations.json, the
translation of the meanings for every ayah the book prints (the ayat listed in
Resources/surah-index.json: al-Fatiha, al-Baqara 1-5 and surahs 91-114).

Standard library only. Three sources, copied word for word - their terms
forbid changing, adding to or leaving out any of the text:
  uz  QuranEnc.com uzbek_sadiq   - Muhammad Sadiq Muhammad Yusuf (Cyrillic script)
  ru  QuranEnc.com russian_rwwad - Rowwad Translation Center
  en  ClearQuran.com, Edition Allah - Talal Itani (CC BY-ND 4.0)

Raw downloads are kept in .cache/ next to this script (gitignored).

Usage (run from the repo root):
  python3 tools/translations/build_translations.py              # check only (.cache/ first)
  python3 tools/translations/build_translations.py --bundle-out MuallimiSoniy/Resources/translations.json
  python3 tools/translations/build_translations.py --refresh    # refetch everything, ignore .cache/

The bundle is written only when the check finds no errors.
Exit code: 0 when there are no errors, 1 otherwise.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import io
import json
import re
import sys
import urllib.error
import urllib.request
import zipfile
from pathlib import Path

TOOL_DIR = Path(__file__).resolve().parent  # tools/translations
REPO_ROOT = Path(__file__).resolve().parents[2]
SURAH_INDEX = REPO_ROOT / "MuallimiSoniy/Resources/surah-index.json"
CACHE_DIR = TOOL_DIR / ".cache"

# Bundle format read by the app (TranslationsFile). Bump both sides together.
BUNDLE_SCHEMA_VERSION = 1
HTTP_TIMEOUT = 30  # seconds per request

QURANENC_API = "https://quranenc.com/api/v1/translation/sura/{key}/{sura}"
# The list API skips uzbek_sadiq and russian_rwwad, so their version and
# release date are read from the translations index page instead.
QURANENC_INDEX = "https://quranenc.com/en/home"
QURANENC_BROWSE = "https://quranenc.com/en/browse/{key}"
QURANENC_TERMS = (
    "QuranEnc.com terms: no modification, addition or deletion; credit the "
    "publisher and QuranEnc.com; state the version number."
)

CLEARQURAN_ZIP = (
    "https://www.clearquran.com/downloads/"
    "quran-in-english-clearquran-verse-by-verse-txt-edition-allah.zip"
)
CLEARQURAN_CREDIT = "Translation by Talal Itani, ClearQuran.com"
CLEARQURAN_LICENSE = "CC BY-ND 4.0 (clearquran.com/download: free to use, including commercial use, unmodified)"

QURANENC_SOURCES = [
    dict(
        id="uz",
        script="uz-cyrl",
        key="uzbek_sadiq",
        title="Uzbek Translation - Muhammad Sadiq",
        translator="Muhammad Sadiq Muhammad Yusuf",
    ),
    dict(
        id="ru",
        script="ru",
        key="russian_rwwad",
        title="Russian Translation - Rowwad Translation Center",
        translator="Rowwad Translation Center",
    ),
]

VERSION_RE = re.compile(r"(\d{2})/(\d{2})/(\d{4})\s*-\s*V(\d+(?:\.\d+)+)")


class Report:
    """Collects ERROR / WARN / INFO lines; prints them as they come."""

    def __init__(self) -> None:
        self.errors = 0

    def error(self, message: str) -> None:
        self.errors += 1
        print(f"ERROR {message}")

    def warn(self, message: str) -> None:
        print(f"WARN  {message}")

    def info(self, message: str) -> None:
        print(f"INFO  {message}")


def fetch(url: str, cache_name: str, refresh: bool) -> bytes:
    """Returns the body of `url`, from .cache/ unless `refresh` is set."""
    cached = CACHE_DIR / cache_name
    if cached.exists() and not refresh:
        return cached.read_bytes()
    request = urllib.request.Request(
        url, headers={"User-Agent": "MuallimiSoniy-tools/1.0"}
    )
    with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT) as response:
        body = response.read()
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cached.write_bytes(body)
    return body


def wanted_ayat(report: Report) -> list[tuple[int, int]]:
    """Every (surah, ayah) the book prints, in book order, from surah-index.json."""
    index = json.loads(SURAH_INDEX.read_text(encoding="utf-8"))
    ayat: list[tuple[int, int]] = []
    for surah in index["surahs"]:
        for item in surah["items"]:
            if item["role"] == "ayah" and item.get("ayah"):
                ayat.append((surah["number"], item["ayah"]))
    if len(set(ayat)) != len(ayat):
        report.error("surah-index.json lists the same ayah twice")
    report.info(
        f"surah-index.json: {len(ayat)} ayat in {len({s for s, _ in ayat})} surahs"
    )
    return ayat


def quranenc_version(key: str, index_html: str, report: Report) -> tuple[str, str]:
    """(version, ISO release date) printed next to `key` on the index page."""
    anchor = index_html.find(QURANENC_BROWSE.format(key=key))
    if anchor < 0:
        report.error(f"{key}: not found on {QURANENC_INDEX}")
        return "", ""
    # The version line sits just before the translation's browse link.
    window = html.unescape(
        re.sub(r"<[^>]+>", " ", index_html[max(0, anchor - 4000) : anchor])
    )
    matches = VERSION_RE.findall(window)
    if not matches:
        report.error(f"{key}: no 'dd/mm/yyyy - Vx.y.z' line before its browse link")
        return "", ""
    day, month, year, version = matches[-1]
    return version, f"{year}-{month}-{day}"


def quranenc_edition(
    source: dict,
    ayat: list[tuple[int, int]],
    index_html: str,
    refresh: bool,
    report: Report,
) -> dict:
    key = source["key"]
    version, released = quranenc_version(key, index_html, report)
    by_ayah: dict[str, dict] = {}
    for sura in sorted({s for s, _ in ayat}):
        try:
            body = fetch(
                QURANENC_API.format(key=key, sura=sura),
                f"{key}_{sura:03d}.json",
                refresh,
            )
            rows = json.loads(body)["result"]
        except (urllib.error.URLError, OSError, ValueError, KeyError) as error:
            report.error(f"{key} surah {sura}: {error}")
            continue
        for row in rows:
            entry = {"text": row["translation"].strip()}
            notes = (row.get("footnotes") or "").strip()
            if notes:
                entry["notes"] = notes
            by_ayah[f"{int(row['sura'])}:{int(row['aya'])}"] = entry
    ayahs = collect(key, ayat, by_ayah, report)
    report.info(
        f"{key}: v{version} ({released}), {len(ayahs)} ayat, "
        f"{sum('notes' in a for a in ayahs.values())} with footnotes"
    )
    return dict(
        id=source["id"],
        script=source["script"],
        title=source["title"],
        translator=source["translator"],
        source="QuranEnc.com",
        sourceKey=key,
        version=version,
        released=released,
        credit=f"{source['title']}, QuranEnc.com, v{version}",
        license=QURANENC_TERMS,
        url=QURANENC_BROWSE.format(key=key),
        ayahs=ayahs,
    )


def clearquran_edition(
    ayat: list[tuple[int, int]], refresh: bool, report: Report
) -> dict:
    try:
        body = fetch(CLEARQURAN_ZIP, "clearquran-edition-allah.zip", refresh)
    except (urllib.error.URLError, OSError) as error:
        report.error(f"ClearQuran download: {error}")
        body = b""
    by_ayah: dict[str, dict] = {}
    if body:
        with zipfile.ZipFile(io.BytesIO(body)) as archive:
            for name in archive.namelist():
                # Files are named SSS-AAA.txt; AAA 000 is a bismillah heading.
                match = re.fullmatch(r"(?:.*/)?(\d{3})-(\d{3})\.txt", name)
                if not match or int(match.group(2)) == 0:
                    continue
                text = archive.read(name).decode("utf-8").strip()
                by_ayah[f"{int(match.group(1))}:{int(match.group(2))}"] = {"text": text}
    ayahs = collect("clearquran", ayat, by_ayah, report)
    digest = hashlib.sha256(body).hexdigest()[:16] if body else ""
    report.info(f"clearquran: {len(ayahs)} ayat, zip sha256 {digest}")
    return dict(
        id="en",
        script="en",
        title="The Clear Quran (Edition Allah)",
        translator="Talal Itani",
        source="ClearQuran.com",
        credit=CLEARQURAN_CREDIT + " (CC BY-ND 4.0)",
        license=CLEARQURAN_LICENSE,
        url="https://www.clearquran.com",
        ayahs=ayahs,
    )


def collect(
    name: str, ayat: list[tuple[int, int]], by_ayah: dict[str, dict], report: Report
) -> dict[str, dict]:
    """Keeps only the book's ayat, in book order; reports any gap."""
    ayahs: dict[str, dict] = {}
    for sura, aya in ayat:
        key = f"{sura}:{aya}"
        entry = by_ayah.get(key)
        if not entry or not entry["text"]:
            report.error(f"{name}: missing text for {key}")
            continue
        ayahs[key] = entry
    return ayahs


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--bundle-out", type=Path, help="write the app bundle JSON here"
    )
    parser.add_argument(
        "--refresh", action="store_true", help="ignore .cache/ and refetch"
    )
    args = parser.parse_args()

    report = Report()
    ayat = wanted_ayat(report)
    try:
        index_html = fetch(QURANENC_INDEX, "quranenc-home.html", args.refresh).decode(
            "utf-8"
        )
    except (urllib.error.URLError, OSError) as error:
        report.error(f"QuranEnc index page: {error}")
        index_html = ""

    translations = [
        quranenc_edition(s, ayat, index_html, args.refresh, report)
        for s in QURANENC_SOURCES
    ]
    translations.append(clearquran_edition(ayat, args.refresh, report))

    if report.errors:
        print(f"\n{report.errors} error(s); nothing written.")
        return 1
    if args.bundle_out:
        bundle = dict(schemaVersion=BUNDLE_SCHEMA_VERSION, translations=translations)
        text = json.dumps(bundle, ensure_ascii=False, indent=1) + "\n"
        args.bundle_out.write_text(text, encoding="utf-8")
        report.info(f"wrote {args.bundle_out} ({len(text.encode('utf-8')) // 1024} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
