"""Normalized declarative contract comparison, not GitHub runner execution."""
import hashlib
import json
import subprocess
from pathlib import Path
import yaml

PARENT = '51bbea4891cef23129be07cb4bab17e1247db5c5'
PR = 'c62d8286e8c3a612d305484d918467c66effb6b4'
BASE = '8744a9699812d62ea5ed31c63781748f833c3def'
MAIN = '3b0049163ece2d9431cee01f1bea624a66d9d8d4'
path = '.github/workflows/backend.yml'
def raw(ref, name):
    return subprocess.check_output(['git', 'show', f'{ref}:{name}'])
def read(ref, name):
    return yaml.load(raw(ref, name), Loader=yaml.BaseLoader)
old, new = read(PARENT, path), read(PR, path)
checks = []
def check(name, condition):
    assert condition, name
    checks.append({'case': name, 'result': 'PASS'})
check('Tony backend exactly matches historical PR2 base', raw(PARENT, path) == raw(BASE, path))
check('existing SQL job unchanged', old['jobs']['sql-server-integration'] == new['jobs']['sql-server-integration'])
before, after = old['jobs']['build-and-guards'], new['jobs']['build-and-guards']
check('all existing build guard steps preserved', before['steps'] == after['steps'][1:])
check('original build runner and timeout retained', all(after[k] == before[k] for k in ('runs-on', 'timeout-minutes')))
check('build requires new gate', after['needs'] == 'no-mistakes')
gate = new['jobs']['no-mistakes']
check('verifier only receives read permissions', gate['permissions'] == {'contents': 'read', 'pull-requests': 'read'})
check('no checkout or exemption inputs in verifier job', gate['steps'] == [{'uses': 'kunchenguid/no-mistakes/.github/actions/require-no-mistakes@5732d1ed88a1572fa6115d6ede5d69bfec097946'}])
check('body edits rerun verifier', set(new['on']['pull_request']['types']) == {'opened', 'reopened', 'synchronize', 'edited', 'ready_for_review'})
check('main push and manual triggers unchanged', all(old['on'][k] == new['on'][k] for k in ('push', 'workflow_dispatch')))
cfg = read(PR, '.no-mistakes.yaml')
check('repo shell opt-in disabled and repair budgets zero', cfg['allow_repo_commands'] == 'false' and set(cfg['auto_fix'].values()) == {'0'})
check('repair revalidation on and transient retries off', cfg['ci'] == {'revalidate_repairs': 'true', 'rerun_transient': '0'})
check('intent and media publishing disabled', cfg['pr']['publish_intent'] == 'false' and cfg['test']['evidence'] == {'store_in_repo': 'false', 'attach_media': 'false'})
bindings = []
paths = [path, '.no-mistakes.yaml', 'docs/NO-MISTAKES.md', 'docs/no-mistakes.example.yaml', 'tools/install-no-mistakes.ps1']
for ref in (PR, PARENT):
    names = paths if ref == PR else [path, 'docs/NO-MISTAKES.md', 'docs/no-mistakes.example.yaml', '.github/workflows/savia.yml', '.github/workflows/golden-path.yml', '.github/workflows/ci.yml', '.github/workflows/progress-digest.yml']
    for name in names:
        data = raw(ref, name)
        bindings.append({'commit': ref, 'path': name, 'git_blob': subprocess.check_output(['git', 'rev-parse', f'{ref}:{name}'], text=True).strip(), 'sha256': hashlib.sha256(data).hexdigest()})
print(json.dumps({'checks': checks, 'total': len(checks), 'bindings': bindings, 'runner_execution': 'NOT RUN'}, indent=2))
