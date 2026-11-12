"""Doctor contract tests use fake processes; no installs or runtime services."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('doctor', Path(__file__).resolve().parents[1] / 'tools/doctor.py')
doctor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(doctor)


class DoctorTests(unittest.TestCase):
    def item(self, **kwargs):
        return doctor.check('fake', [sys.executable, '-c', 'pass'], 'tests/test_doctor.py', **kwargs)

    def run_main(self, code, args=()):
        out = io.StringIO()
        with patch.object(doctor, 'checks', return_value=[self.item()]), patch.object(
                doctor.subprocess, 'run', return_value=subprocess.CompletedProcess([], code, '', '')), contextlib.redirect_stdout(out):
            exit_code = doctor.main(args)
        return exit_code, out.getvalue()

    def test_pass_and_exit_zero(self):
        code, text = self.run_main(0)
        self.assertEqual(code, 0)
        self.assertIn('PASS fake', text)
        self.assertNotIn('read ', text)

    def test_failure_read_next_and_exit_one(self):
        code, text = self.run_main(7)
        self.assertEqual(code, 1)
        self.assertIn('FAIL fake (exit 7) -> read tests/test_doctor.py', text)

    def test_missing_tool_never_executes(self):
        with patch.object(doctor.shutil, 'which', return_value=None), patch.object(doctor.subprocess, 'run') as run:
            result = doctor.execute(self.item(requires=('dotnet',)))
        self.assertEqual(result['status'], 'SKIPPED')
        self.assertIn('install .NET SDK 10.0.402', result['reason'])
        self.assertIsNone(result['exit_code'])
        run.assert_not_called()

    def test_missing_jsdom_has_install_hint(self):
        with tempfile.TemporaryDirectory() as directory:
            reason = doctor.missing('jsdom', Path(directory))
        self.assertIn('python tests/check.py --install', reason)

    def test_quick_skip(self):
        with patch.object(doctor.subprocess, 'run') as run:
            result = doctor.execute(self.item(slow=True), quick=True)
        self.assertEqual((result['status'], result['reason']), ('SKIPPED', 'quick mode'))
        run.assert_not_called()

    def test_json_shape_and_exit_codes(self):
        for child_code, expected in ((0, 0), (9, 1)):
            code, text = self.run_main(child_code, ['--json'])
            data = json.loads(text)
            self.assertEqual(code, expected)
            self.assertEqual(data['exit_code'], expected)
            self.assertEqual(data['schema_version'], 1)
            self.assertEqual(set(data['checks'][0]), {'name', 'status', 'reason', 'read_next', 'command', 'exit_code'})
            self.assertEqual(sum(data['summary'].values()), 1)

    def test_all_skipped_is_zero(self):
        with patch.object(doctor, 'checks', return_value=[self.item(reason='missing optional fixture')]), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(doctor.main([]), 0)

    def test_environment_removes_runtime_opt_ins_and_credentials(self):
        with patch.dict(doctor.os.environ, {'MARTHA_INTERNAL_TEST_SQL_CONNECTION': 'dummy', 'SAVIA_OWNER_RECOVERY_SQL_APPROVED': 'yes', 'EXAMPLE_TOKEN': 'dummy'}):
            env = doctor.environment('temporary-evidence')
        self.assertNotIn('MARTHA_INTERNAL_TEST_SQL_CONNECTION', env)
        self.assertNotIn('SAVIA_OWNER_RECOVERY_SQL_APPROVED', env)
        self.assertNotIn('EXAMPLE_TOKEN', env)

    def test_timeout_is_failure_with_pointer(self):
        with patch.object(doctor.subprocess, 'run', side_effect=subprocess.TimeoutExpired('fake', 900)):
            result = doctor.execute(self.item())
        self.assertEqual(result['status'], 'FAIL')
        self.assertEqual(result['read_next'], 'tests/test_doctor.py')

    def test_inventory_has_offline_boundaries(self):
        items = doctor.checks()
        self.assertTrue(any(i['name'] == 'tests/bugproof/test_prove.py' for i in items))
        browser = next(i for i in items if i['name'] == 'tests/gallery-browser-contracts.cjs')
        self.assertIn('writes evidence', browser['reason'])
        adapter = next(i for i in items if i['name'] == 'tests/integration-adapters.test.js')
        self.assertIn('no-network', adapter['reason'])
        for item in items:
            command = item['command']
            self.assertNotIn('--install', command)
            self.assertNotIn('docker', command)
            if command[0] == 'dotnet':
                self.assertIn('--no-restore', command)
                if command[1] == 'test':
                    self.assertIn('Category!=SqlServer', command)


if __name__ == '__main__':
    unittest.main()
