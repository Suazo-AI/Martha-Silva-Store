#!/usr/bin/env bash
# Offline checks by default; --install explicitly installs locked DOM dependencies.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if [[ $# -gt 1 || (${1:-} != '' && ${1:-} != '--install') ]]; then
  echo 'Usage: bash tests/check.sh [--install]' >&2
  exit 2
fi
if [[ ${1:-} == '--install' ]]; then
  npm ci --prefix tests/frontend-deps --registry=https://registry.npmjs.org \
    --ignore-scripts --no-audit --no-fund
fi
if [[ ! -f tests/frontend-deps/node_modules/jsdom/package.json ]]; then
  echo 'Missing jsdom: run bash tests/check.sh --install first.' >&2
  exit 2
fi
# Do not accidentally label a baseline override run as recovered-demo QA.
unset FRONTEND_APP FRONTEND_API
node --version
python3 --version
printf '\n== Reproducible snapshot build ==\n'
python3 tests/build.py
printf '\n== Recovered fixture ==\n'
python3 - <<'PY'
from pathlib import Path
pages = sorted(Path('dist').glob('*.html'))
assert len(pages) == 9, f'Expected 9 recovered pages, found {len(pages)}'
for name in ('app.js', 'demo-api.js'):
    assert (Path('src') / name).read_bytes() == (Path('dist') / name).read_bytes(), f'src/dist drift: {name}'
print('PASS: 9 pages; src/dist app.js and demo-api.js match')
PY
printf '\n== Backend simulation ==\n'
node --test tests/backend.cjs
printf '\n== Catalog expansion regression ==\n'
node --test tests/catalog-migration.cjs
printf '\n== Asset audit regression (not full catalog completion) ==\n'
python3 tests/asset-audit.py
printf '\n== Frontend DOM simulation (not a browser) ==\n'
node tests/frontend-runtime.cjs
printf '\n== Local HTML structure ==\n'
python3 tests/structure.py
printf '\n== JavaScript syntax ==\n'
files=(src/*.js dist/*.js tests/*.cjs)
for file in "${files[@]}"; do node --check "$file"; done
printf 'PASS: syntax (%s JavaScript files)\n' "${#files[@]}"
printf '\nPASS: all recovered-demo automated checks\n'
