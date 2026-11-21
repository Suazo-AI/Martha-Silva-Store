# Runner R1-R4 corrected; review pending

Primary: SUAZO-PC / T3 Code / Codex / gpt-6.1-sol/xhigh.
Source parent: `754b67eedd70d4234db950f53262d652b83d616c`.
[Astra's source review](../astra-recheck.md) is accepted as actionable; it did not execute its additional probes.
Primary added focused counterexamples before corrections, reproduced the unsafe outcomes, then applied minimal corrections.

| Finding | Correction and fresh check |
|---|---|
| R1: persistence can exhaust a budget before the next stage | Check after file persistence, stage logging and before budget transitions. A fake clock exhausted inside C71 logging blocks D dispatch. |
| R2: cleanup can falsely report absence | Use `--no-trunc`; require valid full IDs and names. Failed removal with renamed surviving ID reports present. Abbreviated/malformed rows remain unknown. |
| R3: interruption can persist PASS or skip cleanup | Capture interruption before finalization, preserve original failure, attempt every owned resource independently, persist FAILED, then re-raise the original interruption. C1 and first-cleanup interruptions are tested. |
| R4: archive aliases share one destination | Require canonical allowlist/member paths; compare destination identities case-insensitively. Dot, doubled slash and case aliases are rejected before extraction. Ordinary permissions still pass. |

Fresh full command: `python tools/local-validation/test_run_local_validation.py`.
**46/46 PASS**, exit 0, 2.922 seconds. Includes nine historical OLD controls and seven added methods.
Real process execution is prohibited by the tests' subprocess guard. This is not a Docker campaign.
Publication documentation checks passed: progress 23/23, delivery 24/24, ledger 40 items and export 15 preserved hashes; all exits 0.
Exact commands are recorded in the [integration verification](../../../../cash-register-20261107/backend-integration/README.md).

The first red cohort reported nine assertion failures and one error. One alias test reused a destination after an expected rejection failed.
Primary corrected only that fixture to use independent destinations; all three alias probes then failed independently against uncorrected source.
The final 46/46 includes the corrected fixture. Original red logs remain retained without rewriting.
[Source bindings, commands, private log hashes and limits](RESULT.json).

## Blockers and next action

Primary must freeze these source bytes and request fresh Astra/xhigh review. Closure requires exact-source acceptance with R1-R4 addressed.
Dependency closure and a qualified immutable image remain absent; the Dockerfile deliberately stops.
Primary must prepare reviewed build inputs before requesting the separately scoped image/runtime work.
Actual Windows private-directory DACL qualification remains pending; no ACL or security setting was changed.
The old C77/E2 manifest predates cash additions. Refresh current coverage separately before a combined campaign; preserve historical evidence.
C77/current SQL, D and E2 remain NOT RUN for this candidate. No runtime permission or production gate is waived.

Lesson: simulated transport success needs separate checks for filesystem delays, interruptions and authoritative absence readback.
