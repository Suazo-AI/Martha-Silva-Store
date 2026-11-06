"""Current release manifest includes control hashes without counting them public."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('snapshot', ROOT / 'tools/verify_release_snapshot.py')
snapshot = importlib.util.module_from_spec(spec)
spec.loader.exec_module(snapshot)


class SnapshotTests(unittest.TestCase):
    def test_record_verify_and_negative_controls(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            static = root / 'build-inputs/static'
            dist = root / 'dist'
            static.mkdir(parents=True)
            dist.mkdir()
            (root / 'src').mkdir()
            # Keep the actual frozen path identities, with tiny inert fixture bytes.
            for source in (ROOT / 'dist').rglob('*'):
                if not source.is_file():
                    continue
                rel = source.relative_to(ROOT / 'dist')
                data = source.read_bytes() if rel.as_posix() in ('catalog.js', '_headers') else b'fixture'
                target = dist / rel
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                canonical = root / 'src' / rel if str(rel) in ('app.js', 'demo-api.js', 'integration-adapters.js') else static / rel
                canonical.parent.mkdir(parents=True, exist_ok=True)
                canonical.write_bytes(data)
            manifest = root / 'snapshot.json'
            with patch.object(snapshot, 'ROOT', root), patch.object(snapshot, 'SNAPSHOT', manifest):
                snapshot.verify(record=True)
                snapshot.verify()
                recorded = json.loads(manifest.read_text())
                self.assertEqual(len(recorded), 1559)
                self.assertEqual(recorded['_headers']['sha256'], snapshot.digest(dist / '_headers'))
                original = (dist / '_headers').read_bytes()
                (dist / '_headers').write_bytes(b'tampered')
                with self.assertRaisesRegex(AssertionError, 'Canonical/dist drift'):
                    snapshot.verify(record=True)
                (static / '_headers').write_bytes(b'tampered')
                with self.assertRaisesRegex(AssertionError, 'Publication bytes differ'):
                    snapshot.verify()
                (dist / '_headers').write_bytes(original)
                (static / '_headers').write_bytes(original)
                (dist / 'unexpected.js').write_bytes(b'extra')
                with self.assertRaisesRegex(AssertionError, 'public path count changed'):
                    snapshot.verify(record=True)
                (dist / 'unexpected.js').unlink()
                (dist / '_headers').unlink()
                with self.assertRaisesRegex(AssertionError, 'Missing static asset control'):
                    snapshot.verify(record=True)


if __name__ == '__main__':
    unittest.main()
