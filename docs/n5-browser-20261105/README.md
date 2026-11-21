# N5 browser recovery coverage: accepted with limits

Primary accepts N5-COV after Sol/high execution, Opus critic return and final
Astra/high adjudication of M1. Ledger done_when is unchanged. No waiver is used.
Production remains NO-GO. No product source changed.

Current overlay: raw test SHA256
`88eaa468cc92bdd32ca6b066b512c6a8ebd38969cc7f332dbad9b41122269dea`.

| Control | Result | Exit |
| --- | --- | --- |
| Baseline N5 | 8/8 PASS | 0 |
| M01: remove busy/pending submit guards | Semantic failure detected | 1 |
| M02: omit obsolete receipt removal | Semantic failure detected | 1 |
| M03: remove combined logout boundary guards | Semantic failure detected | 1 |
| Restored N5 | 8/8 PASS | 0 |

The original product was restored byte for byte after every injection.
These controls prove the tests detect the injected regressions. They do not prove
an existing product defect was fixed. The same-generation newer-pending race is
reasonedly unreachable through this UI. The reachable logout boundary is tested.
M03 covers combined protection and the observed window, not isolated guards or
all possible scheduling orders.

[Primary acceptance](primary-review.md) records findings, source versions,
verification and limits. [Final independent adjudication](mutations/judge.md)
closes M1 and the observation objection for this scope.
[Mutation results](mutations/RESULT.json), [public import map](mutations/IMPORT.json)
and [byte policy](HASH-POLICY.md) preserve exact original-versus-public semantics.

Historical worker runs remain separately attributed: focused8/8, full browser50/50,
staff102/102 on their recorded source versions. The exact-stock primary rerun is
separate from the later overlay's baseline/restored8/8. Frozen original RESULT,
worker-README and worker-test.patch retain that history. Raw logs are archived
outside the public repository with paths/hashes; none was renamed to bypass policy.

Opus model was claude-opus-5-5 via Antigravity. High was requested; effective
reasoning is unknown. Astra runtime high was verified. No provider gate is waived.
The final judge's narrative hash typo is preserved with a factual primary erratum.

[REVIEW-PACKET.json](REVIEW-PACKET.json) is historical pre-acceptance input metadata.
Its 29 exact inputs are privately archived before acceptance edits; current
portable hashes are in INTEGRATION.json. The packet is not a current-file claim.

Local checks: progress23/23, ledger24/24, valid35 items, preserved hashes15/15 and
staged whitespace check passed. Windows portable remains WinError1314; earlier
Linux CI is evidence only for its own SHA. See [publication](PUBLICATION.md) for
normal-hook readback and exact-SHA CI requirements.

NOT RUN: real API, SQL, physical devices, full suite on the current overlay,
production or operational acceptance. Actual browser work uses synthetic HTTP.
C2/C9/C10 and commercial/operational readiness remain separate. Next action:
primary publishes the accepted evidence and verifies that publication's own CI.
