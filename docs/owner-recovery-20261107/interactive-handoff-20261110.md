# P-OWNER: interactive hand-off for the private recovery consoles (2026-11-10)

Everything that can be prepared without a human is prepared and verified. The two remaining
steps need the operator's own hands in an unrecorded private console, by design: the console
refuses redirected input, output or error, and the password must never pass through a script,
a pipe, a log or a transcript.

## Prepared and verified state

| Item | State |
| --- | --- |
| Disposable target database | `SaviaInternalTest_Golden_6d855346e4024e0fb226108a07410190` on `MSSQL$SAVIATEST`, 23 internal tables, 4 migrations applied, **0 staff rows** (bootstrap still open) |
| Transport | Windows Integrated Security + trusted TLS (locally provisioned CA and leaf) |
| `C:\ProgramData\SAVIA` | protected: SYSTEM + Administrators full, operator read/execute only, inheritance broken, owner Administrators |
| `C:\ProgramData\SAVIA\maintenance` | same rules |
| `C:\ProgramData\SAVIA\maintenance\owner-recovery.journal` | protected: operator may append but not delete, change permissions or take ownership |
| ACL verification | a script that mirrors `InternalOwnerRecoveryConsole.ValidateAcl` reports **PASS** for all three objects |
| Console guard (negative control) | running the bootstrap console with redirected stdin exits **2** with "Refused: an interactive private console with no redirected input, output or error is required." |
| Launchers | `private-exports/owner-recovery-20261110/launch-bootstrap-owner.cmd` (initial Owner) and `launch-recover-owner.cmd` (emergency recovery) |

## Step 1 — operator creates the first Owner (interactive, ~1 minute)

Run in a **new console window** (not from this chat, not through a pipe):

```
C:\Users\Jason\MARTHA-SILVA\github\private-exports\owner-recovery-20261110\launch-bootstrap-owner.cmd
```

The window prints the prompts; type:

1. `PRIVATE` then Enter
2. the owner login, 3-64 characters of letters, digits, dot, underscore or hyphen
3. the display name, 1-120 characters
4. the new password (masked with stars, minimum length per the prompt)
5. the same password again
6. the exact final authorization line the window prints, for example
   `CREATE OWNER IN localhost\SAVIATEST/SaviaInternalTest_Golden_6d855346e4024e0fb226108a07410190`

Expected last line: `Initial owner creation committed. No password was printed. Bootstrap is now closed.`
Exit code 0. Any refusal prints the reason and makes no database attempt.

Use a login and password you will not reuse anywhere else; this identity exists only inside a
disposable database that is dropped afterwards.

## Step 2 — agent prepares the protected manifest (automatic)

After Step 1 the agent reads, from SQL only, the created Owner's id, current security version,
database id and database GUID, plus `SUSER_SID()`, and writes
`C:\ProgramData\SAVIA\maintenance\owner-recovery.json` with exactly the ten properties the
console requires (`Server`, `Catalog`, `DatabaseId`, `DatabaseGuid`, `OperatorSid`, `SqlSid`,
`TargetId`, `Login`, `SecurityVersion`, `Confirmation`), then re-runs the ACL verification. The
file is protected exactly like the journal but with read-only access for the operator.

## Step 3 — operator performs the emergency recovery (interactive, ~1 minute)

The agent first rotates the first Owner's password to a value the operator does not know, so
the scenario is a real loss of access rather than a rehearsal.

Run in a **new console window**:

```
C:\Users\Jason\MARTHA-SILVA\github\private-exports\owner-recovery-20261110\launch-recover-owner.cmd
```

Type:

1. `PRIVATE` then Enter
2. the exact `RECOVER <server> <catalog> <id> <guid> <target> <login> <version>` confirmation line
   the window prints, character for character
3. the replacement password (masked)
4. the same password again

Expected last line: `Recovery committed; receipt flushed.` Exit code 0.

## Step 4 — agent verifies and cleans up (automatic)

The agent then reads the journal rows (no secret ever enters it), confirms the Owner's new hash
and rotated security version, the revoked sessions, the unchanged business tables, proves the
old password no longer works and the new one does, and finally drops the disposable database and
removes `C:\ProgramData\SAVIA`.

## Operational decisions still open for Jason

1. **Two custodians.** P-OWNER requires two enabled Owners with separate custodians and
   credentials. The API-level proof of that (second Owner recovering the first through
   `POST /internal/api/security/staff/{id}/password`) is already executed and passing
   (`InternalOwnerRecoveryHttpSqlTests.F14`, see `runtime-20261110.md`). What remains is the
   human part: naming the two custodians and who holds each credential.
2. **Windows operator identity.** The recovery console validates the operator SID against the
   manifest and requires the protected objects above. The local proof used Jason's own account
   (`S-1-5-21-3070145050-454918991-3214582734-1001`). A production decision needs a dedicated
   custodian account and the ACLs that grant it exactly this role.
3. **Rollback of the local TLS provisioning.** The certificate and CA added for this proof are
   reversible; the readback and rollback steps are in
   `C:\Users\Jason\.savia-private\host-tls-provision-20261110\readback.json`.

## Limits

- Nothing here touches production, real accounts or real money. The database is disposable and
  every identity in it is synthetic.
- The interactive consoles must never be run through CI, a pipe, a transcript, a terminal
  recorder or a remote automation runner; that is the operator's responsibility.
- The evidence from these steps is bound to the local instance and the locally provisioned
  certificate; it does not discharge the release gates.
