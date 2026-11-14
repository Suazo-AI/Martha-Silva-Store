"""Fast unit contract for the transactional migration envelope."""
import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('usd_change_db', ROOT / 'tools/db/saviadb.py')
db = importlib.util.module_from_spec(spec)
spec.loader.exec_module(db)


class MigrationEnvelopeTests(unittest.TestCase):
    def test_marked_file_and_registry_share_session(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'V028__probe.sql'
            path.write_text('-- savia:transactional\nCREATE TABLE dbo.Probe(Id int);\nGO\n')
            calls = []
            with patch.object(db, 'migration_files', return_value=[path]), patch.object(db, 'scalar', return_value='none'), \
                    patch.object(db, 'run_sql', side_effect=lambda name, sql: (calls.append(sql) or (0, ''))):
                self.assertEqual(0, db.migrate('SAVIA_T_probe')[0])
            script = next(sql for sql in calls if 'CREATE TABLE dbo.Probe' in sql)
            for required in ['SET XACT_ABORT ON', 'BEGIN TRAN', '@@TRANCOUNT', 'XACT_STATE()', 'INSERT INTO dbo.SaviaMigrations', 'COMMIT']:
                self.assertIn(required, script)




if __name__ == '__main__':
    unittest.main()
