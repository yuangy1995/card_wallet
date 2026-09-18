"""从客户端子目录运行时也必须检查全仓，而不是仅检查当前目录。"""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCANNER = Path(__file__).with_name('check-signing-secrets.py').resolve()


class SigningScanScopeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        subprocess.run(['git', 'init', '-q', str(self.repo)], check=True)
        self.nested = self.repo / 'apps/android'
        self.nested.mkdir(parents=True)

    def stage(self, name, content):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        subprocess.run(['git', 'add', '--', name], cwd=self.repo, check=True)

    def check_nested(self):
        return subprocess.run([sys.executable, str(SCANNER)], cwd=self.nested, capture_output=True, text=True)

    def test_nested_invocation_finds_signing_file_in_other_client(self):
        self.stage('apps/macos/unexpected.p12', 'test fixture, not a real key')
        result = self.check_nested()
        self.assertEqual(result.returncode, 1)
        self.assertIn('apps/macos/unexpected.p12', result.stderr)

    def test_nested_invocation_finds_root_token_without_printing_it(self):
        token = 'ghp' + '_' + 'b' * 40
        self.stage('unrelated/config.txt', token)
        result = self.check_nested()
        self.assertEqual(result.returncode, 1)
        self.assertNotIn(token, result.stdout + result.stderr)

    def test_nested_invocation_allows_clean_repository(self):
        self.stage('apps/android/build.gradle.kts', 'storePassword = providers.environmentVariable("ANDROID_KEYSTORE_PASSWORD").orNull')
        self.stage('apps/macos/public.pem', '-----BEGIN PUBLIC KEY-----\npublic test fixture\n-----END PUBLIC KEY-----')
        self.assertEqual(self.check_nested().returncode, 0)


if __name__ == '__main__':
    unittest.main()
