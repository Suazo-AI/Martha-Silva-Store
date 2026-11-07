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


def partition_manifest(parts):
    partitions, entries = [], []
    for partition_id, methods in parts:
        partitions.append({'id': partition_id, 'cases': sum(methods.values()),
                           'methods': len(methods)})
        for method, count in methods.items():
            entries.append({'method': method, 'cases': count, 'attribute': 'Fact',
                            'source': 'synthetic', 'partition': partition_id})
    return {'schema': 1, 'partitions': partitions, 'backend_methods': entries}


class VerifyFullSuiteTests(unittest.TestCase):
    def run_dir(self, files, minimum):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            for i, content in enumerate(files):
                (directory / f'{i}.trx').write_text(content)
            code = verifier.main(['--min-tests', str(minimum), str(directory)])
            text = (directory / 'sanitized-results.json').read_text()
            return code, json.loads(text), text

    def run_partition(self, files, parts, group='A', manifest=None):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            results = directory / 'results'
            results.mkdir()
            for i, content in enumerate(files):
                (results / f'{i}.trx').write_text(content)
            manifest_path = directory / 'PARTITIONS.json'
            manifest_path.write_text(json.dumps(manifest or partition_manifest(parts)))
            code = verifier.main(['--manifest', str(manifest_path),
                                  '--partition', group, str(results)])
            text = (results / 'sanitized-results.json').read_text()
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

    def test_partition_accepts_exact_method_multiplicity(self):
        parts = [('A', {'Suite.Alpha': 1, 'Suite.Beta': 2})]
        code, report, _ = self.run_partition(
            [trx(case(1, name='Suite.Alpha'), case(2, name='Suite.Beta')),
             trx(case(3, name='Suite.Beta'))], parts)
        self.assertEqual((code, report['status'], report['cases']), (0, 'passed', 3))
        self.assertEqual(report['methods'], {'Suite.Alpha': {'cases': 1, 'passed': 1},
                                             'Suite.Beta': {'cases': 2, 'passed': 2}})

    def test_partition_missing_method_or_occurrence_fails(self):
        parts = [('A', {'Suite.Alpha': 1, 'Suite.Beta': 2})]
        code, report, _ = self.run_partition([trx(case(1, name='Suite.Alpha'))], parts)
        self.assertEqual((code, report['missingMethods']), (1, ['Suite.Beta']))
        code, report, _ = self.run_partition(
            [trx(case(1, name='Suite.Alpha'), case(2, name='Suite.Beta'))], parts)
        self.assertEqual((code, report['multiplicityMismatch']), (1, ['Suite.Beta']))

    def test_partition_extra_method_fails(self):
        parts = [('A', {'Suite.Alpha': 1})]
        code, report, _ = self.run_partition(
            [trx(case(1, name='Suite.Alpha'), case(2, name='Suite.Gamma'))], parts)
        self.assertEqual((code, report['unexpectedMethods']), (1, ['Suite.Gamma']))

    def test_partition_failed_or_skipped_fails(self):
        parts = [('A', {'Suite.Alpha': 2})]
        for outcome in ('Failed', 'NotExecuted'):
            code, report, _ = self.run_partition(
                [trx(case(1, name='Suite.Alpha'), case(2, name='Suite.Alpha', outcome=outcome))], parts)
            self.assertEqual((code, report['status'], report['notPassed']), (1, 'failed', 1))

    def test_partition_duplicate_identity_fails(self):
        parts = [('A', {'Suite.Alpha': 2})]
        code, report, _ = self.run_partition(
            [trx(case(1, name='Suite.Alpha')), trx(case(1, name='Suite.Alpha'))], parts)
        self.assertEqual((code, report['reason']), (1, 'duplicate test case'))

    def test_partition_groups_aggregate_only_their_manifest_rows(self):
        parts = [('C1', {'Suite.C1': 1}), ('C.Internal', {'Suite.C2': 2}),
                 ('A', {'Suite.Alpha': 1}), ('E', {'Suite.Echo': 1})]
        code, report, _ = self.run_partition(
            [trx(case(1, name='Suite.C1'), case(2, name='Suite.C2'),
                 case(3, name='Suite.C2'))], parts, group='C')
        self.assertEqual((code, report['partition'], report['cases']), (0, 'C', 3))
        code, report, _ = self.run_partition([trx(case(4, name='Suite.Alpha'))], parts, group='A')
        self.assertEqual(code, 0)
        code, report, _ = self.run_partition([trx(case(5, name='Suite.C1'))], parts, group='A')
        self.assertEqual((code, report['unexpectedMethods']), (1, ['Suite.C1']))

    def test_partition_manifest_is_fail_closed(self):
        parts = [('A', {'Suite.Alpha': 1})]
        cases = [trx(case(1, name='Suite.Alpha'))]
        code, report, _ = self.run_partition(cases, parts, manifest={'schema': 1})
        self.assertEqual((code, report['reason']), (1, 'malformed partition manifest'))
        unknown = partition_manifest(parts)
        unknown['backend_methods'][0]['partition'] = 'Z'
        code, report, _ = self.run_partition(cases, parts, manifest=unknown)
        self.assertEqual((code, report['reason']), (1, 'unknown manifest partition'))
        duplicate = partition_manifest(parts)
        duplicate['backend_methods'].append(dict(duplicate['backend_methods'][0], cases=2))
        code, report, _ = self.run_partition(cases, parts, manifest=duplicate)
        self.assertEqual((code, report['reason']), (1, 'duplicate manifest method'))
        mismatch = partition_manifest(parts)
        mismatch['partitions'][0]['cases'] = 2
        code, report, _ = self.run_partition(cases, parts, manifest=mismatch)
        self.assertEqual((code, report['reason']), (1, 'manifest partition mismatch'))

    def test_partition_evidence_is_sanitized(self):
        parts = [('A', {'Suite.Theory': 2})]
        name = 'Suite.Theory(value: &quot;SYNTHETIC-only-secret-marker&quot;)'
        code, report, text = self.run_partition(
            [trx(case(1, name=name), case(2, name=name))], parts)
        self.assertEqual(code, 0)
        self.assertNotIn('SYNTHETIC', text)
        self.assertEqual(report['methods'], {'Suite.Theory': {'cases': 2, 'passed': 2}})

    def test_partition_corrupted_fixture_exits_nonzero(self):
        parts = [('A', {'Suite.Alpha': 1, 'Suite.Beta': 1})]
        intact = [trx(case(1, name='Suite.Alpha'), case(2, name='Suite.Beta'))]
        corrupted = [trx(case(1, name='Suite.Alpha'))]
        self.assertEqual(self.run_partition(intact, parts)[0], 0)
        self.assertEqual(self.run_partition(corrupted, parts)[0], 1)

    def test_frozen_manifest_a_complete_inventory_accepted(self):
        path = Path(__file__).resolve().parents[2] / 'docs/local-validation-20261106/PARTITIONS.json'
        manifest = json.loads(path.read_text(encoding='utf-8'))
        expected = verifier.load_partition_expectations(path, 'A')
        self.assertEqual((len(expected), sum(expected.values())), (195, 552))
        rows, n = [], 0
        for method, count in expected.items():
            for _ in range(count):
                n += 1
                rows.append((f'{n:08d}-0000-0000-0000-000000000000', method, 'Passed'))
        half = len(rows) // 2
        code, report, _ = self.run_partition(
            [trx(*rows[:half]), trx(*rows[half:])], None, manifest=manifest)
        self.assertEqual((code, report['cases'], report['expectedCases']), (0, 552, 552))
        code, report, _ = self.run_partition(
            [trx(*rows[:-1])], None, manifest=manifest)
        self.assertEqual((code, len(report['multiplicityMismatch'])), (1, 1))


if __name__ == '__main__':
    unittest.main()
