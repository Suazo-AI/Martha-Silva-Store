# Primary inspection: final responsive candidate

Date: 2026-11-05 UTC. Host: SUAZO-PC. Primary: T3 Code / Codex / gpt-6.1-sol, xhigh.
Disposition: source/evidence inspected; independent review and integrated Linux verification pending.
This is not production acceptance or a claim that the full Windows suite passed.

## Frozen candidate

Worker checkout: `C:/Users/Jason/.t3/worktrees/github/t3-3e335278`.
Base and returned HEAD: `6f304a7571a554bb8968e081a14985829aee3dfb`.
Candidate changes are unstaged; HEAD alone does not identify them.
Worker report: `docs/release-20261105/responsive-followup/README.md` in that checkout.
Execution selection: Codex `gpt-6.1-sol`, explicit `reasoningEffort: high`; worker reports effective high.

| Artifact in responsive-followup | RAW SHA256 |
| --- | --- |
| source-manifest.json | 691b0043f655b0febbbe9d16fab5140f68c99874354b284e4eda38ee2abc3649 |
| changed-paths.json | 4ed009e15136e78ff16dd6c48fc126ff3a4dd1b7894c2b95090cefde94c0b7b6 |
| RESULT.json | b78c699cab53a4f7f017c8110a0cfb498a00e0eaceecd6c29d6808b3a4f544c3 |
| commands.json | ffc266fd6435499e2f2345e7a6a59fbf24861a54aa30e6ccc0cc0e9985277ea6 |
| private-files.json | 4bf848b1c39357cd5649b9b0b8f8938bf49c2372543621c2e0f41791d4feb3c9 |
| recordings.json | 5e4c08c53f22c92699b976c15f8421771c0ff4d22a67030da16d71d61705911c |
| measurement.json | 1dde265cad1b02275bf42045d24823337bdc03af1c6b16e81d21bbca9630c73a |

## Direct inspection

- Recomputed 3,127 RAW file hashes and their portable hashes: zero mismatches.
- Recomputed all 34 private-file hashes and all 12 video hashes: zero mismatches.
- Bound 346 before and 346 after served responses to each phase's frozen source manifest: zero mismatches.
- Compared all 3,125 after-phase sources with current worker bytes: zero mismatches.
- Inspected the font generator, full-font comparison, font regression, CSS diff and editorial-test diff against the base.
- Inspected the immutable 20261030 release contracts used by the editorial test. Existing catalog contracts remain a separate regression oracle.
- Decoded private command logs, including the actual WinError1314 stack traces and the final 18/18 editorial/catalog and 5/5 staff summaries.
- Re-extracted twelve frames directly from the bound videos at 4.000 seconds. Every extracted frame has the same pixels as the worker's corresponding frame.
- Viewed the six before/after pairs for mobile and desktop index, catalog and Amarillo product. Sampled composition and legible typography are preserved.

Primary machine receipt and extracted frames remain outside Git:
`C:/Users/Jason/AppData/Local/Temp/savia-primary-responsive-review-20261105/followup-primary-checks.json`.
This inspection did not rerun the historical browser sessions or suites.
Frame sampling does not establish temporal, audio, accessibility or physical-device acceptance.

## Measured result and limits

The original image worker's six normal reductions, 94.144-96.595%, remain attributed to its original source/run.
The follow-up adds full WOFF2 encodes of the same eight fonts; original TTF files remain.
Aggregate font storage changes from 1,544,216 to 458,104 bytes. This is not a per-page transfer claim.

The matched degraded mobile samples use Chrome 156, DPR1, 360x800, 50,000 bytes/second each direction, latency400ms, CPU6x and a 40-second load limit.
They use uncompressed loopback delivery and fresh isolated contexts, with one sample per condition.

| Route | Image candidate before font conversion | After font conversion |
| --- | --- | --- |
| index.html | timeout at 40 seconds | 33,110 ms, HTTP200 |
| catalogo.html | 39,842 ms, HTTP200 | 32,535 ms, HTTP200 |
| producto-amarillo.html | 37,415 ms, HTTP200 | 30,682 ms, HTTP200 |

All eighteen navigation observations record zero page errors, horizontal overflow and external requests.
Normal product observations disclose an unfinished original PNG response; transferred bytes for unfinished responses remain unknown.
These samples establish the bounded 40-second target. They do not establish satisfactory field performance or universal device/network support.

The worker reports image regression PASS, font checks 2/2, editorial/catalog18/18 and staff DOM5/5.
Negative controls reject missing IA disclosure, changed image identity, missing responsive source and lost font character.
The historical editorial failures were reproduced before test edits; the independent reviewer must assess the revised contract's strength.
Full demo checkout remains attributed to the bound image worker. The font follow-up verifies one add-to-bag interaction; no new real payment is claimed.

## Blocker ownership

1. Full portable suite: `python tests/check.py` exit1. Actual failure: three asset-audit symlink fixtures raise `OSError: [WinError 1314] A required privilege is not held by the client`.
   The worker preserved that failure and ran remaining stages separately. Catalog-staging has two instances of the same privilege failure.
   Cause: Windows refuses symlink creation in those fixtures. No evidence here establishes a product defect, and the complete suite is not green.
   Correction route: primary serially imports the reviewed exact candidate, publishes normally to Tony, then checks the same remote SHA's existing Ubuntu `tony-snapshot.yml` historical-regressions job.
   Completion check: that job's full `python tests/check.py --install` exits0 on the exact published candidate; any Linux failure needs its own diagnosis.
   No Windows privilege change, test skip, TLS change or old-SHA CI substitution is authorized.
2. Independent judgment: primary dispatches one Astra/high review of the frozen candidate and ten acceptance checks. Owner: primary. Completion check: review returned, material findings resolved and disposition recorded.
3. Critic availability: the existing Antigravity quota rejection still prevents Opus review. No retry or substitute is scheduled. Owner: primary/Jason for an approved available route; completion requires an actual Opus return or an explicit owner decision. Astra does not impersonate the critic.
4. Integration/publication: candidate remains in the completed worker's worktree. Owner: primary. Completion requires reviewed allowlist import, source bindings, normal hooks, SYNCED, matching remote SHA and applicable fresh CI.

NOT RUN by this primary: full suites, fresh browser navigation, Linux CI, production runtime, API/SQL, physical devices, field INP or operational acceptance.
C2/C9/C10 and deployment/merge gates remain unchanged.

## Verifier corrections and lesson

An initial primary helper incorrectly normalized CRLF in binary files. RAW hashes all matched; correcting normalization to textual suffixes made all portable hashes match.
The initial contact-sheet helper grouped recordings by ordinal positions. It was corrected to explicit phase, viewport and route before the final paired inspection.
A read of a nonexistent `validate.yml` was resolved by listing the actual workflow files and reading `ci.yml` and `tony-snapshot.yml`.
Lesson: bind comparisons to explicit asset types and observation identities; a verifier's assumption must not become a product finding.
