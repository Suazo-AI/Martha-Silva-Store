import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

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
        self.assertEqual(report['methods'],
                         {'Suite.Theory': {'cases': 2, 'passed': 2, 'skipped': 0, 'failed': 0}})
        self.assertNotIn('SYNTHETIC', text)

    def test_documented_platform_skip_is_accepted_and_reported(self):
        method = 'Martha.Store.Api.Tests.InternalOwnerRecoverySqlTests.Host_only_case'
        code, report, _ = self.run_dir([trx(case(1, 'NotExecuted', name=method))], 1)
        self.assertEqual((code, report['status']), (0, 'passed'))
        self.assertIn(method, report['platformSkipped'])
        self.assertEqual(report['platformSkipped'][method]['skipped'], 1)
        self.assertNotIn(method, report['methodsNotPassed'])

    def test_platform_skip_never_excuses_a_failure(self):
        method = 'Martha.Store.Api.Tests.InternalOwnerRecoverySqlTests.Host_only_case'
        code, report, _ = self.run_dir([trx(case(1, 'Failed', name=method))], 1)
        self.assertEqual((code, report['status'], report['methodsNotPassed']), (1, 'failed', [method]))
        self.assertNotIn(method, report['platformSkipped'])

    def test_unexpected_identity_fails(self):
        code, report, _ = self.run_dir([trx(('not-a-guid', 'Suite.Case', 'Passed'))], 1)
        self.assertEqual((code, report['reason']), (1, 'unexpected test identity'))

    def test_equivalent_test_guids_fail_in_both_modes(self):
        identity = 'abcdef00-0000-0000-0000-000000000001'
        files = [trx((identity, 'Suite.Alpha', 'Passed')),
                 trx((identity.upper(), 'Suite.Alpha', 'Passed'))]
        for run in (lambda: self.run_dir(files, 2),
                    lambda: self.run_partition(files, [('A', {'Suite.Alpha': 2})])):
            code, report, _ = run()
            self.assertEqual((code, report.get('reason')), (1, 'duplicate test case'))
        malformed = '-' * 36
        code, report, _ = self.run_dir([trx((malformed, 'Suite.Alpha', 'Passed'))], 1)
        self.assertEqual((code, report.get('reason')), (1, 'unexpected test identity'))

    def test_partition_execution_guids_are_validated_and_canonicalized(self):
        identity = 'fedcba00-0000-0000-0000-000000000001'
        parts = [('A', {'Suite.Alpha': 2})]
        first = trx(case(1, name='Suite.Alpha')).replace(
            '<UnitTestResult ', f'<UnitTestResult executionId="{identity}" ')
        for second_id, reason in ((identity.upper(), 'duplicate execution identity'),
                                  ('not-a-guid', 'unexpected execution identity')):
            second = trx(case(2, name='Suite.Alpha')).replace(
                '<UnitTestResult ', f'<UnitTestResult executionId="{second_id}" ')
            code, report, _ = self.run_partition([first, second], parts)
            self.assertEqual((code, report.get('reason')), (1, reason))

    def test_cli_requires_complete_and_exclusive_partition_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            combinations = [
                ['--manifest', 'unused.json', '--min-tests', '1'],
                ['--manifest', 'unused.json'],
                ['--partition', 'A'],
                ['--manifest', 'unused.json', '--partition', 'A', '--min-tests', '1'],
            ]
            for index, arguments in enumerate(combinations):
                results = Path(tmp) / str(index)
                with self.subTest(arguments=arguments), contextlib.redirect_stderr(io.StringIO()):
                    with self.assertRaises(SystemExit) as result:
                        verifier.main([*arguments, str(results)])
                    self.assertEqual(result.exception.code, 2)
                self.assertFalse((results / 'sanitized-results.json').exists())

    def test_filesystem_diagnostics_never_reach_evidence_or_stdout(self):
        marker = 'SYNTHETIC_ONLY_SECRET_MARKER'
        for mode in ('legacy', 'partition'):
            with self.subTest(mode=mode):
                output = io.StringIO()
                with patch.object(verifier.ET, 'parse', side_effect=FileNotFoundError(
                        2, marker, marker + '.trx')), contextlib.redirect_stdout(output):
                    if mode == 'legacy':
                        code, report, text = self.run_dir([trx(case(1))], 1)
                    else:
                        code, report, text = self.run_partition(
                            [trx(case(1, name='Suite.Alpha'))], [('A', {'Suite.Alpha': 1})])
                self.assertEqual((code, report.get('reason')), (1, 'unreadable TRX evidence'))
                self.assertNotIn(marker, text + output.getvalue())
                self.assertNotIn('Errno', text + output.getvalue())

    def test_output_filesystem_error_is_sanitized(self):
        marker = 'SYNTHETIC_ONLY_SECRET_MARKER'
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / 'valid.trx').write_text(trx(case(1)))
            output = io.StringIO()
            with patch.object(Path, 'write_text', side_effect=OSError(13, marker)), \
                    contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                code = verifier.main(['--min-tests', '1', tmp])
            self.assertEqual(code, 1)
            self.assertEqual(output.getvalue(), 'Evidence output unavailable.\n')
            self.assertNotIn(marker, output.getvalue())

    def test_partition_accepts_exact_method_multiplicity(self):
        parts = [('A', {'Suite.Alpha': 1, 'Suite.Beta': 2})]
        code, report, _ = self.run_partition(
            [trx(case(1, name='Suite.Alpha'), case(2, name='Suite.Beta')),
             trx(case(3, name='Suite.Beta'))], parts)
        self.assertEqual((code, report['status'], report['cases']), (0, 'passed', 3))
        self.assertEqual(report['methods'], {'Suite.Alpha': {'cases': 1, 'passed': 1, 'skipped': 0, 'failed': 0},
                                             'Suite.Beta': {'cases': 2, 'passed': 2, 'skipped': 0, 'failed': 0}})

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
        self.assertEqual(report['methods'], {'Suite.Theory': {'cases': 2, 'passed': 2, 'skipped': 0, 'failed': 0}})

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
        repeated = next(method for method, count in expected.items() if count > 1)
        indexes = [i for i, row in enumerate(rows) if row[1] == repeated][:2]
        duplicate_rows = list(rows)
        identity = 'abcdef00-0000-0000-0000-000000000001'
        for index, guid in zip(indexes, (identity, identity.upper())):
            duplicate_rows[index] = (guid, repeated, 'Passed')
        code, report, _ = self.run_partition(
            [trx(*duplicate_rows)], None, manifest=manifest)
        self.assertEqual((code, report.get('reason')), (1, 'duplicate test case'))
        code, report, _ = self.run_partition(
            [trx(*rows[:-1])], None, manifest=manifest)
        self.assertEqual((code, len(report['multiplicityMismatch'])), (1, 1))


if __name__ == '__main__':
    unittest.main()
