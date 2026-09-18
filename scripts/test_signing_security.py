from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent


class SigningSecurityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        subprocess.run(['git', 'init', '-q', str(self.repo)], check=True)

    def stage(self, name, content):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        subprocess.run(['git', 'add', '--', name], cwd=self.repo, check=True)

    def check(self, cwd=None):
        return subprocess.run(['python3', str(ROOT / 'check-signing-secrets.py')], cwd=cwd or self.repo, capture_output=True, text=True)

    def test_blocks_signing_files(self):
        self.stage('app/release.jks', 'fake binary fixture')
        self.assertEqual(self.check().returncode, 1)

    def test_blocks_literal_password_without_printing_it(self):
        value = 'test-only-' + 'password-value'
        self.stage('app/build.gradle.kts', 'storePassword = "' + value + '"')
        result = self.check()
        self.assertEqual(result.returncode, 1)
        self.assertNotIn(value, result.stdout + result.stderr)

    def test_allows_environment_and_public_key(self):
        self.stage('app/build.gradle.kts', 'storePassword = providers.environmentVariable("ANDROID_KEYSTORE_PASSWORD").orNull')
        self.stage('public.pem', '-----BEGIN PUBLIC KEY-----\nfixture\n-----END PUBLIC KEY-----')
        self.stage('.env.example', 'EXAMPLE=\n')
        self.assertEqual(self.check().returncode, 0)

    def test_blocks_private_key_in_text_file(self):
        self.stage('unexpected.txt', '-----BEGIN ' + 'PRIVATE KEY-----\nfixture')
        self.assertEqual(self.check().returncode, 1)

    def test_blocks_token_without_printing_it(self):
        token = 'ghp' + '_' + 'a' * 40
        self.stage('config.txt', token)
        result = self.check()
        self.assertEqual(result.returncode, 1)
        self.assertNotIn(token, result.stdout + result.stderr)

    def test_nested_invocation_checks_entire_repository(self):
        self.stage('elsewhere/release.p12', 'fixture')
        nested = self.repo / 'apps/android'
        nested.mkdir(parents=True)
        self.assertEqual(self.check(nested).returncode, 1)


if __name__ == '__main__':
    unittest.main()
