#!/usr/bin/env bash
# Runs one stage inside the disposable runner. The Git source is mounted read-only at
# /source; a writable copy is built under /work/src so the source mount never changes.
set -euo pipefail

stage="${1:?stage required}"
src=/work/src
manifest=docs/local-validation-20261106/PARTITIONS.json

if [ ! -e "$src/.savia-copied" ]; then
  mkdir -p "$src"
  cp -a /source/. "$src"/
  : > "$src/.savia-copied"
fi
cd "$src"
# Persistent sequence gate in the disposable work volume; fail closed on repeats/reordering.
python3 tools/local-validation/evidence_gate.py sequence "$stage"

c1_filter=$(python3 - <<'PY'
import json
d = json.load(open('docs/local-validation-20261106/PARTITIONS.json', encoding='utf-8'))
print('|'.join('FullyQualifiedName=' + e['method'] for e in d['backend_methods'] if e['partition'] == 'C1'))
PY
)

crest_filter=$(python3 - <<'PY'
import json
d = json.load(open('docs/local-validation-20261106/PARTITIONS.json', encoding='utf-8'))
print('|'.join('FullyQualifiedName=' + e['method'] for e in d['backend_methods'] if e['partition'].startswith('C.')))
PY
)

case "$stage" in
  build)
    dotnet restore backend/tests/Martha.Store.Api.Tests --locked-mode
    dotnet build backend/tests/Martha.Store.Api.Tests --no-restore --configuration Release
    dotnet restore tests/golden-path/GoldenPath.Sql --locked-mode
    dotnet build tests/golden-path/GoldenPath.Sql --no-restore --configuration Release
    ;;
  c1)
    mkdir -p /work/evidence/c/results
    dotnet test backend/tests/Martha.Store.Api.Tests --no-build --no-restore --configuration Release \
      --filter "$c1_filter" \
      --logger 'trx;LogFileName=C1.trx' --results-directory /work/evidence/c/results
    python3 tools/local-validation/evidence_gate.py c1
    ;;
  crest)
    python3 tools/local-validation/evidence_gate.py c1
    mkdir -p /work/evidence/c/results
    dotnet test backend/tests/Martha.Store.Api.Tests --no-build --no-restore --configuration Release \
      --filter "$crest_filter" \
      --logger 'trx;LogFileName=C-remaining.trx' --results-directory /work/evidence/c/results
    python3 backend/tests/verify_full_suite.py --manifest "$manifest" --partition C /work/evidence/c/results
    ;;
  d)
    mkdir -p /work/evidence/d/private
    python3 tests/golden-path/golden_path.py --mode browser --no-build --supply --stock-exception \
      --playwright-directory /opt/savia-playwright/node_modules/playwright \
      --out /work/evidence/d/combined --keep-private-log /work/evidence/d/private/api.log < /dev/null
    python3 tests/golden-path/verify_evidence.py \
      --source /work/evidence/d/combined --destination /work/evidence/d/approved
    ;;
  e-release)
    mkdir -p /work/evidence/e/pilot /work/evidence/e/results
    cp backend/tests/fixtures/expected-invariants.model-derived.json \
      /work/evidence/e/pilot/expected-invariants.json
    dotnet test backend/tests/Martha.Store.Api.Tests --no-build --no-restore --configuration Release \
      --filter 'FullyQualifiedName~Real_migration_reapply_throwaway_down_up_and_actual_backup_restore' \
      --logger 'trx;LogFileName=E-release.trx' --results-directory /work/evidence/e/results
    python3 tools/local-validation/evidence_gate.py seal
    ;;
  e-restart)
    dotnet test backend/tests/Martha.Store.Api.Tests --no-build --no-restore --configuration Release \
      --filter 'FullyQualifiedName~Frozen_fixture_survives_controlled_owned_container_stop_start' \
      --logger 'trx;LogFileName=E-restart.trx' --results-directory /work/evidence/e/results
    python3 backend/tests/verify_full_suite.py --manifest "$manifest" --partition E /work/evidence/e/results
    ;;
  *)
    echo "unknown stage: $stage" >&2
    exit 2
    ;;
esac

python3 tools/local-validation/evidence_gate.py complete "$stage"
