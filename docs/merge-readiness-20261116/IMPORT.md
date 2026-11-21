# Public evidence import

Raw `.log` files are excluded under the unchanged `tools/progress.py` publication filter. Originals remain in ignored private exports and in their original worker worktrees. [OUTCOMES.json](OUTCOMES.json) contains only reviewed counts, exits and non-sensitive conclusions; it does not replace or claim a fresh execution.

| Excluded worker path | Original RAW SHA256 | Private archive |
| --- | --- | --- |
| `pr5/apply-check.log` | `21ba3c3ff7018eb93606b6ea51a13b4593bff994499a487e0ab357dfe5a00638` | `private-exports/merge-readiness-20261116/worker-raw/pr5/apply-check.log` |
| `pr5/pr5-dom.log` | `e82d2901548c09e4deba11ac14bdb5a7e83c783ef20ff26b759173c6d428b7aa` | `private-exports/merge-readiness-20261116/worker-raw/pr5/pr5-dom.log` |
| `pr5/probe.log` | `63517de448a7dbad105e287c3d066d6465c61851c4e961b74af02aa894f8987a` | `private-exports/merge-readiness-20261116/worker-raw/pr5/probe.log` |
| `pr5/tony-dom.log` | `baf1aeb41568e1c67f13c71a2f87b6a3709cdef0653cb0ffa12886faed463ac1` | `private-exports/merge-readiness-20261116/worker-raw/pr5/tony-dom.log` |

Two public evidence derivatives are declared explicitly:

- `pr5/README.md`: evidence links now point to the sanitized outcomes and this import map. Original RAW SHA256: `f3be80e7e23d87a509a5646a5bdd32041705fb4cba9c2ea3125f902726f4d5ed`; public LF SHA256: `9a03da4be51890c28895abe6f01300ca1550ca445fcf113ae4ad1c40bfc99094`. The original report is archived alongside its raw logs.
- `pr6/main-protection.json`: doubled carriage returns were normalized to LF only. Original RAW SHA256: `f5a53219609f56c58afea1c6e3489f17d6b8ebe7f3d079bf3bcceafce4ce05ad`; public LF SHA256: `80c4cdba5ef3585e63d5ff7a27522a82e71f425c5e7f774070d1fe7e1b55bd88`. Its original bytes remain in `private-exports/merge-readiness-20261116/import-originals/pr6/main-protection.json`.

The other ten imported worker evidence files remain byte-identical to their sources. `PLAN.md`, this import map and `OUTCOMES.json` are primary-owned. No product, pipeline or branch-protection setting changed.

## Independent merge-route review

`astra-merge-route.md` was copied from the reviewer's exact owned report path in `t3-ee501791-40773bf60626b84a`. RAW SHA256 `4fb31b91e50fcfc0aed3c6a3dcba3b25c2062c3e7e681303033f39eedfbb2942` is identical before and after import. No other worker file was copied. The report records source-only advice at `670d4a8`; the primary's later source preflight, gate correction and prepared runtime packet are separate evidence.

## Final independent preflight review

`astra-final-preflight.md` was copied byte for byte from the reviewer's owned `docs/merge-readiness-20261116/astra-final-preflight.md` in `t3-9af55c6a-eec87f7c56c44215`. Original RAW SHA256: `b6605e53cec76c4859bdaf98ac71b255b349b160274e1e98a20ed3bc1e116713`. The first staged whitespace check rejected the original extra blank line at EOF. The public derivative removes only that blank line; public RAW SHA256: `119c6e64b740de90efab7e4ae058e94f839879a7e0f1dc488ac0deb67d0d7d69`. The exact original remains in `private-exports/merge-readiness-20261116/preflight-acceptance/astra-final-preflight-original.md` and the reviewer worktree. No other worker file was copied. Its verdict applies to source `edd2e097f6b4f22c9dbbffa897e9ed7f7a063055`; primary's acceptance and exact-head CI readback are recorded separately in PLAN and OUTCOMES. Raw CI logs remain under ignored private exports. This import does not start SQL or create a PR.
