# One PR, one automatic validation attempt

Status: PREPARED, NOT AUTHORIZED, NOT RUN. This packet replaces the incomplete three-SQL-job proposal in the initial plan. Primary: SUAZO-PC, T3 Code / Codex gpt-6.1-sol/xhigh. Source before the two-file gate correction: `670d4a8e6fab650ef1ee2b0fba64d7e810b7dbe3`.

## Target and acceptance

Open one same-repository `Tony` → `main` product rollup after source publication, independent review and Jason's runtime approval. Record the exact final head, base and Actions merge-checkout SHA. The seven protected contexts below must pass on that candidate. Inspect every additional scheduled job; a skipped or missing SQL job is not executed evidence. Do not weaken protection or merge this PR.

Tony contains PR #2. The new rollup can supersede it without losing its changes. PR #5's seasonal-offers feature stays open and deferred; PR #6's optional no-mistakes policy stays separate and inactive. Neither draft is included or declared finished.

## Automatic jobs and limits

| Workflow / job | Maximum minutes | Required by recorded main protection | Actual layer |
| --- | ---: | --- | --- |
| savia.yml / backend-full-suite-sql | 25 | Yes | Legacy backend and disposable SQL |
| savia.yml / staff-ui-and-browser | 15 | Yes | Staff DOM and Chrome with mocked HTTP |
| golden-path.yml / golden-path | 20 | Yes | Legacy Chrome → real HTTPS API → SQL, cash path |
| backend.yml / build-and-guards | 15 | Yes | Offline backend |
| ci.yml / check, Windows | 15 | Yes | Portable storefront checks |
| ci.yml / check, Ubuntu | 15 | Yes | Portable storefront checks |
| progress-digest.yml / digest | 5 | Yes | Ledger and PR description |
| savia-v2.yml / check | 45 | No | v2 rules, web, T-SQL and .NET with real SQL |
| savia-azure.yml / build-and-prove | 30 | No | Images, real SQL migration twice and API container smoke |
| bug-proof.yml / proof | 20 | No | Event-metadata gate; proof runs only for a bug label or Fixes/Closes issue reference |
| progress-digest.yml / narrate | 15 | No | Provider steps skipped when API/OAuth secrets are absent |
| progress-digest.yml / publish | 5 | No | Existing digest publication to the PR |
| bug-proof.yml / comment | 5 | No | Conditional on required bug proof; not selected by the proposed ordinary rollup |

The first twelve envelopes total 225 job-minutes; the conditional bug comment makes the conservative total 230. This is cumulative job time, not elapsed waiting time or a dollar cap. PR creation/description editing can cause separate events: use the prepared final body on creation, then make no unapproved edits, pushes, reopens or reruns. Inspect actual run IDs and attempts before acceptance. No manual dispatch or automatic retry is included.

Path filters use the entire large PR diff. Verify that both v2 and Azure jobs actually schedule. If GitHub's changed-file filter misses one, stop dependent acceptance and prepare its exact manual scope; do not call it passed or dispatch under this grant.

Authenticated metadata read on 2026-11-16: repository public, owner type User, zero repository Actions secrets, zero Actions variables. The narrator has no configured provider credential; recheck immediately before creation and stop if a provider becomes configured. No new paid-provider call is approved. No organization-secret inheritance applies to this User-owned repository.

Standard hosted runner compute is free for this public repository under [GitHub's billing rules](https://docs.github.com/en/actions/concepts/billing-and-usage). This does not certify account-wide storage usage or another product's bill. No larger/self-hosted runner or billing configuration is selected.

## SQL, certificates and artifact publication

Only fresh GitHub-hosted Ubuntu jobs and fictional data. SQL Server 2022 Developer image:

`mcr.microsoft.com/mssql/server@sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718`

Preserve existing nonproduction EULA acceptance and SQL test-certificate trust (`TrustServerCertificate=true` / sqlcmd `-C`). The golden path may use its existing temporary loopback HTTPS certificate. Create and mutate only each job's synthetic accounts, databases, migrations, fixtures, containers, volumes and networks. Generate and mask passwords on the runner. Copy no local secrets, databases or `.env` files. No Windows trust-store, native SQL, service or real-account change.

The existing v2 workflow uploads raw synthetic database-test diagnostics only after failure, from `savia/.out/dbtests`, with seven-day retention. Other artifacts retain their existing workflow rules; the golden path verifies its restricted evidence before upload. This packet includes that existing artifact publication. Raw synthetic logs are not independently certified as sanitized customer-data exports. No customer data is permitted.

## Cleanup boundary adopted for this proposed hosted run

The legacy backend and golden-path workflows contain explicit owned-resource cleanup/readback. Acceptance must inspect its actual output. A green job alone does not establish resource absence.

The v2 workflow uses `docker compose down --volumes || true`; Azure uses best-effort container/network deletion. Neither proves individual resource absence. Primary adopts the reviewer's permitted **hosted-runner isolation boundary** for this proposed fictional-data PR attempt. GitHub documents [ephemeral, clean isolated hosted VMs](https://docs.github.com/en/actions/reference/security/secure-use). This acceptance is limited to the standard fresh hosted jobs selected here. It is not a cleanup verification or a guarantee about deletion timing. Record their teardown as best-effort and individual absence as NOT PROVEN, even if jobs pass. Never reuse this boundary for SUAZO-PC, native SQL, a self-hosted runner, production or an Azure deployment. Jason's runtime decision must include this disclosed boundary.

## Exclusions and failure behavior

- `backend.yml/sql-server-integration` is main-push/manual-only and is excluded from this PR.
- Azure deployment requires `workflow_dispatch`; no dispatch is authorized. Cloudflare deployment excludes PR events, and deployment variables are absent.
- The bug-intake workflow is absent from the current default branch. Do not infer its workflow-run automation is active from the candidate alone.
- Automatic golden path selects cash. Manual supply and stock-exception flags remain false. A successful backend job does not guarantee its conditional restart step executed. Inspect the receipt and step output before claiming restart evidence.
- v2's job is not v2 browser acceptance. No live payments, operational installation or production READY claim follows from this PR.

On failure, collect actual step outcomes and permitted artifacts, verify the applicable cleanup boundary, diagnose the failed layer, and stop dependent acceptance. Independent jobs already scheduled may finish. No repeat, new source push, manual run, merge or deployment follows automatically. Prepare a bounded correction and new runtime scope if needed.

## Before creation

1. Primary publishes source and docs normally, checks remote SHA and non-SQL Tony CI, and obtains Astra/xhigh's bounded review.
2. Primary refreshes base/head, protection, repository visibility, secrets/variables names and runner labels. Stop on a material change.
3. Jason authorizes this exact final SHA and one automatic PR validation attempt, including the disclosed artifact and cleanup limits.
4. Primary creates the PR with the prepared body, links it, reads back the actual checks, then watches until results settle. No merge is included.

`docs/DATABASE.md` requires a runtime scope for each execution. Earlier grants are consumed. That rule is why PR creation remains pending; all independent preparation continues.
