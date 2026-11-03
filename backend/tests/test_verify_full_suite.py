import json
import tempfile
import unittest
from pathlib import Path

import verify_full_suite as verifier

NS = 'http://microsoft.com/schemas/VisualStudio/TeamTest/2010'


def trx(*results):
    rows = ''.join(
        f'<UnitTestResult testId="{test_id}" testName="{name}" outcome="{outcome}">'
        f'<Output><StdOut>SYNTHETIC-only-secret-marker</StdOut></Output></UnitTestResult>'
        for test_id, name, outcome in results)
    return f'<TestRun xmlns="{NS}"><Results>{rows}</Results></TestRun>'


def case(n, outcome='Passed', name=None):
    return (f'00000000-0000-0000-0000-{n:012d}', name or f'Suite.Case_{n}', outcome)


class VerifyFullSuiteTests(unittest.TestCase):
    def run_dir(self, files, minimum):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            for i, content in enumerate(files):
                (directory / f'{i}.trx').write_text(content)
            code = verifier.main(['--min-tests', str(minimum), str(directory)])
            text = (directory / 'sanitized-results.json').read_text()
            return code, json.loads(text), text

    def test_all_passed_across_files(self):
        code, report, _ = self.run_dir([trx(case(1), case(2)), trx(case(3))], 3)
        self.assertEqual((code, report['status'], report['cases']), (0, 'passed', 3))

    def test_failed_or_skipped_case_fails(self):
        for outcome in ('Failed', 'NotExecuted'):
            code, report, _ = self.run_dir([trx(case(1), case(2, outcome))], 1)
            self.assertEqual((code, report['notPassed'], report['methodsNotPassed']), (1, 1, ['Suite.Case_2']))

    def test_below_minimum_fails(self):
        code, report, _ = self.run_dir([trx(case(1))], 2)
        self.assertEqual((code, report['status']), (1, 'failed'))

    def test_missing_trx_and_duplicate_case_fail_closed(self):
        self.assertEqual(self.run_dir([], 1)[0], 1)
        code, report, _ = self.run_dir([trx(case(1)), trx(case(1))], 1)
        self.assertEqual((code, report['reason']), (1, 'duplicate test case'))

    def test_arguments_and_diagnostics_never_reach_evidence(self):
        name = 'Suite.Theory(value: &quot;SYNTHETIC-only-secret-marker&quot;)'
        code, report, text = self.run_dir([trx(case(1, name=name), case(2, name=name))], 2)
        self.assertEqual(code, 0)
        self.assertEqual(report['methods'], {'Suite.Theory': {'cases': 2, 'passed': 2}})
        self.assertNotIn('SYNTHETIC', text)

    def test_unexpected_identity_fails(self):
        code, report, _ = self.run_dir([trx(('not-a-guid', 'Suite.Case', 'Passed'))], 1)
        self.assertEqual((code, report['reason']), (1, 'unexpected test identity'))


if __name__ == '__main__':
    unittest.main()
