import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('release_tag', Path(__file__).with_name('release-tag.py'))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)
SHA = 'a' * 40
OTHER = 'b' * 40
TAG = 'android-v1.3.0-5'


class ReleaseTagTests(unittest.TestCase):
    def setUp(self):
        self.tags = {}
        self.head = SHA
        self.creates = []
        self.readback_override = None
        for target, replacement in [('api', self.api), ('checkout_sha', lambda: SHA)]:
            mock = patch.object(release, target, replacement)
            mock.start()
            self.addCleanup(mock.stop)

    def api(self, path, values=None):
        if path.startswith('git/matching-refs/tags/'):
            prefix = path.removeprefix('git/matching-refs/tags/')
            return [{'ref': f'refs/tags/{tag}', 'object': obj}
                    for tag, obj in self.tags.items() if tag.startswith(prefix)]
        if path == 'git/ref/heads/main':
            return {'object': {'type': 'commit', 'sha': self.head}}
        if path == 'git/refs':
            self.creates.append(values.copy())
            self.tags[values['ref'].removeprefix('refs/tags/')] = {
                'type': 'commit', 'sha': self.readback_override or values['sha']}
            return {}
        raise AssertionError(path)

    def test_pins_current_main_and_verifies(self):
        release.pin(TAG, SHA)
        release.verify(TAG, SHA)
        self.assertEqual(self.creates, [{'ref': f'refs/tags/{TAG}', 'sha': SHA}])

    def test_rerun_keeps_same_tag_without_writing(self):
        self.tags[TAG] = {'type': 'commit', 'sha': SHA}
        self.head = OTHER
        release.pin(TAG, SHA)
        self.assertEqual(self.creates, [])

    def test_verified_tag_remains_valid_after_main_advances(self):
        release.pin(TAG, SHA)
        self.head = OTHER
        release.verify(TAG, SHA)

    def test_new_tag_rejects_main_movement(self):
        self.head = OTHER
        with self.assertRaises(ValueError):
            release.pin(TAG, SHA)
        self.assertEqual(self.creates, [])

    def test_never_replaces_another_commit_or_an_annotated_tag(self):
        for obj in [{'type': 'commit', 'sha': OTHER}, {'type': 'tag', 'sha': SHA}]:
            with self.subTest(obj=obj):
                self.tags[TAG] = obj
                with self.assertRaises(ValueError):
                    release.pin(TAG, SHA)
                with self.assertRaises(ValueError):
                    release.verify(TAG, SHA)
        self.assertEqual(self.creates, [])

    def test_similar_tag_does_not_count_as_exact_match(self):
        self.tags[TAG + '0'] = {'type': 'commit', 'sha': OTHER}
        release.pin(TAG, SHA)
        self.assertEqual(len(self.creates), 1)

    def test_verify_requires_existing_tag(self):
        with self.assertRaises(ValueError):
            release.verify(TAG, SHA)
        self.assertEqual(self.creates, [])

    def test_detects_tag_changed_after_creation(self):
        self.readback_override = OTHER
        with self.assertRaises(ValueError):
            release.pin(TAG, SHA)

    def test_rejects_wrong_checkout_and_invalid_parameters_before_writing(self):
        for tag, sha in [(TAG, OTHER), ('main', SHA), ('android-v1.3.0-0', SHA),
                         ('../main', SHA), (TAG, 'not-a-sha')]:
            with self.subTest(tag=tag, sha=sha), self.assertRaises(ValueError):
                release.pin(tag, sha)
        self.assertEqual(self.creates, [])

    def test_supports_mac_release_tags(self):
        release.pin('mac-v1.1.0-7', SHA)
        release.verify('mac-v1.1.0-7', SHA)


if __name__ == '__main__':
    unittest.main()
