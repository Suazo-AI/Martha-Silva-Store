# Security self-test scans, 2026-11-27

Run date: 2026-11-27 (local, UTC-6); scans started 2026-11-28T00:51Z.
Branch `Tony`, run as the test sub-agent.
No code, package or setting was changed.
No secret value is stored in this folder; the secret scan used `--redact` and a pattern grep of this folder found nothing.

## Result per scan

| Scan | Result | Counts |
| --- | --- | --- |
| ST-3 dependency scan | PASS | 0 vulnerable packages in 7 .NET projects; 0 npm findings in 3 lockfiles. |
| ST-4 full-history secret scan | PARTIAL: no real credential found, history not fully covered | 2,915 raw findings; 0 real-looking credentials; scan stopped early. |
| ST-6 image scan | FINDINGS | 6 HIGH, 0 CRITICAL, 41 MEDIUM, 6 LOW. |
| ST-1 ZAP baseline (passive) | FINDINGS, low risk | 0 FAIL, 7 WARN, 61 PASS. |

## ST-3 dependency scan (evidence for SEC-26 part 2, SEC-27, ST-3)

| Item | Value |
| --- | --- |
| Tools | .NET SDK 10.0.402 (`C:/Users/Jason/.dotnet-sdk-10.0.402`); npm 11.17.0. |
| .NET command | `dotnet list Savia.slnx package --vulnerable --include-transitive` run in `savia/`. |
| .NET source | `https://api.nuget.org/v3/index.json` only. |
| .NET result | Savia.Api, Application, Contracts, Domain, Infrastructure, Migrator and Tests: no vulnerable packages. |
| npm command | `npm audit --json` in repo root, `savia/` and `tests/frontend-deps/`. |
| npm result | 0 info, 0 low, 0 moderate, 0 high, 0 critical in all three. |
| Lockfiles unchanged | `git status` shows the three `package-lock.json` files unmodified after the audit. |
| Skipped on purpose | `.claude/worktrees/*` copies of lockfiles (agent worktrees, not shipped). |
| Files | `st3-dotnet-vulnerable.txt`, `st3-dotnet-version.txt`, `st3-npm-audit-root.json`, `st3-npm-audit-savia.json`, `st3-npm-audit-tests-frontend-deps.json`, `st3-npm-version.txt`. |

Limit: this is a point-in-time scan on this PC.
SEC-27 asks for the scan to run in CI. It does not yet. This evidence proves the scan is clean today, not that CI enforces it.
SEC-26 also asks for digest-pinned base images. The image scan below checks the image, not the Dockerfile `FROM` lines.

## ST-4 full-history secret scan (evidence for SEC-12 part 1, ST-4)

| Item | Value |
| --- | --- |
| Tool | gitleaks v8.30.1, image `zricethezav/gitleaks@sha256:c00b6bd0aeb3071cbcb79009cb16a60dd9e0a7c60e2be9ab65d25e6bc8abbb7f`. |
| Command | `docker run --rm -v <repo>:/repo:ro -v <evidence>:/out zricethezav/gitleaks detect --source /repo --log-opts="--all" --redact --report-format json --report-path /out/st4-gitleaks.json` |
| Duration | 44 min 17 s, 4.77 GB scanned. |
| Commits scanned | 964. The repository has about 1,290 reachable commits, so about 320 were not scanned. |
| Raw findings | 2,915, all rule `generic-api-key`, in 40 files and 339 commits. |
| Redaction | Every `Secret` field is `REDACTED`. 0 fields are unredacted. |

Gitleaks stopped early with two errors (text in `st4-gitleaks.stdout.txt`):

1. `fatal: unterminated line in .git/packed-refs` (another agent wrote refs while the scan read them).
2. `fatal: could not fetch f7f17b0f792586ce3d296e6bcb78b4e046a905d1 from promisor remote`.

The repository is a partial clone (`remote.origin.partialclonefilter=blob:none`).
`git rev-list --all --objects --missing=print` lists 34 blobs that are not stored locally, so gitleaks cannot read them.
Result: the scan is not a complete full-history scan.
SEC-12 and ST-4 are not satisfied until the scan completes with exit code 0.

Classification of the 2,915 findings (shape check on the committed line, no value printed; script `st4-classify.js`):

| Class | Count | Meaning |
| --- | --- | --- |
| 64-hex SHA-256 digest | 947 | File hashes in evidence JSON, for example `"api.mjs": "<sha256>"`. Placeholder-class, not a credential. |
| GUID | 1,956 | Test idempotency keys (`key`, `originalKey`, `preservedKey`, `newKey`, `pendingKey`) in browser-test results, and one Azure built-in role id (`savia/deploy/azure/main.bicep:78`, `keyVaultSecretsUser`). Test fixtures or public ids. |
| Other | 12 | `README.md:32` (prose, "access table"), `TEST-INVENTORY.txt:161` (`one-valid-key-1234`, a test fixture), `configuration.md:82` (`sk-live-abc123...`, a documentation placeholder). |
| Real-looking credential | 0 | None. |

Full row list for the non-digest findings: `st4-gitleaks-classification.txt`.
The raw report `st4-gitleaks.json` also contains author fields; they are GitHub noreply addresses only.

Recommended code change: add a `.gitleaks.toml` allowlist for `docs/**/browser-results.json`-style evidence files and the three fixtures above, so the CI scan stays quiet.
Then run the scan against a full clone (or after `git fetch` hydrates the 34 blobs) and confirm exit 0 and the commit count.

## ST-6 image scan (evidence for SEC-26 part 1, ST-6)

| Item | Value |
| --- | --- |
| Tool | Trivy 0.76.2, image `aquasec/trivy@sha256:8f6bb947dbc528902e11f2f5be52f7b519f6a39d5d148f41166f2040499768fb`. |
| Target | `acrsaviabukmlt.azurecr.io/savia-api:c7e30bc41a837daa7d999f817b81d3609796ebed`, image id `sha256:cf0cf039b09304ee08c19ae30772a8efa25a580a0c69180068486badd69e3a71`, Ubuntu 24.04. |
| Command | `docker run --rm -v //var/run/docker.sock:/var/run/docker.sock -v <evidence>:/out aquasec/trivy image --scanners vuln --format json --output /out/st6-trivy-full.json <image>` |
| Counts | CRITICAL 0, HIGH 6, MEDIUM 41, LOW 6. |
| App layer | `app/Savia.Api.deps.json`: 0 findings. All HIGH findings are in the base image. |

| Severity | ID | Package | Installed | Fixed version |
| --- | --- | --- | --- | --- |
| HIGH | CVE-2026-109518 | apt | 2.8.3 | 2.8.4ubuntu0.1 |
| HIGH | CVE-2026-109518 | libapt-pkg6.0t64 | 2.8.3 | 2.8.4ubuntu0.1 |
| HIGH | CVE-2026-114146 | Microsoft.AspNetCore.App.Runtime.linux-x64 | 10.0.13 | 10.0.15 (also 8.0.34, 9.0.23, 11.0.0) |
| HIGH | CVE-2026-114147 | Microsoft.AspNetCore.App.Runtime.linux-x64 | 10.0.13 | 10.0.15 |
| HIGH | CVE-2026-114149 | Microsoft.AspNetCore.App.Runtime.linux-x64 | 10.0.13 | 10.0.15 |
| HIGH | GHSA-p3jp-9v83-76w9 | Microsoft.NETCore.App.Runtime.linux-x64 | 10.0.13 | 10.0.14 (also 8.0.33, 9.0.22, 11.0.0-rc.3) |

All 6 HIGH findings have a fixed version.
The fix for the .NET ones is a base-image bump from runtime 10.0.13 to 10.0.15 or later, then a digest update in `savia/Dockerfile` and a redeploy.
The `apt` fix arrives with a refreshed Ubuntu layer in the same bump.
The 41 MEDIUM findings are mostly Ubuntu libraries (libc6, libpcre2, libgnutls30t64, tar and others); see the JSON for fix status.
Files: `st6-trivy-full.json`, `st6-trivy-high-critical.txt` (derived from the JSON, no second scan), `st6-trivy-run.stdout.txt`.
Limit: vulnerability scan only (`--scanners vuln`); no secret or misconfiguration scan of the image.
The CVE ids are as Trivy printed them.

## ST-1 ZAP baseline, passive (evidence for ST-1)

| Item | Value |
| --- | --- |
| Tool | OWASP ZAP 2.17.0, image `ghcr.io/zaproxy/zaproxy@sha256:9624669db72f54d86c4b46a7064518bd9bf79d8c61a4c31befa9923489f328af` (tag `stable`). |
| Target | `https://martha-silva-preview.jason-suazof.workers.dev/` only. |
| Command | `zap-baseline.py -t https://martha-silva-preview.jason-suazof.workers.dev/ -r st1-zap.html -J st1-zap.json -m 2` |
| Counts | FAIL 0, WARN 7, INFO 0, PASS 61. The spider found 413 URLs. |
| Mode | Passive only. No active scan. Demo mode only; live mode was not tested. |

| ZAP risk | Rule | Plugin | Instances | Note |
| --- | --- | --- | --- | --- |
| Medium | CSP: style-src unsafe-inline | 10055 | 5 | The CSP header allows `'unsafe-inline'` for styles. Script policy is strict (`'self'` plus one hash). |
| Low | Cross-Origin-Embedder-Policy missing | 90004 | 1 | Header absent on `/`. |
| Low | Cross-Origin-Resource-Policy missing | 90004 | 5 | Header absent. |
| Info | Suspicious comments | 10027 | 5 | In `app.js`. |
| Info | Modern web application | 10109 | 5 | Single-page behavior. No action. |
| Info | Non-storable / storable-but-non-cacheable content | 10049 | 8 | 307 redirects and `max-age=0`. |
| Info | Re-examine Cache-control | 10015 | 5 | `public, max-age=0, must-revalidate`. |
| Info | User controllable HTML attribute | 10031 | 1 | `/catalogo?category=Gala`; the report marks it Low confidence. Needs a manual look, not an exploit. |

Seen in the live response headers: HSTS, `X-Content-Type-Options`, `frame-ancestors 'none'`, `Permissions-Policy` and `Referrer-Policy` are present.
Files: `st1-zap.html`, `st1-zap.json`, `st1-zap.stdout.txt`, `zap.yaml` (config ZAP generated).

## Control rows these results touch

| Control | Evidence here | Status after this run |
| --- | --- | --- |
| SEC-12 full-history secret scan in CI and before release | ST-4 run | Not satisfied: partial scan, not in CI. |
| SEC-26 locked builds, digest-pinned images | ST-6 image id and scan; ST-3 lockfiles unchanged | Image scanned. Digest pinning and `npm ci` are verified elsewhere. |
| SEC-27 dependency scan in CI | ST-3 clean run | Clean today. Not in CI, so the gap stays open. |
| ST-1 | ZAP baseline | Run once, passive, demo mode. 0 FAIL. |
| ST-3 | dotnet and npm | Run. Clean. |
| ST-4 | gitleaks | Run, incomplete. |
| ST-6 | Trivy | Run. 6 HIGH with fixes available. |

## Not run

| Item | Reason |
| --- | --- |
| ST-4 on the missing 34 blobs and about 320 commits | Partial clone plus a concurrent write to `.git/packed-refs`. Hydrating blobs would change `.git`; left to the parent. |
| ST-1 in live mode, ST-2, ST-5, ST-7 | Out of scope for this task. |
| Image secret and misconfiguration scan | Only vulnerabilities were requested. |
