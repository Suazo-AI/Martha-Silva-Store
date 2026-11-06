# Supply harness: critic corrections

Gemini returned ACCEPT WITH LIMITS on preparation commit `65ab1d9`. Production remains NO-GO.
[Original critic report](gemini-critic.md) is imported unchanged; SHA256 is `b84ef4972e47c19716554e0f501e461cf68438444cc200c5151e65be573e8340`.

The primary reproduced F1 using the new regression test against the old allowlist.
All fourteen supply-code subtests failed: the harness replaced their safe codes with `browser_protocol_invalid`.
The primary added exactly those fourteen known codes. Unknown text is still reduced to the safe generic code.
The full browser safety suite now passes 24/24; core safety passes 17/17. Both exit 0.
[CORRECTIONS.json](CORRECTIONS.json) records evidence and its limits. A persistent red log was not captured.

F2 is corrected: UTF-8 accents are restored in the receipt section, and the stray `Inventory` word is corrected.
F3 and F4 remain low, non-blocking readability findings. No SQL behavior or C# source was changed for them.
The earlier 40 checks and successful C# compile remain historical results on their original bytes.
`CANDIDATE.json` remains frozen. [REVIEW-CANDIDATE.json](REVIEW-CANDIDATE.json) binds the corrected 21 paths.

The no-SQL candidate workflow for `65ab1d942a4666321e489da1cccd6341a0f671b7` completed successfully:
[run 42166701247](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42166701247).
The new correction commit requires its own successful checks. A previous green run does not certify new bytes.

| Gate | Evidence, attempted resolution and owner |
| --- | --- |
| F1 diagnostic code loss | Reproduced; explicit allowlist correction; 24/24 browser safety checks now pass. Primary closes this narrow defect. |
| F2 corrupted text | Corrected UTF-8; no ASCII question marks remain in the target section. Primary closes this documentation issue. |
| Independent adjudication | Critic exists; corrected bytes are now frozen. Primary sends the 21 bindings, critic objections and exact CI to Astra/high. |
| Combined browser to API to SQL | NOT RUN. The earlier isolated SQL authorization is consumed. No new runtime was attempted. Jason must authorize the reviewed, bounded manual workflow before execution. |
| Operational acceptance | C2/C9/C10, payment and production gates remain separate. These preparations do not close them. |

Lesson: preserve safe, specific diagnostic codes through each process boundary, and test unknown-text rejection beside known-code propagation.

Next: publish the corrected candidate, read exact-commit CI, and obtain Astra's independent adjudication.

## Automatic Linux readback on 8523523

[CI-852.json](CI-852.json) binds all 21 source paths to successful no-SQL run 42169677581 on `8523523a41d490f7bdcca016bf34cc5fc2c04a37`. Helper Release build: zero warnings/errors. Staff: 124/124; mocked Chrome: 50/50 and 8/8. Database-independent .NET: 526 passed, 55 skipped, zero failed. These skipped tests remain explicit. This is preparation and source-lineage evidence; the combined real browser/API/SQL journey remains NOT RUN.
