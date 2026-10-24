"""Runner-only stdlib regression tests; no npm installation required."""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location('check', Path(__file__).with_name('check.py'))
check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check)


class RunnerTests(unittest.TestCase):
    def test_overrides_removed_without_mutating_parent(self):
        with mock.patch.dict(os.environ, {'FRONTEND_APP': 'other.js', 'FRONTEND_API': 'other-api.js'}):
            env = check.clean_environment()
            self.assertNotIn('FRONTEND_APP', env)
            self.assertNotIn('FRONTEND_API', env)
            self.assertEqual(os.environ['FRONTEND_APP'], 'other.js')

    def test_unknown_argument_is_rejected(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as raised:
            check.main(['--unknown'])
        self.assertEqual(raised.exception.code, 2)

    def test_missing_dependency_does_not_download(self):
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(check, 'ROOT', Path(directory)), \
                mock.patch.object(check.shutil, 'which', return_value='node'), \
                mock.patch.object(check.subprocess, 'run') as run, contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(check.main([]), 2)
            run.assert_not_called()

    def test_failed_install_stops_and_preserves_exit_code(self):
        with mock.patch.object(check.shutil, 'which', return_value='executable'), \
                mock.patch.object(check.subprocess, 'run', side_effect=subprocess.CalledProcessError(7, ['npm'])) as run, \
                contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(check.main(['--install']), 7)
            self.assertEqual(run.call_count, 1)
            self.assertIn('--ignore-scripts', run.call_args.args[0])

    def test_fixture_rejects_wrong_count_and_drift(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'dist').mkdir()
            (root / 'src').mkdir()
            with self.assertRaisesRegex(ValueError, 'Expected 9'):
                check.check_fixture(root)
            for i in range(9):
                (root / 'dist' / f'{i}.html').write_text('')
            for name in ('app.js', 'demo-api.js', 'integration-adapters.js'):
                (root / 'src' / name).write_text('original')
                (root / 'dist' / name).write_text('original')
            with contextlib.redirect_stdout(io.StringIO()):
                check.check_fixture(root)
            (root / 'dist/app.js').write_text('changed')
            with self.assertRaisesRegex(ValueError, 'src/dist drift: app.js'):
                check.check_fixture(root)


if __name__ == '__main__':
    unittest.main()
