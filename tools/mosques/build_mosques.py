#!/usr/bin/env python3
"""Builds the mosques dataset for the app from OpenStreetMap (Overpass API).

Run by hand when preparing a release. The data ships inside the app, so the
phones never query Overpass (its usage policy forbids per-device querying) and
never download it. Standard library only.

    python3 tools/mosques/build_mosques.py --out build/mosques            # query Overpass
    python3 tools/mosques/build_mosques.py --input raw.json --out build/x  # rebuild from a saved answer

Writes <out>/mosques.json — copy it over MuallimiSoniy/Resources/mosques-uz.json —
and <out>/mosques-manifest.json, a local record of the build (count, size,
sha256). Keep the manifest out of Resources: every file there ships in the app.
Nothing at all is written when the answer looks broken (fewer than MIN_MOSQUES).

The data is © OpenStreetMap contributors and published under the ODbL 1.0 —
keep the attribution and the licence with every copy.
"""

import argparse
import datetime
import hashlib
import json
import math
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# The main server is often overloaded (502/504); the others mirror it.
OVERPASS_URLS = (
    "https://overpass-api.de/api/interpreter",
    "https://overpass.private.coffee/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
)
QUERY = """[out:json][timeout:180];
area["ISO3166-1"="UZ"][admin_level=2]->.a;
nwr["amenity"="place_of_worship"]["religion"="muslim"](area.a);
out center tags;"""
# A node and the building outline of the same mosque usually sit this close.
MERGE_METERS = 30.0
# Far below the ~2,200 known mosques: a smaller answer is a broken one and must
# never replace a good dataset.
MIN_MOSQUES = 1000
USER_AGENT = "MuallimiSoniy-mosques-builder/1.0 (+https://github.com/Codingtech2/muallimi-soniy-ios-mobile)"


def fetch_overpass():
    """Asks each server in turn (twice, with a pause) until one answers."""
    body = urllib.parse.urlencode({"data": QUERY}).encode()
    errors = []
    for attempt in range(2):
        for url in OVERPASS_URLS:
            request = urllib.request.Request(
                url, data=body, headers={"User-Agent": USER_AGENT}
            )
            try:
                with urllib.request.urlopen(request, timeout=240) as response:
                    return json.load(response)
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
                errors.append(f"{url}: {error}")
                print(f"overpass failed ({url}): {error}", file=sys.stderr)
        time.sleep(30 * (attempt + 1))
    raise RuntimeError("every Overpass server failed: " + "; ".join(errors))


def point(element):
    """(lat, lon) of a node, or the centre Overpass gives for a way/relation."""
    if element.get("type") == "node":
        return element.get("lat"), element.get("lon")
    centre = element.get("center") or {}
    return centre.get("lat"), centre.get("lon")


def meters(a, b):
    lat1, lon1, lat2, lon2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = (
        math.sin((lat2 - lat1) / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    )
    return 2 * 6_371_000 * math.asin(math.sqrt(h))


def record(element):
    lat, lon = point(element)
    if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)):
        return None
    tags = element.get("tags") or {}
    item = {
        "id": element["type"][0] + str(element["id"]),
        "lat": round(lat, 6),
        "lon": round(lon, 6),
    }
    for key, out in (("name", "name"), ("name:ru", "nameRu"), ("name:uz", "nameUz")):
        value = (tags.get(key) or "").strip()
        if value:
            item[out] = value
    return item


def richness(item):
    return sum(1 for key in ("name", "nameRu", "nameUz") if key in item)


def merge_duplicates(items):
    """Keeps one record per mosque: a node and an outline closer than
    MERGE_METERS are the same building. The record with more names wins and
    borrows any name it lacks from the other."""
    cell = MERGE_METERS / 111_000  # degrees, roughly
    grid = {}
    kept = []
    for item in sorted(items, key=lambda i: (-richness(i), i["id"])):
        gx, gy = int(item["lat"] / cell), int(item["lon"] / cell)
        twin = None
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for other in grid.get((gx + dx, gy + dy), []):
                    if (
                        meters((item["lat"], item["lon"]), (other["lat"], other["lon"]))
                        <= MERGE_METERS
                    ):
                        twin = other
                        break
        if twin is not None:
            for key in ("name", "nameRu", "nameUz"):
                if key in item and key not in twin:
                    twin[key] = item[key]
            continue
        grid.setdefault((gx, gy), []).append(item)
        kept.append(item)
    return sorted(kept, key=lambda i: i["id"])


def make_dataset(raw):
    """The app's dataset from an Overpass answer; writes nothing."""
    elements = raw.get("elements") or []
    items = [r for r in (record(e) for e in elements) if r is not None]
    mosques = merge_duplicates(items)
    generated = (raw.get("osm3s") or {}).get(
        "timestamp_osm_base"
    ) or datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    dataset = {
        "schemaVersion": 1,
        "generatedAt": generated,
        "attribution": "© OpenStreetMap contributors",
        "license": "ODbL-1.0",
        "licenseUrl": "https://www.openstreetmap.org/copyright",
        "count": len(mosques),
        "mosques": mosques,
    }
    return len(elements), dataset


def write(dataset, out_dir):
    """Writes mosques.json and its local manifest (count, size, sha256)."""
    os.makedirs(out_dir, exist_ok=True)
    payload = json.dumps(dataset, ensure_ascii=False, separators=(",", ":")).encode(
        "utf-8"
    )
    with open(os.path.join(out_dir, "mosques.json"), "wb") as handle:
        handle.write(payload)
    manifest = {
        "schemaVersion": 1,
        "version": dataset["generatedAt"][:10].replace("-", "."),
        "sha256": hashlib.sha256(payload).hexdigest(),
        "bytes": len(payload),
        "count": dataset["count"],
    }
    with open(
        os.path.join(out_dir, "mosques-manifest.json"), "w", encoding="utf-8"
    ) as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=1)
    return manifest


def main():
    parser = argparse.ArgumentParser(description="Builds the mosques dataset from OpenStreetMap.")
    parser.add_argument("--out", required=True, help="output folder")
    parser.add_argument(
        "--input", help="a saved Overpass answer instead of a live query"
    )
    parser.add_argument("--save-raw", help="also save the raw Overpass answer here")
    args = parser.parse_args()
    if args.input:
        with open(args.input, encoding="utf-8") as handle:
            raw = json.load(handle)
    else:
        raw = fetch_overpass()
    total, dataset = make_dataset(raw)
    kept = dataset["count"]
    # Checked before anything is written: a broken answer must never replace a good dataset.
    if kept < MIN_MOSQUES:
        print(f"only {kept} mosques — refusing to write anything", file=sys.stderr)
        sys.exit(1)
    if args.save_raw and not args.input:
        with open(args.save_raw, "w", encoding="utf-8") as handle:
            json.dump(raw, handle, ensure_ascii=False)
    manifest = write(dataset, args.out)
    print(
        f"{total} OSM objects -> {kept} mosques, {manifest['bytes']} bytes, sha256 {manifest['sha256']}"
    )


if __name__ == "__main__":
    main()
