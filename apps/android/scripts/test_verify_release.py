import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("verify_release", Path(__file__).with_name("verify-release.py"))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)
TEST_CERTIFICATE = Path(__file__).resolve().parents[1].joinpath("signing-certificate.sha256").read_text().strip()


class ReleaseVerificationTests(unittest.TestCase):
    def setUp(self):
        env = patch.dict("os.environ", {"ANDROID_SIGNING_CERT_SHA256": TEST_CERTIFICATE})
        env.start()
        self.addCleanup(env.stop)
        self.badging = "package: name='com.applist.cardwallet' versionCode='4' versionName='1.2.0'\nminSdkVersion:'23'\n"
        self.certificates = (f"Signer #1 certificate SHA-256 digest: {TEST_CERTIFICATE}\n"
                             "Verified using v1 scheme (JAR signing): true\n"
                             "Verified using v2 scheme (APK Signature Scheme v2): true\n")

    def test_accepts_configured_new_release(self):
        release.validate_metadata(self.badging, self.certificates, "1.2.0", "4")

    def test_rejects_changed_package_version_or_minimum_sdk(self):
        for original, changed in [("com.applist.cardwallet", "com.applist.cardwallet.preview"),
                                  ("versionCode='4'", "versionCode='3'"),
                                  ("versionName='1.2.0'", "versionName='1.1.0'"),
                                  ("minSdkVersion:'23'", "minSdkVersion:'24'")]:
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                release.validate_metadata(self.badging.replace(original, changed), self.certificates, "1.2.0", "4")

    def test_rejects_debug_apk(self):
        with self.assertRaises(ValueError):
            release.validate_metadata(self.badging + "application-debuggable\n", self.certificates, "1.2.0", "4")

    def test_rejects_changed_or_multiple_signers(self):
        for certificates in [self.certificates.replace(TEST_CERTIFICATE, "0" * 64),
                             self.certificates + f"Signer #2 certificate SHA-256 digest: {TEST_CERTIFICATE}\n"]:
            with self.assertRaises(ValueError):
                release.validate_metadata(self.badging, certificates, "1.2.0", "4")

    def test_rejects_missing_signature_scheme(self):
        for scheme in ["v1 scheme (JAR signing)", "v2 scheme (APK Signature Scheme v2)"]:
            with self.subTest(scheme=scheme), self.assertRaises(ValueError):
                release.validate_metadata(self.badging, self.certificates.replace(f"{scheme}: true", f"{scheme}: false"), "1.2.0", "4")

    def test_missing_fingerprint_never_trusts_apk(self):
        with patch.dict("os.environ", {}, clear=True), self.assertRaises(ValueError):
            release.validate_metadata(self.badging, self.certificates, "1.2.0", "4")

    def test_rejects_invalid_fingerprint(self):
        for value in ["", "a1", "g" * 64]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                release.expected_certificate(value)

    def test_normalizes_public_fingerprint(self):
        self.assertEqual(release.expected_certificate(":".join(["A1"] * 32)), "a1" * 32)

    def test_rejects_other_environment_certificate(self):
        with patch.dict("os.environ", {"ANDROID_SIGNING_CERT_SHA256": "a1" * 32}), self.assertRaises(ValueError):
            release.expected_certificate()

    def test_rejects_compromised_key_even_when_configured(self):
        with self.assertRaisesRegex(ValueError, "泄漏"):
            release.expected_certificate(release.COMPROMISED_CERTIFICATE)

    def test_rejects_apk_signed_by_compromised_key(self):
        with self.assertRaises(ValueError):
            release.validate_metadata(self.badging, self.certificates.replace(TEST_CERTIFICATE, release.COMPROMISED_CERTIFICATE), "1.2.0", "4")


if __name__ == "__main__":
    unittest.main()
