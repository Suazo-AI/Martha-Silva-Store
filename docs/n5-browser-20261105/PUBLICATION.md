# N5 publication and exact-source CI

## Accepted negative-control publication, 2026-11-05

Primary accepts N5-COV with limits after the independent Astra/high M1 verdict.
This publication includes the exact 88eaa4 test overlay, restored-product evidence,
normal-hook-safe public artifacts and the unchanged ledger criterion.
Local checks: progress23/23, ledger24/24, ledger valid35, preserved15/15.
No product source changed. No merge, deployment, API, SQL or operational acceptance.

Remote delivery criterion for this publication: normal hooks emit SYNCED;
origin/Tony equals local HEAD; GitHub Checks for that exact SHA finish with no
failed or pending applicable job. Optional configured narrator skip is reported
separately. The primary records the observed SHA and check results in the final
handoff. Those live per-commit Checks are the authoritative CI evidence.
Earlier receipts below apply only to their recorded SHAs. Their green results
are never reused as proof for this publication. This avoids a self-referential
extra commit solely to insert its own future SHA/CI result into this file.

REVIEW-PACKET.json is historical input metadata for the independent review.
Before acceptance edits, primary archived its exact29 files and packet outside
the public repository. INTEGRATION.json contains current portable artifact hashes.

## Earlier publication history

Observed 2026-11-05 UTC on SUAZO-PC by T3 Code / Codex gpt-6.1-sol/xhigh.

Published source SHA: `0a056be612f5f3701f7a39fd37031f426bfe0dc8` on Tony.
The normal pre-commit/post-commit hooks returned SYNCED. `git ls-remote origin
refs/heads/Tony` matched that exact SHA. No PR, merge or deployment was performed.

## Exact-source CI

All six check runs completed: five success and one expected optional skip.

- [Publication integrity and reproducible build: success](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42040483071/job/127289692816).
- [Historical portable regression suite: success](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42040483071/job/127289891302). Its `python tests/check.py --install` step passed on Ubuntu.
- [Progress receipt and sync safety: success](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42040482961/job/127289697851).
- [Ledger check and deterministic digest: success](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42040482933/job/127289691889).
- [Publish digest: success](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42040482933/job/127289877832).
- [Optional AI narrator: skipped](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42040482933/job/127289879876).

Readback: `gh-axi api repos/Suazo-AI/Martha-Silva-Store/commits/0a056be612f5f3701f7a39fd37031f426bfe0dc8/check-runs`.
The local Windows symlink privilege failure remains real. The alternate Ubuntu
verification closes the portable-check gap for this source SHA without a Windows
permission or security change. Browser N5 8/8 is the primary local Chrome/mock
run; this CI receipt does not claim a browser, SQL or device rerun.

## Remaining acceptance

N5-COV remains in review. Astra/high found no material blocker; primary resolved
its two minor findings. Opus 5.5/high through Antigravity remains pending.
Its last fresh Claude/GPT availability was 0% at 13:46:34 UTC, with indicated
reset 14:03:19 UTC. Owner: primary; check fresh quota after that time before an
approved bounded review. No alternate model, credit purchase or automatic retry.

No new product defect was reproduced. No product source changed. C2/C9/C10 and
production approval remain open. The earlier CI-pending statements in the initial
review and ledger describe the pre-publication observation; this receipt closes
only that CI verification step. It does not close the independent critic gate.

## Publication-control correction

The first commit attempt rejected nine raw .log files. Primary archived those
files outside the repository and published reviewed structured totals/hashes.
The next normal-hook attempt succeeded. No hook, filter or trust setting changed.
See EXECUTION-SUMMARY.json for the original log hashes and bounded archive paths.
