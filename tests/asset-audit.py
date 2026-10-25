"""Standard-library audit regression checks; no network or production writes."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('audit_assets', ROOT / 'tools/audit_assets.py')
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)


class AuditTests(unittest.TestCase):
    def test_evidence_counts_and_current_demo(self):
        result = a.audit(json.loads((ROOT / 'evidence/asset-source-manifest.json').read_text()), ROOT / 'dist')
        for catalog in result['catalog_evidence']:
            self.assertEqual((catalog['products'], catalog['variants'], catalog['gallery_references']), (40, 120, 170))
        self.assertEqual(result['published_fixture'], {'products': 40, 'variants': 120, 'gallery_references': 170})
        self.assertEqual(result['unpublished_product_ids'], [])
        unavailable = set(json.loads((ROOT / 'tests/fixtures/original-missing-media.json').read_text())['paths'])
        missing = {item['reference'] for item in result['original_media'] if item['demo']['status'] != 'present'}
        self.assertEqual(missing, unavailable)
        self.assertEqual(result['unique_original_media_paths'], 778)
        self.assertEqual(result['original_media_paths_present_in_demo'], 777)
        inventory = {item['path'].replace('\\', '/') for item in result['local_media_inventory']}
        self.assertTrue(all(item['demo']['path'].replace('\\', '/') in inventory
                            for item in result['original_media'] if item['demo']['status'] == 'present'))
        self.assertTrue(all(p['status'] == 'present' for p in result['selected_demo_images']))

    def test_original_and_legacy_asset_layouts_are_both_observed(self):
        reference = '/research/assets/example/front.jpg'
        for relative in (reference.lstrip('/'), 'assets' + reference):
            with self.subTest(relative=relative), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                target = root / relative
                target.parent.mkdir(parents=True)
                target.write_bytes(b'fixture image')
                observed = a.original_record(root, reference)
                self.assertEqual(observed['status'], 'present')
                self.assertEqual(observed['path'], relative)

    def test_empty_original_file_cannot_be_hidden_by_a_legacy_copy(self):
        reference = '/research/assets/example/front.jpg'
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for relative in (reference.lstrip('/'), 'assets' + reference):
                target = root / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(b'' if relative == reference.lstrip('/') else b'fixture')
            self.assertEqual(a.original_record(root, reference)['status'], 'empty')

    def test_symlinks_are_rejected_in_both_original_and_legacy_layouts(self):
        reference = '/research/assets/example/front.jpg'
        for relative in (reference.lstrip('/'), 'assets' + reference):
            with self.subTest(relative=relative), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                original = root / 'fixture.jpg'
                original.write_bytes(b'fixture')
                link = root / relative
                link.parent.mkdir(parents=True)
                link.symlink_to(original)
                if relative == reference.lstrip('/'):
                    legacy = root / ('assets' + reference)
                    legacy.parent.mkdir(parents=True)
                    legacy.write_bytes(b'legacy fixture')
                self.assertEqual(a.original_record(root, reference)['status'], 'symlink_rejected')

    def test_path_allowlist(self):
        for path in ['/research/assets/../secret.jpg', 'https://example.com/test.jpg',
                     '/research/assets/data.sqlite', '/research/assets/a.jpg?token=secret',
                     '/research/assets/.env', '/etc/passwd']:
            self.assertFalse(a.safe(path), path)
        self.assertTrue(a.safe('/research/assets/store-media/dorado/01-front-800.webp'))

    def test_missing_and_symlink_not_read(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.assertEqual(a.record(root, 'missing.jpg')['status'], 'missing')
            (root / 'actual.jpg').write_bytes(b'fixture bytes')
            (root / 'link.jpg').symlink_to(root / 'actual.jpg')
            self.assertEqual(a.record(root, 'link.jpg')['status'], 'symlink_rejected')
            self.assertEqual(a.record(root, 'actual.jpg')['bytes'], 13)
            (root / 'empty.jpg').touch()
            self.assertEqual(a.record(root, 'empty.jpg')['status'], 'empty')


if __name__ == '__main__':
    unittest.main()
