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

NS = {'t': 'http://microsoft.com/schemas/VisualStudio/TeamTest/2010'}
METHOD = re.compile(r'^[A-Za-z_][A-Za-z0-9_.]{0,300}$')
TEST_ID = re.compile(r'^[0-9a-fA-F-]{36}$')


def summarize(trx_files, minimum):
    """Return the sanitized report. Raises ValueError on malformed or duplicate evidence."""
    if not trx_files:
        raise ValueError('no TRX files found')
    cases = {}
    for path in trx_files:
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError:
            raise ValueError('malformed TRX file') from None
        for result in root.iterfind('.//t:UnitTestResult', NS):
            test_id, name = result.get('testId', ''), result.get('testName', '')
            method = name.split('(', 1)[0]
            if not TEST_ID.match(test_id) or not METHOD.match(method):
                raise ValueError('unexpected test identity')
            if test_id in cases:
                raise ValueError('duplicate test case')
            cases[test_id] = (method, result.get('outcome', ''))
    methods = {}
    for method, outcome in cases.values():
        entry = methods.setdefault(method, {'cases': 0, 'passed': 0})
        entry['cases'] += 1
        entry['passed'] += outcome == 'Passed'
    passed = sum(entry['passed'] for entry in methods.values())
    ok = len(cases) >= minimum and passed == len(cases)
    return {
        'status': 'passed' if ok else 'failed',
        'minimumCases': minimum,
        'cases': len(cases),
        'passed': passed,
        'notPassed': len(cases) - passed,
        'methodsNotPassed': sorted(m for m, e in methods.items() if e['passed'] < e['cases']),
        'methods': dict(sorted(methods.items())),
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--min-tests', type=int, required=True)
    parser.add_argument('results_dir', type=Path)
    args = parser.parse_args(argv)
    try:
        report = summarize(sorted(args.results_dir.glob('*.trx')), args.min_tests)
    except (ValueError, OSError) as error:
        report = {'status': 'failed', 'minimumCases': args.min_tests, 'reason': str(error)}
    args.results_dir.mkdir(parents=True, exist_ok=True)
    (args.results_dir / 'sanitized-results.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f"Backend suite: {report['status']}; {report.get('passed', 0)}/{report.get('cases', 0)} cases passed, "
          f"minimum {args.min_tests}, zero skips allowed.")
    for method in report.get('methodsNotPassed', []):
        print(f'Not passed: {method}')
    if 'reason' in report:
        print(f"Reason: {report['reason']}")
    return 0 if report['status'] == 'passed' else 1


if __name__ == '__main__':
    sys.exit(main())
