"""Offline staging safety checks. Run: python tests/catalog-staging.py"""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('stage_catalog', ROOT / 'tools/stage_catalog.py')
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)
REF = '/research/assets/example/front.jpg'


class StagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.original = {'products': [{'id': 'example', 'name': 'Example', 'images': [REF],
                                      'commercial_status': 'sample', 'price_minor': 100,
                                      'currency': 'USD', 'variants': [{'id': 'example-S', 'size': 'S', 'stock': 3}]}]}
        self.manifest = {'sources': [{'media_paths': [REF]}]}

    def run_compare(self, demo=None):
        return s.compare(self.original, demo or {'products': []}, self.manifest, self.root)

    def test_missing_media_inert_stock_and_inputs_preserved(self):
        before = copy.deepcopy(self.original)
        record = self.run_compare()['records'][0]
        self.assertFalse(record['publish_allowed'])
        self.assertFalse(record['original_gallery_complete'])
        self.assertEqual(record['commercial_evidence']['sample_variants'][0]['sample_stock'], 3)
        self.assertNotIn('variants', record)
        self.assertEqual(self.original, before)
        self.assertEqual(list(self.root.iterdir()), [])

    def test_complete_media_does_not_activate_or_replace_demo_stock(self):
        path = self.root / ('assets' + REF)
        path.parent.mkdir(parents=True)
        path.write_bytes(b'local-image-fixture')
        demo = copy.deepcopy(self.original)
        demo['products'][0]['variants'][0]['stock'] = 91
        demo['products'][0]['images'] = ['/assets' + REF]
        record = self.run_compare(demo)['records'][0]
        self.assertTrue(record['original_gallery_complete'])
        self.assertFalse(record['publish_allowed'])
        self.assertEqual(record['state'], 'existing_demo_preserved')
        self.assertEqual(demo['products'][0]['variants'][0]['stock'], 91)

    def test_original_public_media_layout_is_recognized_without_activation(self):
        path = self.root / REF.lstrip('/')
        path.parent.mkdir(parents=True)
        path.write_bytes(b'local-image-fixture')
        demo = copy.deepcopy(self.original)
        record = self.run_compare(demo)['records'][0]
        self.assertEqual(record['original_gallery'][0]['demo_original_path'], 'present')
        self.assertTrue(record['original_gallery_complete'])
        self.assertFalse(record['publish_allowed'])

    def test_empty_original_path_is_not_hidden_by_a_legacy_copy(self):
        for relative, data in ((REF.lstrip('/'), b''), ('assets' + REF, b'fixture')):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        record = self.run_compare()['records'][0]
        self.assertEqual(record['original_gallery'][0]['demo_original_path'], 'empty')
        self.assertFalse(record['original_gallery_complete'])

    def test_symlinked_original_path_is_not_hidden_by_a_legacy_copy(self):
        target = self.root / 'target.jpg'
        target.write_bytes(b'fixture')
        link = self.root / REF.lstrip('/')
        link.parent.mkdir(parents=True)
        link.symlink_to(target)
        legacy = self.root / ('assets' + REF)
        legacy.parent.mkdir(parents=True)
        legacy.write_bytes(b'legacy fixture')
        record = self.run_compare()['records'][0]
        self.assertEqual(record['original_gallery'][0]['demo_original_path'], 'symlink_rejected')
        self.assertFalse(record['original_gallery_complete'])

    def test_unsafe_paths_and_duplicates_rejected(self):
        for bad in ['/research/assets/../../private.jpg', 'https://example.com/image.jpg', '/etc/passwd']:
            self.original['products'][0]['images'] = [bad]
            with self.assertRaises(ValueError):
                self.run_compare()
        self.original['products'][0]['images'] = [REF]
        self.original['products'].append(copy.deepcopy(self.original['products'][0]))
        with self.assertRaises(ValueError):
            self.run_compare()

    def test_symlink_and_empty_files_are_not_recovery(self):
        target = self.root / 'target.jpg'
        target.write_bytes(b'fixture')
        path = self.root / ('assets' + REF)
        path.parent.mkdir(parents=True)
        path.symlink_to(target)
        self.assertFalse(self.run_compare()['records'][0]['original_gallery_complete'])
        path.unlink()
        path.touch()
        self.assertFalse(self.run_compare()['records'][0]['original_gallery_complete'])

    def test_offline_import_requires_manifest_and_never_activates(self):
        imported = self.root / REF.lstrip('/')
        imported.parent.mkdir(parents=True)
        imported.write_bytes(b'fixture')
        result = s.compare(self.original, {'products': []}, self.manifest, self.root, self.root)
        self.assertTrue(result['records'][0]['original_gallery_complete'])
        self.assertFalse(result['records'][0]['publish_allowed'])
        self.manifest['sources'][0]['media_paths'] = []
        result = s.compare(self.original, {'products': []}, self.manifest, self.root, self.root)
        self.assertFalse(result['records'][0]['original_gallery_complete'])

    def test_current_demo_fixture_is_preserved(self):
        demo = s.read_demo(ROOT / 'dist/catalog.js')
        self.assertEqual(len(demo['products']), 40)
        self.assertEqual(sum(len(product['variants']) for product in demo['products']), 120)
        self.assertTrue(all(p['commercial_status'] == 'sample' for p in demo['products']))

    def test_cli_is_deterministic_and_read_only(self):
        original = self.root / 'original.json'
        original.write_text(json.dumps(self.original))
        cmd = ['python', str(ROOT / 'tools/stage_catalog.py'), '--original', str(original)]
        before = {str(p): p.read_bytes() for p in self.root.rglob('*') if p.is_file()}
        first = subprocess.check_output(cmd)
        self.assertEqual(first, subprocess.check_output(cmd))
        self.assertEqual(json.loads(first)['summary']['publish_allowed'], 0)
        self.assertEqual(before, {str(p): p.read_bytes() for p in self.root.rglob('*') if p.is_file()})


if __name__ == '__main__':
    unittest.main()
