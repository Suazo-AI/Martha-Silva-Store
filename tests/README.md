# Recovered demo checks

Test the committed `dist/` snapshot directly; no build, server, credentials, production
service, or external media download is required. Requirements: Bash, Node.js (tested
with **24.22.1**), npm (**11.9.0**), and Python 3 (**3.12.14**, standard library only).

From the repository root:

```sh
# First run: install the lockfile's jsdom dependency tree from npm's public registry.
bash tests/check.sh --install
# Subsequent runs: offline; no dependency installation.
bash tests/check.sh
```

The runner resolves its own repository root, fails on the first unsuccessful stage,
and clears frontend baseline overrides. It verifies two byte-identical snapshot builds, checks the nine-page fixture and matching
`src/`/`dist/` app/API copies, runs 23 local-adapter backend tests, 11 jsdom DOM tests,
nine-page local asset/link/anchor/ARIA checks, and syntax for all seven JS test/source
files. The frontend dependencies are isolated under `tests/frontend-deps`; `npm ci`
uses committed package-lock versions/integrities and disables lifecycle scripts.
`node_modules/` is ignored. `--install` requires registry network access and may emit
upstream deprecation notices; it does not run an audit or claim dependency security.

Individual commands and frontend coverage details: [frontend-README.md](frontend-README.md).
For direct baseline experiments only, that suite supports `FRONTEND_APP` and
`FRONTEND_API`; the aggregate runner intentionally tests committed demo files.

## Verification record — 2026-10-24

Re-ran against recovered commit `e6299ee` on `work/recovery-qa`:

| Stage | Result |
| --- | --- |
| Locked dependency install | 39 packages installed successfully |
| Backend | 23 passed, 0 failed, 0 skipped |
| Frontend DOM simulation | 11/11 passed |
| Structure | 9 pages passed |
| JavaScript syntax | 7 files passed |
| App/API source versus published snapshot | Both pairs identical |

These are **not real-browser tests**: jsdom stubs dialog/layout/media primitives.
Rendering, responsive/iPhone behavior, accessibility interactions, performance,
network image delivery, and multi-tab locking remain unverified. No browser was
installed or automated for this recovery. Local-adapter tests do not validate real
payments, production authentication, D1, or SISFAIN.

## Build and edit

The recovered snapshot now builds with Python's standard library alone:

```sh
python3 prepare.py
bash tests/check.sh
```

See [build-inputs/README.md](../build-inputs/README.md) for editable inputs,
clean-checkout byte-equivalence verification and the historical-generator boundary.
