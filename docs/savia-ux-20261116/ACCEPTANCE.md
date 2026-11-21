# Primary acceptance: SAVIA staff UX

Date: 2026-11-16. Host: SUAZO-PC.
Primary: T3 Code / Codex / gpt-6.1-sol / max.
Verdict: **ACCEPT WITH LIMITS for the local UX increment**.
Publication: **NOT RUN**. Production readiness: **NOT ESTABLISHED**.

## Accepted scope

Jason authorized simpler staff workflows and parallel implementation. The increment preserves all authorized routes while reducing Owner navigation from 14 to seven main choices. History prioritizes receipt numbers. The fictional demo has four direct role entries and a confirmed reset. Sales keep explicit seller attribution, fold secondary options, and preserve durable attempt identity. Uncertain sales allow receipt lookup without automatic resubmission. Scanner focus respects native keyboard controls.

The ten frozen [sale checks](sale-preimplementation.md) remain unchanged. Server authorization, payments, approval rules and persistence contracts were not relaxed.

## Independent review and primary verification

The final [Astra/xhigh report](corrections/lookup/astra-recheck.md) returns ACCEPT WITH LIMITS. F3b is closed within the observed lifecycle boundaries. Earlier F1, F2, F4, stale-401 and initialization corrections retain their bounded acceptance. No material finding remains open in this increment.

- Base commit: `2c96904f49d2df913850bc13cf53b3b03ceebacf`.
- Immutable reviewed Git tree: `72b192de1661688962b21d6ff3e7925a955a7508`.
- [Candidate manifest](corrections/lookup/CANDIDATE.json): 20/20 source/test LF bindings and 6/6 artifact LF bindings verified.
- The primary compared all 115 changed paths with the reviewed tree: zero differences. Text used the declared CRLF-to-LF policy; media used original RAW bytes.
- Exact report RAW/LF SHA256: `01e2c41118e19671546da09677c80900e215a93e66846e2c3e011d1cdcbefc3d`.
- The imported report matches the independent original byte for byte. Its recorded raw-log hashes match the retained private logs.
- Canonical HEAD and index remained unchanged during acceptance. Unrelated `AGENTS.md`, `docs/DECISIONS.md` and other work are excluded.

The reviewed tree predates this acceptance, its imported report and the top-level README status/attribution corrections. Those are documentation-only additions. Historical manifests and reports remain unchanged.

## Proof and limits

| Evidence | Result | Meaning |
| --- | --- | --- |
| Primary regression before correction | 1 PASS / 6 FAIL; exit 1 | Reproduced stale lookup behavior |
| Corrected focused regression | 7/7; exit 0 | Two lifecycle guards reject retired work |
| Final primary Node suite | 98/98; zero skips; exit 0 | Web and scanner regression checks |
| Final primary lint and demo build | Both exit 0 | 65 web files checked; fictional demo builds |
| Final primary Chrome lookup journey | 8/8; exit 0 | Actual shell, 1440x900 and 390x844; synthetic HTTP; zero sale POSTs |
| Fresh independent Astra Node suite | 98/98; exit 0 | Separate execution on the frozen candidate |
| Fresh independent adversarial probe | 24/24; exit 0 | Delayed body parsing, route/session/scope retirement, successor dialogs and active controls |

The [area README](README.md) separately attributes reused full-shell, mounted-sale, keyboard and demo-entry evidence. The final lookup run does not claim those sale submissions. Browser automation does not prove every scheduler ordering, physical devices, multi-tab behavior, a complete accessibility audit or real-user usability.

One initial primary comparison mistakenly normalized binary media. Comparing binary paths as RAW bytes resolved that verification error; no media or product change was needed. Future comparisons must apply byte policies by file type.

## Remaining delivery blockers

| Blocker | Evidence and attempted resolution | Owner / next action / completion check |
| --- | --- | --- |
| Root Windows repository gate | Earlier `python tests/check.py` failed on three symlink fixtures with `WinError 1314`. Focused checks passed. No redundant rerun or Windows security change was made. | Primary: check the existing Linux gate on the exact published commit; require successful applicable jobs. |
| Publication triggers SQL CI | `savia-v2.yml` starts disposable SQL Server Developer automatically on a Tony push touching `savia/**`; job timeout is 45 minutes. Local UX work has not executed it. | Primary/Jason: verify existing runtime authority or obtain the concrete execution scope before publication. Then verify SYNCED, remote SHA and CI results. |

No commit, push, merge, deploy, real API/SQL execution, real payment or customer data was used in this UX increment. The root Windows gate, exact-SHA Linux CI and operational acceptance remain separate from local UX acceptance.
