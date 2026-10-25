"""Explicitly package the storefront plus SAVIA UI; never deploy or configure a backend."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
UI = Path(__file__).resolve().parent
RUNTIME = ('index.html', 'styles.css', 'app.mjs', 'model.mjs', 'api-client.mjs')


def package(output):
    output = output.resolve()
    if output == ROOT or ROOT in output.parents or output in ROOT.parents:
        raise ValueError('Use a new release directory outside this repository')
    if output.exists():
        raise ValueError('Release directory must not exist; previous releases remain intact')
    git = shutil.which('git')
    if not git:
        raise ValueError('Git must be available to identify the release source')
    sha = subprocess.check_output([git, 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    for name in RUNTIME:
        source = UI / name
        if not source.is_file() or source.is_symlink():
            raise ValueError('Missing or unsupported runtime input: ' + name)
        subprocess.run([git, 'ls-files', '--error-unmatch', source.relative_to(ROOT).as_posix()],
                       cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    subprocess.run([git, 'diff', '--quiet', 'HEAD', '--', 'src', 'build-inputs/static',
                    'dev/savia-demo-ui'], cwd=ROOT, check=True)
    subprocess.run([sys.executable, str(ROOT / 'prepare.py'), '--output', str(output)],
                   cwd=ROOT, check=True)
    target = output / 'savia'
    target.mkdir()
    for name in RUNTIME:
        shutil.copyfile(UI / name, target / name)
    # Add the demo entry only to this explicit combined release. The regular
    # storefront build does not contain /savia/ and must not publish dead links.
    for page in output.glob('*.html'):
        html = page.read_text(encoding='utf-8')
        if html.count('</footer>') != 1:
            raise ValueError('Expected exactly one storefront footer: ' + page.name)
        entry = '<p class="footer-small"><a href="/savia/" data-savia-entry="">Caja de demostraci&#243;n</a></p>'
        page.write_text(html.replace('</footer>', entry + '</footer>'), encoding='utf-8', newline='\n')
    # Version marker covers every public file, including the five allowlisted UI inputs.
    subprocess.run([sys.executable, str(ROOT / 'tools/deployment.py'), 'stamp',
                    '--directory', str(output), '--sha', sha], cwd=ROOT, check=True)
    subprocess.run([sys.executable, str(ROOT / 'tools/deployment.py'), 'verify',
                    '--directory', str(output), '--sha', sha], cwd=ROOT, check=True)
    print(json.dumps({'sha': sha, 'ui_path': '/savia/', 'ui_files': list(RUNTIME),
                      'release_files': sum(path.is_file() for path in output.rglob('*')),
                      'backend_deployed': False, 'output': str(output)}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    package(args.output)
