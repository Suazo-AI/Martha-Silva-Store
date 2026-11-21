# Luxury candidate automated evidence

Execution is in the cloud workspace, **not Suazo PC or the laptop**. No deployment,
Git push, stock operation, SQL, payment integration or original-site mutation is
performed here.

## Final candidate: complete baseline, automated checks passed

All four supplied ZIP archives matched their announced hashes. Their 784 payloads
were validated against the runtime baseline before import; together with 13 reused
local files, all **797 baseline binary assets** matched exactly. No source text was
overwritten and no network access was used by the importer.

The final serial commands passed: `python3 prepare.py`, `python3 tests/check.py`,
`node --test tests/luxury-editorial.cjs`, `python3 tests/test_deployment.py`, and the
ordinary asset audit. There were **161 passing automated cases, zero failures and
zero skips** (139 existing runner + 14 offline deployment + 8 new luxury).
Two clean/repeat builds matched all 902 paths and hashes. The offline deployment
test's printed remote-smoke success comes from mocks, **not a live HTTP test**.

`runtime-final.json` contains **902 outputs / 134,018,632 bytes**: 855 unchanged
baseline files, three changed text outputs and 44 new derivatives, with zero
source-to-dist mismatches. It records SHA-256, byte count, Cloudflare upload hash
and source mapping for every path. No deployment marker is included (a separate
marker would bring an artifact to 903 files; none was generated here).

- Runtime manifest SHA-256: `c5a8b2e146e6d076415d36182547fd8a4f390919b4d0a65b2ba702f72d499a41`
- Canonical build-input mapping SHA-256: `d1eaae834dfdc5eb0ccb0af13b4a9ef40ba3f57fd85e675c4f4861ebbd8d8690`
- Final CSS SHA-256: `7718cbe95874c8f0eed9747154c35c7305ef118b3f33be8203bde98588d0a109`
- Final source comparison: `included-source-diff.json` (actual bytes after tests).
- Commands, exits and timings: `final-test-stages.json`; full runner 76.433 seconds,
  cumulative child peak RSS 1,774,368 KiB. No simultaneous image conversion or
  browser suite. The optional `/usr/bin/time` harness initially failed before
  execution because that binary was absent; standard-library measurement replaced it.

Historical completeness remains **777/778**, with exactly the known missing
`/research/assets/martha-gala/f1bf4e3664d34cd4.jpg`. Thus the explicitly stricter
`--require-complete` command exits 1 as expected; no substitute was created. The
40 products / 120 sample variants / 170 gallery positions and catalog bytes remain
unchanged. These are not commercial inventory, production auth or payment tests.

**Real-browser responsive, accessibility-interaction and visual acceptance remains
independent and pending**. Automated jsdom/image-header checks are not that evidence.

## Historical first candidate: incomplete, now superseded

- The live preview marker was fetched once with normal curl and exactly matched
  source `67d4647d5ee65c65dd037d2e664fcdc45c7009d6` and all 858 baseline SHA-256 entries.
- Thirteen missing binary files were reused from matching local files. Transfer of
  the other 784 files was blocked before execution by auto-review. A scoped
  authorization submission then failed during sandbox setup, also before execution.
  No alternative origin/client or further retry was used. `recovery-blocker.json`
  and `baseline-missing-supply.json` record the remaining supplied-file requirement.
- `prepare-partial.log`: exit 0, 47 pages / 40 products / 118 available output files.
  Missing old fonts and media prevent final visual/completeness acceptance.
- `luxury-editorial-partial-r2.log`: 8 passed, 0 failed, 0 skipped. The first run
  (`luxury-editorial-partial.log`) had one test-authoring error: valid `es-NI` was
  compared with exact `es`. Only the new test was corrected to accept Spanish tags.
- `runtime-partial.json`: exact hashes, bytes, Cloudflare upload hashes and input
  paths; `complete_baseline_present` is explicitly false. The source mapping is
  byte-identical for every output. This is **not a deployment marker**.
- Locked jsdom install initially failed because npm's default home cache could not
  be created. The same `npm ci --ignore-scripts --no-audit --no-fund` with writable
  `/tmp/martha-luxury-npm-cache` succeeded. Both logs are retained.

## Focused test

```sh
python3 prepare.py
node --test tests/luxury-editorial.cjs
```

The eight cases cover the new sections, lead/lazy priorities, all 44 derivative
byte hashes and decoded **header dimensions**, source-identity/whole-frame ratios,
responsive markup, six authentic source links without catalog bindings, scoped
contain/focus/reduced-motion declarations, every new visible/accessible English
translation and Spanish restoration, and unchanged catalog SHA / 40 products /
120 sample variants / 170 gallery positions.

These tests use **jsdom, not a real browser**. CSS declarations are not proof of
rendered geometry; header parsing is not a browser image decode. Independent
browser evidence is required, especially after the old fonts/media are restored.
The new test does not change or weaken assertions in the existing regression suite.

## Remaining acceptance boundary

Use only the final evidence for the complete candidate, not the files explicitly
named `partial`. If browser review leads to source edits, rebuild and rerun affected
checks and regenerate exact-byte evidence before calling the changed candidate
verified. Publication, source commit/push and marker generation are outside this
test owner's completed work.
