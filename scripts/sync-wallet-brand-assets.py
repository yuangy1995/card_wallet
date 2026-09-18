#!/usr/bin/env python3
"""Maintain committed iOS/Web artwork from the existing Android/Mac sources, offline.
Run from any directory. --check validates without modifying files; no runtime generation.
"""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / 'apps/android'
MAC = ROOT / 'apps/macos'
IOS = ROOT / 'apps/ios'
WEB = ROOT / 'apps/web'
NETWORKS = ('visa', 'mastercard', 'amex', 'unionpay', 'jcb', 'discover', 'diners')


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()


def outputs():
    source = json.loads((ANDROID / 'branding/catalog.json').read_text())
    entries = [{key: row[key] for key in ('id', 'name', 'aliases', 'resource')} for row in source['issuers']]
    assert len(entries) == source['issuer_count']
    assert len({row['id'] for row in entries}) == len(entries)
    catalog = encoded(entries)
    assert (MAC / 'Resources/WalletBrandCatalog.json').read_bytes() == catalog, 'Refresh Mac artwork first'
    expected = {
        IOS / 'Resources/WalletBrandCatalog.json': catalog,
        WEB / 'src/assets/wallet-brand-catalog.json': catalog,
    }
    for path in (MAC / 'Resources/WalletBranding.xcassets').rglob('*'):
        if path.is_file():
            expected[IOS / 'Resources/WalletBranding.xcassets' / path.relative_to(MAC / 'Resources/WalletBranding.xcassets')] = path.read_bytes()
    resources = [row['resource'] + suffix for row in entries for suffix in ('', '_card')]
    resources += ['wallet_network_' + name for name in NETWORKS]
    for name in resources:
        expected[WEB / 'public/wallet-brands' / (name + '.webp')] = (ANDROID / 'app/src/main/res/drawable-nodpi' / (name + '.webp')).read_bytes()
    for path in (MAC / 'Resources/WalletBrandLicenses').glob('*.txt'):
        expected[IOS / 'Resources/WalletBrandLicenses' / path.name] = path.read_bytes()
        expected[WEB / 'public/wallet-brands/licenses' / path.name] = path.read_bytes()
    manifest = {
        'assetRevision': source['asset_revision'], 'issuerCount': len(entries), 'networkCount': len(NETWORKS),
        'catalogSHA256': hashlib.sha256(catalog).hexdigest(),
        'sources': ['apps/android/branding/catalog.json', 'apps/macos/Resources/WalletBranding.xcassets'],
        'note': 'Display hints only; no BIN or ownership verification. Unknown or ambiguous issuers use a generic card.',
        'assets': {str(path.relative_to(ROOT)): hashlib.sha256(data).hexdigest() for path, data in sorted(expected.items())}
    }
    expected[ROOT / 'contracts/card-wallet/branding-manifest.json'] = encoded(manifest)
    return expected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    expected = outputs()
    generated = [IOS / 'Resources/WalletBranding.xcassets', IOS / 'Resources/WalletBrandLicenses', WEB / 'public/wallet-brands']
    stale = [path for folder in generated for path in folder.rglob('*') if path.is_file() and path not in expected]
    changed = [path for path, data in expected.items() if not path.is_file() or path.read_bytes() != data]
    if args.check:
        if changed or stale:
            raise SystemExit('Outdated branding files:\n' + '\n'.join(str(path.relative_to(ROOT)) for path in changed + stale))
    else:
        for path in stale:
            path.unlink()
        for path in changed:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(expected[path])
    print(f'Verified {len(expected)} committed files; original bytes, aspect ratios, alpha and licenses retained.')


if __name__ == '__main__':
    main()
