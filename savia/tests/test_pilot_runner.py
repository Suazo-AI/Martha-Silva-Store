"""Runner safeguards; no credentials, processes or database mutations in these tests."""
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import pilot


class PilotRunnerTests(unittest.TestCase):
    def test_connection_password_is_quoted_for_adonet(self):
        with patch.object(pilot, 'env_file_values', return_value={'MSSQL_SA_PASSWORD': 'x;"y'}), \
             patch.object(pilot.saviadb, 'docker', return_value=(0, '127.0.0.1:1433')):
            self.assertIn('Password="x;""y";', pilot.connection_string())

    def test_shared_password_requires_explicit_opt_in(self):
        with patch.dict(os.environ, {'SAVIA_PILOT_PASSWORD': 'local-test-placeholder'}, clear=True):
            with self.assertRaises(SystemExit):
                pilot.pilot_passwords()

    def test_pid_of_another_dotnet_program_is_not_killed(self):
        with patch.object(pilot.PID_FILE.__class__, 'read_text', return_value='1234'), \
             patch.object(pilot.subprocess, 'run') as run:
            run.return_value.stdout = 'dotnet unrelated.dll'
            self.assertIsNone(pilot.api_pid())

    def test_only_the_exact_pilot_dll_pid_is_recognized(self):
        with patch.object(pilot.PID_FILE.__class__, 'read_text', return_value='1234'), \
             patch.object(pilot.subprocess, 'run') as run:
            run.return_value.stdout = f'"C:/sdk/dotnet.exe" "{pilot.API_DLL}" --urls {pilot.URL}'
            self.assertEqual(1234, pilot.api_pid())
            run.return_value.stdout = f'"C:/sdk/dotnet.exe" "{pilot.API_DLL}.other"'
            self.assertIsNone(pilot.api_pid())

    def test_per_login_variables_and_explicit_shared_fallback(self):
        values = {f'SAVIA_PILOT_PASSWORD_{role}': role * 4 for role in ('CAJERA', 'SUPERVISORA', 'DUENA')}
        with patch.dict(os.environ, values, clear=True):
            self.assertEqual(values, pilot.pilot_passwords())
        with patch.dict(os.environ, {'SAVIA_PILOT_PASSWORD': 'shared-test-value', 'SAVIA_PILOT_ALLOW_SHARED': '1',
                                    'SAVIA_PILOT_PASSWORD_CAJERA': 'per-login-test-value'}, clear=True):
            result = pilot.pilot_passwords()
            self.assertEqual('per-login-test-value', result['SAVIA_PILOT_PASSWORD_CAJERA'])
            self.assertEqual('shared-test-value', result['SAVIA_PILOT_PASSWORD_DUENA'])


if __name__ == '__main__':
    unittest.main()
