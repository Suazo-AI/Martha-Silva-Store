#!/usr/bin/env python3
"""Fail closed unless every backend case in the TRX files ran and passed.

Writes sanitized-results.json with counters and method names only. Test arguments,
messages, stdout and stack traces are never copied: some cases use secret-like
synthetic markers, and raw diagnostics stay on the disposable runner.
"""
import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from uuid import UUID

NS = {'t': 'http://microsoft.com/schemas/VisualStudio/TeamTest/2010'}
METHOD = re.compile(r'^[A-Za-z_][A-Za-z0-9_.]{0,300}$')
PARTITION_GROUPS = ('A', 'C', 'E')


def _in_group(partition, group):
    if group == 'C':
        return partition == 'C1' or partition.startswith('C.')
    return partition == group


def _canonical_guid(value, reason):
    try:
        identity = str(UUID(value))
    except ValueError:
        raise ValueError(reason) from None
    if identity != value.lower():
        raise ValueError(reason)
    return identity


def load_partition_expectations(manifest_path, group):
    """Read the frozen manifest and return exact expected cases for A, C or E."""
    try:
        data = json.loads(Path(manifest_path).read_text(encoding='utf-8'))
    except (OSError, ValueError):
        raise ValueError('malformed partition manifest') from None
    if not isinstance(data, dict) or data.get('schema') != 1:
        raise ValueError('malformed partition manifest')
    partitions, entries = data.get('partitions'), data.get('backend_methods')
    if not isinstance(partitions, list) or not isinstance(entries, list):
        raise ValueError('malformed partition manifest')
    known = {}
    for part in partitions:
        if not isinstance(part, dict):
            raise ValueError('malformed partition manifest')
        partition_id = part.get('id')
        if not isinstance(partition_id, str) or not partition_id or partition_id in known:
            raise ValueError('malformed manifest partition')
        known[partition_id] = part
    selected = [pid for pid in known if _in_group(pid, group)]
    for pid in selected:
        part = known[pid]
        if (not isinstance(part.get('cases'), int) or part['cases'] < 0
                or not isinstance(part.get('methods'), int) or part['methods'] < 0):
            raise ValueError('malformed manifest partition')
    expected, counts = {}, {}
    seen = set()
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError('malformed manifest method')
        method, cases = entry.get('method'), entry.get('cases')
        partition = entry.get('partition')
        if (not isinstance(method, str) or not METHOD.match(method)
                or not isinstance(cases, int) or cases <= 0 or not isinstance(partition, str)):
            raise ValueError('malformed manifest method')
        if partition not in known:
            raise ValueError('unknown manifest partition')
        if method in seen:
            raise ValueError('duplicate manifest method')
        seen.add(method)
        if _in_group(partition, group):
            expected[method] = cases
            counts.setdefault(partition, []).append(cases)
    if not selected or not expected:
        raise ValueError('manifest partition not found')
    for pid in selected:
        if (len(counts.get(pid, [])) != known[pid]['methods']
                or sum(counts.get(pid, [])) != known[pid]['cases']):
            raise ValueError('manifest partition mismatch')
    return expected


def summarize(trx_files, minimum, expected=None, partition=None):
    """Return the sanitized report. Raises ValueError on malformed or duplicate evidence."""
    if not trx_files:
        raise ValueError('no TRX files found')
    cases = {}
    executions = set()
    for path in trx_files:
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError:
            raise ValueError('malformed TRX file') from None
        for result in root.iterfind('.//t:UnitTestResult', NS):
            test_id, name = result.get('testId', ''), result.get('testName', '')
            method = name.split('(', 1)[0]
            if not METHOD.fullmatch(method):
                raise ValueError('unexpected test identity')
            test_id = _canonical_guid(test_id, 'unexpected test identity')
            if test_id in cases:
                raise ValueError('duplicate test case')
            if expected is not None:
                execution_id = result.get('executionId', '')
                if execution_id:
                    execution_id = _canonical_guid(execution_id, 'unexpected execution identity')
                    if execution_id in executions:
                        raise ValueError('duplicate execution identity')
                    executions.add(execution_id)
            cases[test_id] = (method, result.get('outcome', ''))
    methods = {}
    for method, outcome in cases.values():
        entry = methods.setdefault(method, {'cases': 0, 'passed': 0})
        entry['cases'] += 1
        entry['passed'] += outcome == 'Passed'
    passed = sum(entry['passed'] for entry in methods.values())
    report = {
        'minimumCases': minimum,
        'cases': len(cases),
        'passed': passed,
        'notPassed': len(cases) - passed,
        'methodsNotPassed': sorted(m for m, e in methods.items() if e['passed'] < e['cases']),
        'methods': dict(sorted(methods.items())),
    }
    if expected is None:
        ok = len(cases) >= minimum and passed == len(cases)
    else:
        missing = sorted(set(expected) - set(methods))
        unexpected = sorted(set(methods) - set(expected))
        multiplicity = sorted(m for m in set(expected) & set(methods)
                              if methods[m]['cases'] != expected[m])
        exact = (not missing and not unexpected and not multiplicity
                 and passed == len(cases) and len(cases) == sum(expected.values()))
        ok = exact
        report.update({
            'partition': partition,
            'expectedCases': sum(expected.values()),
            'expectedMethods': len(expected),
            'missingMethods': missing,
            'unexpectedMethods': unexpected,
            'multiplicityMismatch': multiplicity,
        })
    report['status'] = 'passed' if ok else 'failed'
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--min-tests', type=int)
    parser.add_argument('--manifest', type=Path)
    parser.add_argument('--partition', choices=PARTITION_GROUPS)
    parser.add_argument('results_dir', type=Path)
    args = parser.parse_args(argv)
    if (args.manifest is None) != (args.partition is None):
        parser.error('--manifest and --partition are required together')
    if args.partition:
        if args.min_tests is not None:
            parser.error('--min-tests cannot be combined with --manifest/--partition')
    elif args.min_tests is None:
        parser.error('--min-tests is required')
    expected, minimum = None, args.min_tests
    try:
        if args.partition:
            expected = load_partition_expectations(args.manifest, args.partition)
            minimum = sum(expected.values())
        report = summarize(sorted(args.results_dir.glob('*.trx')), minimum,
                           expected=expected, partition=args.partition)
    except (ValueError, OSError) as error:
        reason = 'unreadable TRX evidence' if isinstance(error, OSError) else str(error)
        report = {'status': 'failed', 'minimumCases': minimum, 'reason': reason}
        if args.partition:
            report.update({'expectedCases': sum(expected.values()) if expected else None,
                           'partition': args.partition})
    try:
        args.results_dir.mkdir(parents=True, exist_ok=True)
        (args.results_dir / 'sanitized-results.json').write_text(json.dumps(report, indent=2) + '\n')
    except OSError:
        print('Evidence output unavailable.')
        return 1
    label = f"Partition {args.partition}" if args.partition else 'Backend suite'
    expected_cases = report.get('expectedCases') or report.get('minimumCases') or 0
    print(f"{label}: {report['status']}; {report.get('passed', 0)}/{report.get('cases', 0)} cases passed, "
          f"expected {expected_cases}, zero skips allowed.")
    for method in report.get('methodsNotPassed', []):
        print(f'Not passed: {method}')
    for field in ('missingMethods', 'unexpectedMethods', 'multiplicityMismatch'):
        for method in report.get(field, []):
            print(f'{field}: {method}')
    if 'reason' in report:
        print(f"Reason: {report['reason']}")
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
