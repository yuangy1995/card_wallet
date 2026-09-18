import base64
import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('configure_sparkle', Path(__file__).with_name('configure-sparkle.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SparkleConfigurationTests(unittest.TestCase):
    def test_accepts_new_public_key(self):
        key = base64.b64encode(bytes(range(32))).decode()
        self.assertEqual(module.validated_key(key), key)

    def test_rejects_empty_invalid_or_wrong_length(self):
        for value in ['', 'not base64', base64.b64encode(b'short').decode(), base64.b64encode(bytes(32)).decode()]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                module.validated_key(value)

    def test_rejects_previous_key(self):
        with self.assertRaises(ValueError):
            module.validated_key(module.PREVIOUS_PUBLIC_KEY)

    def test_preserves_app_metadata_and_uses_current_repo(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'Info.plist'
            path.write_bytes(plistlib.dumps({'CFBundleIdentifier': 'com.applist.cardwallet.mac', 'SUFeedURL': 'https://example.invalid'}))
            key = base64.b64encode(bytes(range(32))).decode()
            module.configure(path, key)
            info = plistlib.loads(path.read_bytes())
            self.assertEqual(info['CFBundleIdentifier'], 'com.applist.cardwallet.mac')
            self.assertEqual(info['SUPublicEDKey'], key)
            self.assertEqual(info['SUFeedURL'], module.FEED)

    def test_invalid_key_does_not_modify_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'Info.plist'
            before = plistlib.dumps({'CFBundleIdentifier': 'unchanged'})
            path.write_bytes(before)
            with self.assertRaises(ValueError):
                module.configure(path, '')
            self.assertEqual(path.read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
