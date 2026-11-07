"""Source-bound local gates; delegates exact method/identity checks to frozen verifier."""
import hashlib
import importlib.util
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

CHECKS = ('real_migrator_up', 'reapply_unchanged', 'down_destroyed_fixture',
          'throwaway_up_again', 'backup_checksum', 'restore_verifyonly', 'actual_restore',
          'independent_business_expected', 'restored_business_equal', 'restored_schema_equal', 'rejections')
DB = re.compile(r'SaviaInternalTest_Pilot_[a-f0-9]{32}')
ORDER = ('build', 'c1', 'crest', 'd', 'e-release', 'e-restart')


def sequence(work, stage, commit=False):
    path = work / 'stage-order'
    done = path.read_text().splitlines() if path.exists() else []
    if done != list(ORDER[:len(done)]) or len(done) >= len(ORDER) or ORDER[len(done)] != stage:
        raise ValueError('stage order/prerequisite rejected')
    if commit:
        with path.open('a', encoding='utf-8') as out:
            out.write(stage + '\n')


def verifier(source):
    spec = importlib.util.spec_from_file_location('savia_exact_verifier', source / 'backend/tests/verify_full_suite.py')
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    return m


def exact(source, files, partition):
    v = verifier(source)
    expected = v.load_partition_expectations(source / 'docs/local-validation-20261106/PARTITIONS.json', partition)
    identities(files, v)
    report = v.summarize(files, sum(expected.values()), expected, partition)
    if report['status'] != 'passed':
        raise ValueError('exact partition evidence failed')
    return report


def identities(files, v):
    for path in files:
        for row in ET.parse(path).getroot().iterfind('.//t:UnitTestResult', v.NS):
            # Frozen aggregate verifier permits missing execution IDs; the early gate requires them.
            v._canonical_guid(row.get('executionId', ''), 'missing/noncanonical execution identity')


def hashfile(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def release_data(evidence, source):
    candidates = list((evidence / 'pilot').glob('release-*.json'))
    if len(candidates) != 1:
        raise ValueError('exactly one release metadata file required')
    data = json.loads(candidates[0].read_text(encoding='utf-8'))
    names = [data.get(k) for k in ('source', 'restored', 'throwaway_down')]
    if any(not isinstance(n, str) or not DB.fullmatch(n) for n in names) or len(set(names)) != 3:
        raise ValueError('release database guard failed')
    if not all(data.get('checks', {}).get(k) is True for k in CHECKS):
        raise ValueError('release checks incomplete')
    trx = evidence / 'results/E-release.trx'
    v = verifier(source)
    identities([trx], v)
    expected = v.load_partition_expectations(source / 'docs/local-validation-20261106/PARTITIONS.json', 'E')
    selected = {m: n for m, n in expected.items() if m.endswith('.Real_migration_reapply_throwaway_down_up_and_actual_backup_restore')}
    if len(selected) != 1 or sum(selected.values()) != 1:
        raise ValueError('release method manifest ambiguous')
    report = v.summarize([trx], 1, selected, 'E-release')
    if report['status'] != 'passed':
        raise ValueError('release TRX failed')
    return data['source'], candidates[0], trx


def seal(evidence, source, sha, nonce):
    database, raw, trx = release_data(evidence, source)
    receipt = {'sourceSha': sha, 'nonce': nonce, 'releaseSha256': hashfile(raw), 'trxSha256': hashfile(trx)}
    with (evidence / 'release-receipt.json').open('x', encoding='utf-8') as out:
        json.dump(receipt, out)


def release(evidence, source, sha, nonce):
    database, raw, trx = release_data(evidence, source)
    receipt = json.loads((evidence / 'release-receipt.json').read_text(encoding='utf-8'))
    if receipt != {'sourceSha': sha, 'nonce': nonce, 'releaseSha256': hashfile(raw), 'trxSha256': hashfile(trx)}:
        raise ValueError('release receipt source/run/hash binding mismatch')
    return database


if __name__ == '__main__':
    source = Path.cwd()
    if sys.argv[1] == 'c1':
        exact(source, [Path('/work/evidence/c/results/C1.trx')], 'C1')
    elif sys.argv[1] == 'seal':
        seal(Path('/work/evidence/e'), source, os.environ['SAVIA_SOURCE_SHA'], os.environ['SAVIA_RUN_NONCE'])
    elif sys.argv[1] in ('sequence', 'complete'):
        sequence(Path('/work'), sys.argv[2], sys.argv[1] == 'complete')
    else:
        raise SystemExit(2)
