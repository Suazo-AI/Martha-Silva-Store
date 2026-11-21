"""Offline negative controls; no successful PR attestation is manufactured.

Usage: python check_contract.py --verifier <pinned upstream verify.py>
"""
import argparse
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
from unittest.mock import patch

p = argparse.ArgumentParser()
p.add_argument('--verifier', required=True)
args = p.parse_args()
source = Path(args.verifier)
raw = source.read_bytes()
assert hashlib.sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest() == '7379e69d406e60c0879d6ed93c23cbd5cf10fbf8'
spec = importlib.util.spec_from_file_location('upstream_verify', source)
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)
facts = type('Facts', (), {'body': '', 'author': 'offline-control', 'head_sha': 'c62d8286e8c3a612d305484d918467c66effb6b4'})()
checks = []

def rejected(name, action, diagnostic):
    out, err = io.StringIO(), io.StringIO()
    with patch.dict(os.environ, {}, clear=True), contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        try:
            action()
        except SystemExit as e:
            assert e.code == 1, (name, e.code)
        else:
            raise AssertionError(f'{name}: unexpectedly accepted')
    assert diagnostic in err.getvalue(), (name, err.getvalue())
    checks.append({'case': name, 'result': 'PASS', 'observed_exit': 1})

evidence = json.loads((Path(__file__).parent / 'source-evidence.json').read_text(encoding='utf-8'))
body = evidence['pr']['body']
def actual_body():
    with patch.dict(os.environ, {'PR_BODY': body, 'PR_HEAD_SHA': facts.head_sha}, clear=True):
        v.main()
rejected('actual PR6 body rejects missing signature', actual_body, 'This PR was not raised through no-mistakes.')
rejected('API unavailable fails closed without explicit facts', v.main, "Could not verify this PR's live body/head")
rejected('empty body lacks parser attestation', lambda: v.parse_attestation(facts), 'missing structured pipeline step attestation')
rejected('different current head rejects stale bind', lambda: v.check_head_bind(facts, '0' * 40), 'does not match the current PR head')
rejected('missing head rejects empty bind', lambda: v.check_head_bind(facts, ''), 'does not match the current PR head')
rejected('missing required phases reject', lambda: v.check_required_steps(facts, []), 'not completed')
for state in ('failed', 'skipped', 'skipped_quota', 'running'):
    steps = [{'step': name, 'status': state if name == 'test' else 'completed'} for name in ('review', 'test', 'document')]
    rejected(f'test {state} rejects', lambda steps=steps: v.check_required_steps(facts, steps), 'not completed')
rejected('test command override without opt-in rejects', lambda: v.check_test_command_override(facts, {'steps': [{'step': 'test', 'override_reason': 'offline negative control'}]}), 'without a recorded repository opt-in')
print(json.dumps({'verifier_git_blob': '7379e69d406e60c0879d6ed93c23cbd5cf10fbf8', 'verifier_sha256': hashlib.sha256(raw).hexdigest(), 'checks': checks, 'total': len(checks), 'authentic_positive_pipeline': 'NOT RUN'}, indent=2))
