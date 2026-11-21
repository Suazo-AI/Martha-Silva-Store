"""Build from tracked inputs and require exact path/hash equality with dist/."""
from hashlib import sha256
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def manifest(root):
    return {str(p.relative_to(root)): sha256(p.read_bytes()).hexdigest()
            for p in root.rglob('*') if p.is_file()}


with tempfile.TemporaryDirectory(prefix='martha-build-test-') as temporary:
    output = Path(temporary) / 'dist'
    expected = manifest(ROOT / 'dist')
    inputs = manifest(ROOT / 'build-inputs/static')
    inputs.update({name: sha256((ROOT / 'src' / name).read_bytes()).hexdigest()
                   for name in ('app.js', 'demo-api.js', 'integration-adapters.js')})
    assert expected == inputs, 'Published paths/hashes differ from the complete tracked build inputs'
    for run in range(2):
        subprocess.run([sys.executable, '-S', str(ROOT / 'prepare.py'), '--output', str(output)],
                       check=True, cwd=temporary)
        actual = manifest(output)
        assert expected == actual, f'Build {run + 1} differs from committed dist snapshot'
    print(f'PASS: clean and repeat builds match all {len(expected)} paths and SHA-256 hashes')
