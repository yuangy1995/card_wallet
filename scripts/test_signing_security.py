import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace("-", "_"), ROOT / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class SigningSecurityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)

    def stage(self, name, content):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        subprocess.run(["git", "add", "--", name], cwd=self.repo, check=True)

    def check(self):
        return subprocess.run(["python3", str(ROOT / "check-signing-secrets.py")], cwd=self.repo, capture_output=True, text=True)

    def test_blocks_signing_files(self):
        self.stage("app/release.jks", "fake binary fixture")
        self.assertEqual(self.check().returncode, 1)

    def test_blocks_literal_gradle_password_without_printing_it(self):
        value = "test-only-" + "password-value"
        self.stage("app/build.gradle.kts", 'storePassword = "' + value + '"')
        result = self.check()
        self.assertEqual(result.returncode, 1)
        self.assertNotIn(value, result.stdout + result.stderr)

    def test_allows_environment_signing_and_public_key(self):
        self.stage("app/build.gradle.kts", 'storePassword = providers.environmentVariable("ANDROID_KEYSTORE_PASSWORD").orNull')
        self.stage("public.pem", "-----BEGIN PUBLIC KEY-----\nfixture\n-----END PUBLIC KEY-----")
        self.stage(".env.example", "EXAMPLE=\n")
        self.assertEqual(self.check().returncode, 0)

    def test_blocks_private_key_in_arbitrary_text_file(self):
        self.stage("unexpected.txt", "-----BEGIN " + "PRIVATE KEY-----\nfixture")
        self.assertEqual(self.check().returncode, 1)

    def test_blocks_token_without_printing_token(self):
        token = "ghp" + "_" + "a" * 40
        self.stage("config.txt", token)
        result = self.check()
        self.assertEqual(result.returncode, 1)
        self.assertNotIn(token, result.stdout + result.stderr)

    def test_upload_uses_stdin_not_command_arguments(self):
        rotate = load("rotate-android-signing")
        (self.repo / "release.p12").write_bytes(b"test fixture")
        record = {"alias": "test-alias", "password": "test-only-password", "certificate_sha256": "ab" * 32}
        with patch.object(rotate, "execute") as execute, patch("builtins.print"):
            rotate.upload("owner/repo", self.repo, record)
        self.assertEqual(execute.call_count, 5)
        for call in execute.call_args_list:
            self.assertNotIn(record["password"], " ".join(call.args[0]))
            self.assertNotIn("--body", call.args[0])
            self.assertIn("data", call.kwargs)

    def test_private_backup_is_exclusive_and_owner_only(self):
        rotate = load("rotate-android-signing")
        output = self.repo / "backup.txt"
        rotate.write_private(output, "fixture")
        self.assertEqual(output.stat().st_mode & 0o777, 0o600)
        with self.assertRaises(FileExistsError):
            rotate.write_private(output, "must not overwrite")

    def test_history_password_is_found_after_deletion(self):
        history = load("prepare-signing-history-redactions")
        value = "history-test-" + "secret"
        self.stage("old/app/build.gradle.kts", 'keyPassword = "' + value + '"')
        subprocess.run(["git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "fixture"], cwd=self.repo, check=True)
        subprocess.run(["git", "rm", "-q", "old/app/build.gradle.kts"], cwd=self.repo, check=True)
        subprocess.run(["git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "remove fixture"], cwd=self.repo, check=True)
        cwd = os.getcwd()
        try:
            os.chdir(self.repo)
            self.assertEqual(history.collect_passwords(), {value.encode()})
        finally:
            os.chdir(cwd)


if __name__ == "__main__":
    unittest.main()
