import base64
import plistlib
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = 'yuangy1995/card_wallet'

class PublicReleaseMigrationTests(unittest.TestCase):
    def test_macos_public_key_and_feed(self):
        with (ROOT / 'apps/macos/Resources/Info.plist').open('rb') as stream:
            config = plistlib.load(stream)
        self.assertEqual(config['SUFeedURL'], f'https://github.com/{REPOSITORY}/releases/latest/download/appcast.xml')
        self.assertEqual(len(base64.b64decode(config['SUPublicEDKey'], validate=True)), 32)
        self.assertNotEqual(config['SUPublicEDKey'], 'zYvJmq2G5KNcMa/wbxZwKrd+LmjFB3c1khtPWPj6qFo=')

    def test_release_workflows_only_publish_here(self):
        for platform in ('android', 'macos'):
            with self.subTest(platform=platform):
                text = (ROOT / f'.github/workflows/{platform}-release.yml').read_text()
                self.assertIn(f'RELEASE_REPOSITORY: {REPOSITORY}', text)
                self.assertIn('contents: write', text)
                self.assertIn('${{ github.token }}', text)
                self.assertIn('--verify-tag', text)
                self.assertNotIn('--target', text)
                self.assertIn('release-tag.py pin "$RELEASE_TAG" "$GITHUB_SHA"', text)
                self.assertEqual(text.count('release-tag.py verify "$RELEASE_TAG" "$GITHUB_SHA"'), 2)
                self.assertLess(text.index('Pin release tag'), text.index('Run release verification tests'))
                self.assertNotIn('secrets.RELEASES_TOKEN', text)
                self.assertNotIn('card-wallet-releases', text)
                self.assertIn("github.ref == 'refs/heads/main'", text)
        android = (ROOT / '.github/workflows/android-release.yml').read_text()
        self.assertIn('--latest=false', android)
        self.assertIn('Delete temporary signing key', android)

    def test_android_setup_does_not_install_retired_tools(self):
        text = (ROOT / '.github/workflows/android-release.yml').read_text()
        setup = re.search(r'uses: android-actions/setup-android@v3\n(.*?)(?=\n      - |\Z)', text, re.S)
        self.assertIsNotNone(setup)
        packages = re.search(r'^\s+packages:\s*([^\n]+)', setup.group(1), re.M)
        self.assertIsNotNone(packages, '不能回退到包含 tools 的默认 SDK 包列表')
        names = packages.group(1).strip("\"' ").split()
        self.assertIn('platform-tools', names)
        self.assertNotIn('tools', names)

    def test_updater_and_release_verifiers_agree(self):
        names = ('apps/android/app/src/main/java/com/example/creditcard/update/GitHubRelease.kt',
                 'apps/android/prepare-update.sh', 'apps/macos/prepare-update.sh', 'apps/macos/scripts/verify-update.swift')
        for name in names:
            text = (ROOT / name).read_text()
            self.assertIn(REPOSITORY, text)
            self.assertNotIn('card-wallet-releases', text)

    def test_committed_certificate_is_new(self):
        value = (ROOT / 'apps/android/signing-certificate.sha256').read_text().strip()
        self.assertRegex(value, r'^[0-9a-f]{64}$')
        self.assertNotEqual(value, 'e09a2af6d581dd247df0d4ae3ba08b957fee69cfbdd1b0b89dc37c958559a1cf')
        self.assertFalse((ROOT / 'apps/android/app/release.jks').exists())

    def test_only_four_readonly_quality_and_manual_release_entries_remain(self):
        workflows = ROOT / '.github/workflows'
        self.assertEqual({p.name for p in workflows.iterdir() if p.is_file()}, {
            'platform-quality.yml', 'signing-security.yml', 'android-release.yml', 'macos-release.yml'
        })
        for name in ('platform-quality.yml', 'signing-security.yml'):
            text = (workflows / name).read_text()
            self.assertNotIn('contents: write', text)
            self.assertNotIn('actions: write', text)
            self.assertNotRegex(text, r'\$\{\{[^}]*\bsecrets\s*[.\[]')
        security = (workflows / 'signing-security.yml').read_text()
        self.assertNotIn('verify-stage-', security)
        self.assertNotIn('Export reviewed stage three source', security)

    def test_consolidated_quality_keeps_regressions_and_preview(self):
        text = (ROOT / '.github/workflows/platform-quality.yml').read_text()
        for required in ('workflow_dispatch:', 'workflow_call:', 'pnpm test:run',
                         'browser-regression.py', 'parity-browser-regression.py',
                         ':app:testDebugUnitTest', ':app:lintDebug', ':app:connectedDebugAndroidTest',
                         '-PwalletPreview=true', 'com.applist.cardwallet.preview',
                         'platform: [ios, macos]', 'persist-credentials: false'):
            self.assertIn(required, text)
        self.assertNotIn('contents: write', text)
        for retired in ('android-ui-integration.yml', 'web-quality.yml',
                        'macos-brand-workbench.yml', 'wallet-feedback-build.yml',
                        'release-completion-once.yml'):
            self.assertFalse((ROOT / '.github/workflows' / retired).exists())

if __name__ == '__main__':
    unittest.main()
