"""Verification runner regressions. No SQL, API or browser is started."""
import contextlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
import uuid
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import verify


class VerifyTests(unittest.TestCase):
    def test_actual_web_step_resolves_repository_relative_imports(self):
        # Exercise the runner's real command and cwd, including sale-lifecycle.
        web = [step for step in verify.steps(True) if step[0] == 'web-tests']
        evidence_name = 'regression-' + uuid.uuid4().hex
        with patch.object(verify, 'steps', return_value=web), \
             patch.object(verify, 'git', return_value=''), \
             patch.object(verify, 'datetime') as clock, \
             patch.object(sys, 'argv', ['verify.py', '--quick']), \
             contextlib.redirect_stdout(io.StringIO()) as output:
            clock.now.return_value.strftime.return_value = evidence_name
            code = verify.main()
        evidence = verify.ROOT / '.out' / 'verify' / evidence_name
        self.assertEqual(0, code, output.getvalue() + (evidence / '01-web-tests.log').read_text(encoding='utf-8'))
        summary = json.loads((evidence / 'summary.json').read_text(encoding='utf-8'))
        self.assertEqual('PASS', summary['result'])

    def run_mocked(self, quick, fail=None):
        calls = []

        def run(command, **kwargs):
            calls.append((command, kwargs['cwd']))
            return subprocess.CompletedProcess(command, 1 if fail and fail in command else 0)

        with tempfile.TemporaryDirectory() as folder, \
             patch.object(verify, 'ROOT', Path(folder)), \
             patch.object(verify, 'git', return_value=''), \
             patch.object(verify.subprocess, 'run', side_effect=run), \
             patch.object(sys, 'argv', ['verify.py'] + (['--quick'] if quick else [])), \
             contextlib.redirect_stdout(io.StringIO()):
            code = verify.main()
            summary = json.loads(next(Path(folder).glob('.out/verify/*/summary.json')).read_text(encoding='utf-8'))
        return code, summary, calls

    def test_quick_never_invokes_full_check_or_pilot_even_on_failure(self):
        for fail in (None, 'tools/rules.py'):
            with self.subTest(fail=fail):
                code, summary, calls = self.run_mocked(True, fail)
                self.assertEqual(1 if fail else 0, code)
                self.assertEqual(['rules', 'tool-tests', 'web-format-lint', 'web-tests', 'formal'],
                                 [step['step'] for step in summary['steps']])
                self.assertEqual(3, len(calls))  # rules, Python tests, Node tests; missing tools SKIP
                self.assertFalse(any('pilot.py' in str(command) or 'check.py' in str(command)
                                     or 'docker' in str(command) for command, _ in calls))

    def test_full_mode_retains_reset_up_and_final_down(self):
        code, summary, calls = self.run_mocked(False)
        self.assertEqual(0, code)
        commands = [command for command, _ in calls]
        for args in (['tools/check.py'], ['tools/pilot.py', 'reset', '--demo'],
                     ['tools/pilot.py', 'up'], ['tools/pilot.py', 'down']):
            self.assertIn([verify.PY, *args], commands)
        self.assertEqual([verify.PY, 'tools/pilot.py', 'down'], commands[-1])
        self.assertEqual('full', summary['mode'])

    def test_failed_full_prerequisite_blocks_pilot_and_still_cleans_up(self):
        code, summary, calls = self.run_mocked(False, 'tools/check.py')
        self.assertEqual(1, code)
        self.assertTrue(all(step['verdict'] == 'BLOCKED' for step in summary['steps'][6:]))
        self.assertFalse(any(command[1:] == ['tools/pilot.py', 'reset', '--demo'] for command, _ in calls))
        self.assertEqual([verify.PY, 'tools/pilot.py', 'down'], calls[-1][0])


if __name__ == '__main__':
    unittest.main()
