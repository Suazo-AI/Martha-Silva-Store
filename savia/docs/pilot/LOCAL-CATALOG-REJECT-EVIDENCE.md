# Local catalog and scan rejection: local build evidence

Run date: 2026-11-12. Scope: SAVIA v2, one Masaya branch on this Windows PC.
No cloud API, deployment, commit or push.
The pre-existing staged pilot work is preserved. The web client, simulator and V011 are outside this change.

## Red before the fix

`python savia/tools/db/saviadb.py test reject_scan` exited **1** before V012 existed:

```text
FAIL    receiving/152_reject_scan.sql  -- Msg 2812, Level 16, State 62, Server 23b66448cd53, Line 12
FAIL    receiving/153_reject_scan_guards.sql  -- Msg 2812, Level 16, State 62, Server 23b66448cd53, Line 12
SUMMARY FAIL=2
Could not find stored procedure 'receiving.usp_RejectScan'.
```

The focused .NET command used the local SDK selected by `savia/tools/check.py`:

```powershell
python -c "import sys; sys.path.insert(0,'savia/tools'); import check,subprocess; sys.exit(subprocess.call([check.dotnet(),'test','savia/tests/Savia.Tests','--filter','FullyQualifiedName~LocalCatalogRejectTests','-v','minimal']))"
```

It exited **1**, with three failures and two passes:

```text
Unknown_code_registered_via_local_api_resolves_and_becomes_stock [FAIL]
expected success but got 404:
Reject_endpoint_authorizes_scopes_audits_and_posts_only_matched_units [FAIL]
expected 401 auth.required but got 404:
Local_catalog_requires_manager_and_branch_access [FAIL]
expected 403 auth.role_required but got 404:
Failed! - Failed: 3, Passed: 2, Skipped: 0, Total: 5
```

The two passing cases prove the catalog remains absent when the flag is omitted or false.

## Green after the fix

The same SQL command exited **0**, `SUMMARY PASS=2`.
The same focused .NET command exited **0**:

```text
Passed! - Failed: 0, Passed: 5, Skipped: 0, Total: 5
```

Additional regression coverage then added cloud permissions with both flag values,
rejection error mappings, an all-rejected session and a negative conservation control.
The full check then built and ran the expanded .NET coverage: **26 passed, 0 failed, 0 skipped**.

## Full check

`python savia/tools/pilot.py down` exited **0** before the check.
`python savia/tools/check.py` exited **1**, with only the two V011-related SQL failures below.

```text
PASS  baseline is generated from the handoff
      OK: V001__baseline.sql matches the generator output.
PASS  no DELETE or TRUNCATE on synced tables
      18 synced tables, 0 physical deletes
PASS  database container
      16.0.4305.5 Developer Edition (64-bit)
FAIL  T-SQL tests
      FAIL sync/110_change_tracking_sees_a_sale.sql -- ASSERT FAIL: tracked tables expected=6 actual=18
      FAIL sync/140_source_state.sql -- ASSERT FAIL: one row per tracked table expected=6 actual=18
      SUMMARY FAIL=2 PASS=123
PASS  .NET build
PASS  .NET tests on real SQL
      Passed! - Failed: 0, Passed: 26, Skipped: 0, Total: 26
RESULT FAIL
```

Untracked `savia/db/migrations/V011__sync_tracking_all_owned.sql` expands tracking from 6 to 18 tables.
The two existing sync assertions still expect 6. V011 and those unrelated tests were not edited.
The final complete SQL rerun includes the last added all-rejected-session regression.

`python savia/tools/db/saviadb.py test --jobs 4` ran the **full** final suite and exited **1**:

```text
PASS receiving/152_reject_scan.sql
PASS receiving/153_reject_scan_guards.sql
PASS receiving/154_all_rejected_no_receipt.sql
FAIL sync/110_change_tracking_sees_a_sale.sql -- ASSERT FAIL: tracked tables expected=6 actual=18
FAIL sync/140_source_state.sql -- ASSERT FAIL: one row per tracked table expected=6 actual=18
SUMMARY FAIL=2 PASS=124
```

All 126 SQL tests ran; there were no XFAIL, skips or invalid cases.
The 152 test also proves that an unknown scan in a posted session still makes the conservation oracle throw 59100.
A source comparison confirmed that V012 preserves every other V009 conservation check exactly.
`git diff --cached --check -- savia` exited **0** after staging.

## Two consecutive pilot cycles

For each cycle, run these commands in order, with a random `SAVIA_PILOT_PASSWORD` held only in the shell environment:

```powershell
python savia/tools/pilot.py reset
python savia/tools/pilot.py up
python savia/tools/pilot_smoke.py
```

| Cycle | Reset exit | Up exit | Smoke exit |
| --- | --- | --- | --- |
| 1 | 0 | 0 | 0 |
| 2 | 0 | 0 | 0 |

Both smoke runs printed these key lines:

```text
ok   approval refused while a code is unresolved (409)
ok   new catalog item has no stock before posting
ok   second unknown code recorded for rejection
ok   supervisor resolved the unknown code after API catalog registration
ok   second unknown retained as rejected; retry is safe
ok   rejected units do not need review
ok   approved and posted
ok   API-registered item stock rose from 0 to 1; rejected units excluded
ok   stock rose by 5 (0 -> 5)
ok   cash sale of 2 dropped stock by 2 (5 -> 3)
ok   till closed: expected 219800, counted 219800, difference 0
ok   audit.usp_CheckConservation @Throw=1 passed on SAVIA_DEV_pilot
```

`python savia/tools/pilot.py down` then exited **0**. The local API is stopped.

## Files staged for this increment

Only these explicit paths were added to the index. Existing staged work in shared files is retained.

```text
savia/db/migrations/V012__reject_scan.sql
savia/db/tests/receiving/152_reject_scan.sql
savia/db/tests/receiving/153_reject_scan_guards.sql
savia/db/tests/receiving/154_all_rejected_no_receipt.sql
savia/docs/pilot/API-PILOT.md
savia/docs/pilot/LOCAL-CATALOG-REJECT-EVIDENCE.md
savia/src/Savia.Api/Endpoints.cs
savia/src/Savia.Application/Core.cs
savia/src/Savia.Application/Modules.cs
savia/src/Savia.Contracts/Contracts.cs
savia/src/Savia.Domain/Errors.cs
savia/src/Savia.Infrastructure/ServiceRegistration.cs
savia/src/Savia.Infrastructure/Stores.cs
savia/tests/Savia.Tests/LocalCatalogRejectTests.cs
savia/tools/pilot.py
savia/tools/pilot_smoke.py
```

## Behavior and limits

- `Savia:Pilot:LocalCatalog` defaults to false. The pilot runner enables it.
- Existing MANAGER (including the sample supervisor) and OWNER roles can register catalog entries locally.
  Branch access is still required. Catalog business rules remain in the existing SQL procedures.
- V012 uses the existing `rejected` CHECK value and NULL-item rule. It preserves each scan.
  `ResolutionReason`, `ModifiedBy` and `ModifiedAt` hold the first rejection audit record.
- The procedure locks the parent session before changing a scan, so rejection serializes with approval/posting.
  Rejection and retries require `counting`. Matched scans cannot be rejected; rejected scans cannot be resolved.
- Progress, approval, posting and conservation exclude rejected quantities. Unknown and ambiguous scans still block approval.
  A session containing only rejected scans cannot create an empty receipt.
- The smoke script registers through HTTP only. Its only SQL call is the conservation oracle.
- No visual/mobile/accessibility checks, printer hardware, card payments or multi-node synchronization are claimed.

Next action: run the local pilot client against these documented request shapes; coordinate web changes separately.
