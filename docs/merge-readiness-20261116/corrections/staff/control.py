"""Offline disposable controls. Never writes product source or cached dependencies."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

sys.stdout.reconfigure(encoding='utf-8')

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = 'ba8ff2ba10935e99fc268ebbe5eae130f72c1cca'
TEST = ROOT / 'dev/savia-staff-ui/cash.test.mjs'
PRODUCT = ROOT / 'dev/savia-staff-ui/cash.mjs'
NAME = 'mounted cash sale double submit locks synchronously and refreshes current reads'

def absolute_refs(source, folder):
    return re.sub(r"(['\"])(\./[^'\"]+)\1", lambda m: m[1] + (folder / m[2]).resolve().as_uri() + m[1], source)

mode = sys.argv[1]
before = PRODUCT.read_bytes()
with tempfile.TemporaryDirectory(prefix='disposable-', dir=HERE) as scratch:
    scratch = Path(scratch)
    if mode == 'red':
        source = subprocess.check_output(['git', 'show', f'{BASE}:dev/savia-staff-ui/cash.test.mjs'], cwd=ROOT).decode()
        needle = "Object.defineProperty(dom.window.crypto,'subtle',{value:webcrypto.subtle});let reads"
        replacement = "Object.defineProperty(dom.window.crypto,'subtle',{value:{digest:async()=>{console.log('CONTROL: real SHA-256 preparation reached and held');await new Promise(()=>{});}}});let reads"
        assert source.count(needle) == 1
        source = source.replace(needle, replacement)
    elif mode == 'negative':
        source = TEST.read_text(encoding='utf-8')
        product = before.decode()
        needle = "async function begin(kind,body,evidence){if(!usable())return;const a=getSession(),e=epoch;busy=true;lock();"
        assert product.count(needle) == 1
        product = product.replace(needle, needle.replace('busy=true;lock();', '/* disposable mutation: synchronous lock removed */'))
        mutant = scratch / 'cash.mjs'
        mutant.write_text(absolute_refs(product, PRODUCT.parent), encoding='utf-8', newline='\n')
        source = source.replace("from './cash.mjs'", f"from '{mutant.as_uri()}'")
    else:
        raise ValueError(mode)
    target = scratch / 'cash.test.mjs'
    target.write_text(absolute_refs(source, TEST.parent), encoding='utf-8', newline='\n')
    env = dict(os.environ, NODE_PATH='C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules')
    command = ['node', '--test', '--test-name-pattern', NAME, str(target)]
    run = subprocess.run(command, cwd=ROOT, env=env, capture_output=True, text=True, encoding='utf-8', timeout=15)
    output = run.stdout + run.stderr
    (HERE / f'{mode}.log').write_text(output, encoding='utf-8', newline='\n')
    expected = 'release is not a function' if mode == 'red' else 'sale locks before awaiting preparation'
    matched = run.returncode != 0 and expected in output
    unchanged = before == PRODUCT.read_bytes()
    result = dict(mode=mode, command=command, exit=run.returncode, expected=expected, detected=matched,
                  product_raw_sha256=hashlib.sha256(before).hexdigest(), product_unchanged=unchanged,
                  disposable_cleanup='TemporaryDirectory removed on exit')
    (HERE / f'{mode}.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(json.dumps(result))
    print(output[-2400:])
    assert matched and unchanged
