# PR7: publish the accepted corrections and validate them once

Status: **AUTHORIZED ONCE; PUBLICATION AND AUTOMATIC CI PENDING.**

Jason selected: ?A. Publicar y ejecutar una vez (recomendado).?
Authorization recorded at 2026-11-17T01:24:28.216818+00:00. The grant covers this packet only. No automatic retry, paid AI, merge or deployment.

## Result and decision

The primary accepted the local correction source with limits. Astra/xhigh closed the last notice defect with 118/118 web tests and 33 independent assertions. [Acceptance](final-combined/PRIMARY-ACCEPTANCE.json) and [area status](STATUS.md) preserve the evidence and limits.

Recommended decision: authorize **one normal Tony publication**, updating the existing PR7, and its automatic push/PR validation. This does not authorize merge or deployment.

## Exact publication

- Repository: `Suazo-AI/Martha-Silva-Store` (public).
- Branch and expected parent: `Tony@ba8ff2ba10935e99fc268ebbe5eae130f72c1cca`.
- Existing PR: `#7`, targeting `main@3b0049163ece2d9431cee01f1bea624a66d9d8d4`.
- Product/test scope: the 18 reviewed paths in [final result](final-combined/RESULT.json). Include only owned evidence and documentation in [PUBLICATION-FILES.json](PUBLICATION-FILES.json).
- Use normal hooks. The generated progress receipt is the only additional publication path. Do not skip hooks or force-push.
- Verify the staged source against its accepted LF hashes. Record the resulting commit SHA, `SYNCED`, and remote Tony/PR head readback.
- Exclude unrelated work, private exports, raw logs, TRX, credentials and six review ZIPs. Preserve those ZIPs locally; their historical hashes remain in the exclusion list. Public source files and manifests remain available. Historical links to excluded archives describe local review custody, not downloadable GitHub artifacts.
- Stop before publication if the parent, reviewed source, PR base, billing conditions or workflow scope changes. Documentation corrections and the normal generated receipt do not grant another runtime attempt.

## Automatic execution envelope

A Tony push updates the open PR. It can therefore start both push and PR jobs. The two v2 SQL jobs use different concurrency groups and can both run. This packet includes both.

| Trigger | Workflow / jobs | Maximum cumulative job minutes |
| --- | --- | ---: |
| Tony push | `savia-v2.yml`: check | 45 |
| Tony push | `progress-digest.yml`: digest + publish | 10 |
| Tony push | `progress.yml`: progress | 5 |
| Tony push | `staff-ui-candidate.yml`: staff/resource guards | 15 |
| Tony push | `tony-snapshot.yml`: integrity + historical regressions | 25 |
| PR synchronize | `backend.yml`: build/guards | 15 |
| PR synchronize | `bug-proof.yml`: proof + conditional comment | 25 |
| PR synchronize | `ci.yml`: Windows + Linux portable checks | 30 |
| PR synchronize | `golden-path.yml`: real browser/API/SQL | 20 |
| PR synchronize | `progress-digest.yml`: digest + conditional narrator + publish | 25 |
| PR synchronize | `savia-azure.yml`: build/prove | 30 |
| PR synchronize | `savia-v2.yml`: check | 45 |
| PR synchronize | `savia.yml`: backend SQL + staff/browser | 40 |
| **Total upper envelope** | **100 push + 230 PR** | **330** |

These are configured job timeout totals, not elapsed waiting time or a dollar limit. Conditional jobs may skip. No automatic retry, manual dispatch, second publication, new PR, PR-body edit or label change is included.

The four SQL workflow families create up to five SQL job instances: backend, golden path, Azure proof and v2 twice. The corrected golden workflow selects cash, supply receipt and stock-exception checks together. V029 replay, current authorization, financial conservation and observed lock waits must be checked in the actual SQL results.

## Runtime boundaries and publication effects

- Use only disposable GitHub-hosted runners, SQL Server 2022 Developer containers and fictional data. Existing image: `mcr.microsoft.com/mssql/server@sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718`.
- Preserve the existing test EULA, test certificate trust settings and temporary loopback HTTPS. Do not change Windows certificates, native SQL, services, real accounts or real customer data on SUAZO-PC.
- No paid AI provider calls. Preflight found zero repository Actions secrets and variables; PR7 has no bug labels or closing-issue reference. Recheck immediately before publication. Stop if provider credentials or billing become uncertain. A scheduled narrator job does not itself prove an AI call occurred.
- Existing progress workflows can publish digest/check comments. Conditional bug-proof comments are included in the envelope. No manual external message is authorized by this packet.
- Artifacts can be public because the repository is public. Publish only synthetic diagnostics. v2 retains failure diagnostics for seven days; other artifacts retain each workflow's configured/default policy. This is not a promise that all artifacts expire in seven days.
- Legacy SQL and golden-path cleanup include absence checks. v2 uses best-effort `docker compose down --volumes || true`; Azure cleanup is also best effort. Those two families do not independently prove absence of every resource. Disposable hosted-runner isolation is their outer boundary.
- No local SQL runtime, Azure deployment, Cloudflare deployment, `main` push or merge. Main-only and manual-deployment jobs are outside this event scope. The default branch has no active `bug-intake.yml` workflow in the verified base.

## Completion checks and failure handling

1. Recheck the publication allowlist, accepted sources, parent/base, workflow bindings, secrets/variables and actual hook scan. Preserve the empty/unrelated index.
2. After approval, stage explicit owned paths, commit once through normal hooks, and verify the exact remote SHA. Record a failed publication without an automatic retry.
3. Read every resulting workflow result and its tested revision. PR workflows may test a GitHub merge revision; record both PR head and tested revision. Do not treat checks on the old head as current.
4. Require all seven protected contexts: backend SQL, staff/browser, real golden path, build/guards, Windows portable, Linux portable and ledger digest. Inspect v2, Azure proof and other scheduled jobs too.
5. Inspect actual test counts, skips, authorization/financial assertions, concurrency and cleanup evidence. A green label or another worker's summary is insufficient.
6. If a job fails or a required workflow does not start, preserve diagnostics and diagnose it. No rerun or additional dispatch is included. Independent jobs may finish; do not start dependent work after a failed prerequisite.
7. Report merge readiness separately from production readiness. This packet provides no production acceptance and no merge authority.

## Evidence and authorization rule

[PUBLICATION-FILES.json](PUBLICATION-FILES.json) records allowed bytes, exclusions, workflow bindings and sanitized read-only GitHub preflight facts. The private preflight capture was recorded at `2026-11-17T01:02:45.766504+00:00`. No GitHub mutation or runtime was executed to prepare it.

[DATABASE.md](../../DATABASE.md), step 4 under “Preparar el siguiente entorno”, requires: “Obtener alcance de runtime para esa ejecución. La aprobación del lote anterior está consumida.” The previous one-shot attempt has been consumed. Normal Tony hooks start CI, so fresh runtime scope is required before this publication.
