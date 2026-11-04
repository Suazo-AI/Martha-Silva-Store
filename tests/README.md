# Recovered preview checks

Verify `dist/` against reproducible builds from the local inputs. No server, credentials,
production service, or external media download is required. Requirements: Node.js (tested
with **24.22.1**), npm (**11.9.0**), and Python 3 (standard library only).

From the repository root:

```sh
# First run: install the lockfile's jsdom dependency tree from npm's public registry.
python3 tests/check.py --install
# Subsequent runs: offline; no dependency installation.
python3 tests/check.py
```

On Windows, use `python` if that is the installed command. `bash tests/check.sh`
forwards the same arguments to this runner where Bash is available.

The runner resolves its own repository root, fails on the first unsuccessful stage,
and clears frontend baseline overrides. It verifies two byte-identical snapshot builds, checks the 47-page / 40-product sample fixture and matching
`src/`/`dist/` app/API/integration-adapter copies, runs 23 local-adapter tests against the explicit two-product legacy fixture, the dual-integration adapter tests, the unchanged six-to-120 migration regressions, full-catalog/media tests, and jsdom DOM tests,
47-page local asset/link/anchor/ARIA checks, and syntax for the JS test/source
files. The frontend dependencies are isolated under `tests/frontend-deps`; `npm ci`
uses committed package-lock versions/integrities and disables lifecycle scripts.
`node_modules/` is ignored. `--install` requires registry network access and may emit
upstream deprecation notices; it does not run an audit or claim dependency security.

The served catalog preserves the captured sample prices and stock for all 40 products / 120 variants. `fixtures/legacy-catalog.json` keeps the earlier two-product inputs for recovery, totals and migration regressions; it does not replace the served catalog. `original-catalog.cjs` checks the current catalog against the captured records and `fixtures/original-store-media.json`, then requires all rendered media files to exist. The explicitly unavailable historical reference is listed in `fixtures/original-missing-media.json`; it still fails the historical `--require-complete` gate.

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

The luxury Instagram home sections also have eight focused serial checks:

```sh
node --test --test-concurrency=1 tests/luxury-editorial.cjs
```

These verify responsive media metadata, source hashes, section accessibility and
English/Spanish copy. They do not establish browser rendering or mobile QA.

The recovered snapshot now builds with Python's standard library alone:

```sh
python3 prepare.py
bash tests/check.sh
```

See [build-inputs/README.md](../build-inputs/README.md) for editable inputs,
clean-checkout byte-equivalence verification and the historical-generator boundary.

The desktop gallery candidate adds fourteen source-level DOM cases. They are
written but NOT RUN on Tony. Run them explicitly on the authorized cloud host:

```sh
node tests/desktop-gallery.cjs
```

`tests/check.py` includes this file in syntax checks, but does not execute these
cases. See [desktop-gallery-README.md](desktop-gallery-README.md) for prerequisites,
mocking limits and the required independent browser review before publication.
