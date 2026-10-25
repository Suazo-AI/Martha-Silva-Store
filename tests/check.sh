#!/usr/bin/env bash
# Keep Bash and Windows QA on the same portable, fail-fast runner.
set -euo pipefail
exec python3 "$(dirname "${BASH_SOURCE[0]}")/check.py" "$@"
