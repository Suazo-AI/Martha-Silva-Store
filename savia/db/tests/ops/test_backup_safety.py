"""Controles de rechazo y regresión sin usar Docker ni SQL Server."""
import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
import pilot_backup as backup


class BackupSafetyTests(unittest.TestCase):
    def test_retention_keeps_fourteen_complete_backups_and_unrelated_files(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as temporary:
            folder = Path(temporary)
            for index in range(16):
                path = folder / f"SAVIA_DEV_safe_20261112T1200{index:02d}000000Z_abcdef12.bak"
                for suffix in (".bak", ".json", ".sha256"):
                    path.with_suffix(suffix).write_text("fixture", encoding="utf-8")
            unrelated = folder / "otra-copia.bak"
            unrelated.write_text("preservar", encoding="utf-8")
            with patch.object(backup, "backup_folder", return_value=folder):
                backup.prune()
            self.assertTrue(unrelated.exists())
            self.assertEqual(len(list(folder.glob("SAVIA_*.bak"))), 14)
            self.assertEqual(len(list(folder.glob("*.json"))), 14)
            self.assertEqual(len(list(folder.glob("*.sha256"))), 14)
            self.assertFalse((folder / "SAVIA_DEV_safe_20261112T120000000000Z_abcdef12.bak").exists())

    def test_restore_retains_metadata_if_safety_retention_removes_input(self):
        data = {"counts": dict.fromkeys(backup.TABLES, 1)}
        # The safety backup may prune the oldest input after it was uploaded.
        with patch.object(backup, "metadata_for", side_effect=[data, FileNotFoundError()]) as metadata, \
             patch.object(backup, "uploaded", return_value=contextlib.nullcontext("/tmp/copy.bak")), \
             patch.object(backup, "verify_sql"), patch.object(backup, "backup"), \
             patch.object(backup, "restore_sql"), patch.object(backup, "sql"), \
             patch.object(backup.saviadb, "scalar", return_value="1"), \
             patch.object(backup, "counts", return_value=data["counts"]), \
             contextlib.redirect_stdout(io.StringIO()):
            backup.restore(Path("old.bak"), "SAVIA_DEV_safety", True)
            self.assertEqual(metadata.call_count, 1)

    def test_missing_replace_flag_cannot_touch_sql_or_file(self):
        with patch.object(backup, "local_file") as read, patch.object(backup.saviadb, "run_sql") as sql, \
             contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(backup.main(["restore", "absent.bak", "--db", "SAVIA_DEV_safe"]), 1)
            read.assert_not_called()
            sql.assert_not_called()

    def test_invalid_database_cannot_touch_sql_or_file(self):
        with patch.object(backup, "local_file") as read, patch.object(backup.saviadb, "run_sql") as sql, \
             contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(backup.main(["restore", "absent.bak", "--db", "master", "--yes-replace"]), 1)
            read.assert_not_called()
            sql.assert_not_called()

    def test_failed_reservation_never_drops_an_existing_database(self):
        with patch.object(backup, "sql", side_effect=RuntimeError("already exists")), \
             patch.object(backup.saviadb, "drop") as drop:
            with self.assertRaises(RuntimeError):
                with backup.restored_new("/tmp/copy.bak", backup.RESTORE_TEST):
                    self.fail("must not yield")
            drop.assert_not_called()


if __name__ == "__main__":
    unittest.main()
