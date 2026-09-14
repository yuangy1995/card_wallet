#!/usr/bin/env python3
"""Copy the committed Android catalogue/artwork to native Mac resources, fully offline.
Maintenance only: pip install Pillow==11.3.0; python3 scripts/import-android-branding.py
Use --check in CI. Regular Xcode/build.sh builds use committed resources, not Python.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
from PIL import Image

MAC = Path(__file__).resolve().parents[1]
ANDROID = MAC.parent / "android"
SOURCE = ANDROID / "app/src/main/res/drawable-nodpi"
ASSETS = MAC / "Resources/WalletBranding.xcassets"
NETWORKS = ("visa", "mastercard", "amex", "unionpay", "jcb", "discover", "diners")


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode()


def outputs():
    catalog_path = ANDROID / "branding/catalog.json"
    catalog = json.loads(catalog_path.read_text())
    entries = [{k: row[k] for k in ("id", "name", "aliases", "resource")} for row in catalog["issuers"]]
    assert len(entries) == catalog["issuer_count"]
    assert len({i["id"] for i in entries}) == len(entries)
    expected = {MAC / "Resources/WalletBrandCatalog.json": json_bytes(entries)}
    expected[ASSETS / "Contents.json"] = json_bytes({"info": {"author": "xcode", "version": 1}})
    resources = [e["resource"] + suffix for e in entries for suffix in ("", "_card")]
    resources += ["wallet_network_" + network for network in NETWORKS]
    hashes = []
    for resource in resources:
        path = SOURCE / (resource + ".webp")
        raw = path.read_bytes()
        with Image.open(io.BytesIO(raw)) as source:
            rgba = source.convert("RGBA")
            if rgba.getextrema()[3][0] == 255:
                raise ValueError(f"Logo has no transparency: {resource}")
            png = io.BytesIO()
            rgba.save(png, format="PNG", optimize=True)
            with Image.open(io.BytesIO(png.getvalue())) as converted:
                assert converted.size == rgba.size and converted.tobytes() == rgba.tobytes()
            size = list(rgba.size)
        folder = ASSETS / (resource + ".imageset")
        expected[folder / "logo.png"] = png.getvalue()
        expected[folder / "Contents.json"] = json_bytes({
            "images": [{"filename": "logo.png", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
            "properties": {"template-rendering-intent": "original"}
        })
        hashes.append({"resource": resource, "size": size,
                       "android_webp_sha256": hashlib.sha256(raw).hexdigest(),
                       "mac_png_sha256": hashlib.sha256(png.getvalue()).hexdigest()})
    for path in sorted((ANDROID / "app/src/main/assets/licenses").glob("wallet-catalog-*.txt")):
        expected[MAC / "Resources/WalletBrandLicenses" / path.name] = path.read_bytes()
    expected[MAC / "Branding/android-source-manifest.json"] = json_bytes({
        "android_catalog_sha256": hashlib.sha256(catalog_path.read_bytes()).hexdigest(),
        "asset_revision": catalog["asset_revision"], "issuer_count": len(entries),
        "network_count": len(NETWORKS), "upstreams": catalog["upstreams"],
        "source_attribution": catalog["assets"], "assets": hashes
    })
    return expected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected = outputs()
    stale = sorted(p for p in ASSETS.rglob("*") if p.is_file() and p not in expected)
    changed = [p for p, data in expected.items() if not p.exists() or p.read_bytes() != data]
    if args.check:
        if changed or stale:
            raise SystemExit("Outdated Mac branding resources:\n" + "\n".join(str(p.relative_to(MAC)) for p in changed + stale))
    else:
        for p in stale:
            p.unlink()
        for p in changed:
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(expected[p])
    print(f"Verified {len(expected)} files; image pixels, aspect ratios and alpha preserved. No network requests.")


if __name__ == "__main__":
    main()
