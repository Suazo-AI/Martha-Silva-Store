"""Read Git blobs into disposable, non-Git DOM fixtures. Never edits product files."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

REPO = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
DEP = Path('C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules/jsdom')
SHAS = {'tony': '51bbea4891cef23129be07cb4bab17e1247db5c5',
        'pr5': 'cecdbeb05d03ccf01e8ccf74ad83eef4064c0846'}

def git(*args):
    return subprocess.check_output(['git', *args], cwd=REPO)

assert git('rev-parse', 'HEAD').decode().strip() == SHAS['tony']
assert (DEP / 'package.json').exists(), 'Existing canonical jsdom required; no installation allowed'
scratch = Path(tempfile.mkdtemp(prefix='savia-pr5-review-'))
receipt = {'scratch': str(scratch), 'jsdom_path': str(DEP),
           'jsdom_version': json.loads((DEP / 'package.json').read_text())['version'], 'runs': {}}
for label, sha in SHAS.items():
    dest = scratch / label
    files = [p for p in git('ls-tree', '-r', '--name-only', sha, 'dist').decode().splitlines()
             if p.count('/') == 1 and p.endswith(('.html', '.js'))]
    files += ['tests/frontend-runtime.cjs', 'src/app.js', 'src/demo-api.js']
    manifest = {}
    for name in files:
        content = git('show', f'{sha}:{name}')
        path = dest / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        manifest[name] = hashlib.sha256(content).hexdigest()
    test = dest / 'tests/frontend-runtime.cjs'
    original = test.read_text(encoding='utf-8')
    test.write_text(original.replace("require('./frontend-deps/node_modules/jsdom')",
                    f'require({json.dumps(str(DEP))})'), encoding='utf-8')
    result = subprocess.run(['node', str(test)], cwd=dest, capture_output=True, text=True, encoding='utf-8')
    (OUT / f'{label}-dom.log').write_text(result.stdout + result.stderr, encoding='utf-8')
    receipt['runs'][label] = {'sha': sha, 'exit': result.returncode, 'blobs_sha256': manifest,
                            'harness_only_change': 'absolute require of existing jsdom',
                            'harness_sha256': hashlib.sha256(test.read_bytes()).hexdigest()}
    print(label, sha, 'exit', result.returncode, result.stdout.splitlines()[-1:])
(OUT / 'snapshot-receipt.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
print('scratch', scratch)
