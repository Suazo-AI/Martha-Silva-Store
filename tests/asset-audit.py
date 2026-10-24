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
        self.assertEqual(result['published_fixture'], {'products': 2, 'variants': 6, 'gallery_references': 2})
        self.assertEqual(len(result['unpublished_product_ids']), 38)
        self.assertEqual(len(result['local_media_inventory']), 11)
        self.assertTrue(all(p['status'] == 'present' for p in result['selected_demo_images']))

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


if __name__ == '__main__':
    unittest.main()
