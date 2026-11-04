# C9 metadata preflight: FAIL_CLOSED

The single reviewed connection attempt failed certificate-chain validation.
No SQL statement was attempted. C9 remains open; this is not recovery, RTO/RPO or Owner-recovery evidence.

Host: `SUAZO-PC`. Executor: `gpt-6.1-sol / xhigh`.
Target: the approved local `SAVIATEST` instance, explicit Shared Memory transport, `master`, Windows integrated authentication.
TLS policy: `Encrypt=True;TrustServerCertificate=False`; no certificate/hostname override.

## Exact result and evidence

| Field | Observed result |
| --- | --- |
| Started UTC | `2026-11-04T04:49:54.9607047Z` |
| Finished UTC | `2026-11-04T04:49:55.0501447Z` |
| Runner elapsed | `88 ms` |
| Process exit / runner exit | `1 / 1` |
| Open calls attempted | `1` |
| Open calls completed successfully | `0` |
| SQL statements attempted / completed | `0 / 0` |
| Connection finally closed/disposed | `true` |
| Exclusive durable attempt latch | Present and retained privately; consumed, never removed/reused. |
| Base error type | `System.ComponentModel.Win32Exception` |
| Base error HResult | `-2147467259` |
| Exact sanitized error | `The certificate chain was issued by an authority that is not trusted.` |
| Mutation statements issued by this tool | `0` |
| Persistent-state equality | NOT PROVED; no full state-diff audit was performed. |

The successful-session count means completed Open calls in this runner, not a server-wide session audit.
The frozen runner reached its one Open call, caught the failure, closed/disposed the connection, and returned failure.
No second attempt, reconnection, fallback, alternate client or transport followed.

## Requested fields

PASS OS means a Phase A OS/filesystem observation, not SQL readback.

| Requested field | State | Evidence / limit |
| --- | --- | --- |
| Host and Windows operator | PASS OS | Approved host/operator matched; operator SID retained privately. |
| Installed client/path/version | PASS OS | Existing System.Data client; assembly `4.6.1.6`, file `4.900.126.11103`; path/hash retained. |
| SAVIATEST service state/identity | PASS OS | Service observed Running; service identity retained privately. No service action issued. |
| Registered instance/edition/version | PASS OS | Registry reports `Standard Developer Edition`, `17.0.1000.7`; runtime SQL readback NOT RUN. |
| Existing protocol configuration | PASS OS | Shared Memory enabled; TCP/Named Pipes disabled. Actual SQL session transport NOT RUN. |
| TLS certificate validation | FAIL | The existing client rejected certificate-chain trust under the frozen validation policy. |
| Effective certificate / issuing CA | NOT RUN | The attempt did not capture these identities; a blank registry binding does not identify the presented certificate. |
| Current-session TLS encryption/authentication | NOT RUN | Open failed before the first metadata SELECT. |
| SQL machine/server/instance/edition/version | NOT RUN | First SELECT never executed. No runtime destination identity is claimed. |
| SQL original/effective operator and SID | NOT RUN | Windows identity is known; SQL identity was not read. |
| Current operator SQL roles/visibility/permissions | NOT RUN | No SQL statement executed. No permission grant attempted. |
| Expected Windows API account/SID | PASS OS | Existing enabled local account; SID retained privately. |
| Expected API SQL identity/SID/direct roles/explicit permissions | NOT RUN | No SQL statement executed; API access/inherited rights remain unknown. |
| SQL default data/log/backup paths | NOT RUN | Phase A registry values retained privately; SERVERPROPERTY readback never ran. |
| Candidate-path existence/volume/free-space/ACL | NOT RUN | Runner did not reach the OS candidate-path stage. No path/file was created there. |
| Two reserved synthetic database-name collisions | NOT RUN | Names were not queried. Absence is not inferred. |
| SELECT-only execution boundary | PASS | Frozen allowlist; actual statements attempted `0`. |
| Recovery, RTO, RPO and Owner recovery | NOT RUN | Outside this preflight scope. |

## Frozen provenance

| Artifact | SHA256 |
| --- | --- |
| `preflight-once.ps1` | `7609449dea774770a8e8a1a765fe13c422df05e3f8fd20b2a94ec1ac6f5c2b9a` |
| `queries.frozen.json` | `ef3962a3f90cad22af4d6dde489714564be2da963756d040692d4944451a9b56` |
| `plan.json` | `6f18f1faf889b3de7cda144cdc47d8dca529253290246200290243bde98503bc` |

The exact command, timings, invocation hashes and latch evidence are retained in `execution-evidence.private.json`.
The raw runtime metadata/error remain in `result.private.json`; the field-level summary is `result.sanitized.json`.
No execution/approval receipt, SID, private path, credential, certificate/key, business data or private connection string is included here.
All writes stayed below this coordination folder. The checkout, C11, Git and Trello were not modified by this worker.

## Blocker ownership and exact next action

Observed cause: this installed client could not validate the presented certificate chain against existing trust.
The exact certificate, issuing CA, missing chain element or configuration defect is unknown; do not infer one from the registry binding.

Correction attempted: none. Trust/certificate/security/service changes and another connection attempt are outside this consumed batch.
Safe response completed: stop after the first failure, retain the durable latch/error, close/dispose, and report every unread field as NOT RUN.

Next action, owner **primary**: prepare a separate, bounded certificate/trust investigation for `MSSQL$SAVIATEST` on `SUAZO-PC`.
Identify the effective SQL certificate and chain before proposing any correction; retain `Encrypt=True;TrustServerCertificate=False` and the approved endpoint.
Owner **Jason / SQL administrator**: decide any certificate/trust/configuration change and any fresh connection attempt under a separate scope.
Do not set `TrustServerCertificate=True`, relax encryption, switch transport or reuse this latch to obtain metadata.

Completion check for a future separately authorized attempt: certificate validation succeeds, the approved SQL identity/instance and current-session encryption are read, every allowed field is classified, and no mutation/retry is issued.
This preflight remains failed and C9 remains open until the missing evidence is obtained under that separate scope.

Lesson applied: OS configuration and constructor parsing do not prove TLS trust; only the actual connection exposed this gap.
The one-shot guard prevented using a fallback or retry to hide the failure.
