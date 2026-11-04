# SAVIA fixed candidate — focused API/contract re-review

## Verdict

**The prior P2 capability-validation finding is closed by static inspection. No obvious new P1/P2 regression was found in this patch.** This is a source review, not a new automated-test, browser, backend, or SQL execution result.

## Closure evidence

- `dev/savia-demo-ui/api-client.mjs:29–35` enumerates all eleven capabilities and requires the exact key count and boolean values. Missing flags, additional flags, nonboolean values, enabled commercial operations, and changed SAVIA reservation support cannot pass.
- `:36–44` requires a two-entry provider list containing SAVIA with exact authority/implementation status and CGA with null authority/unverified implementation. Both SQL-verification values must be `not_verified`, matching the only permitted enum in `contracts/openapi-v2.json:1114–1118`.
- The SAVIA flags are six true and five false; CGA flags are all false. These match the actual static reports in `backend/src/Martha.Store.Api/ErpPort.cs:23–26`.
- The old duplicate-provider mismatch is closed: accepting one SAVIA and one CGA within exactly two entries leaves no additional/earlier unvalidated SAVIA entry for the SQL-status `.find()` at `api-client.mjs:91` to select. Provider order does not affect this logic.
- The previous tiny repro (`sqlVerification: 'verified'` with otherwise valid reads) now fails at `:42`. The capabilities assignment at `:66` is skipped, a failed check is recorded, aggregate state cannot be `ready`, and returned SQL status falls back to `not_verified` at `:91`.
- `api-client.test.mjs:9–14` now uses the complete two-provider fixture. The new test at `:51–67` covers unsupported SQL status, a missing required flag, SAVIA sales/payments, enabled CGA reservation, non-null CGA authority, and a duplicated provider; it asserts partial state, null capabilities, unverified SQL and disabled transactions. These tests were **read, not executed** by this reviewer.

## Regression check

The diff is limited to the capability validator and its tests. The following code is unchanged apart from line-number movement:

- Fixed root-relative GET paths; credentials omitted; redirects rejected; no request body, authorization header or new network target (`api-client.mjs:3–7,51–58`).
- HTTP/content-type/readiness checks, abort handling and sanitized errors (`:59–63,76–83`).
- Exact synthetic SAVIA authority, single-item XXX catalog and stock arithmetic checks (`:8–26`).
- No operation enabling or simulation/ERP fallback; `transactionsEnabled: false` (`:85–92`).
- `app.mjs` is byte-identical, preserving separate USD memory model and XXX diagnostic rendering.

**Compatibility limit, not an established defect:** the fixed validator explicitly requires both known providers and freezes their exact current capabilities. That matches the two reports supplied in `ErpPort.cs`, but is stricter than the generic `providers` array schema at `openapi-v2.json:1145–1149`. The actual endpoint response constructor is not in this 15-file snapshot, so live response compatibility remains unverified here; a future intentional capability/provider change will require the validator to change. Unknown additional properties on report/provider/authority objects are still not universally rejected; this patch closes the reported semantic P2, not every possible OpenAPI schema deviation.

## Identity and authorization record

- Reviewed target: `/workspace/scratch/14cff504045e/savia-candidate-fixed/source`.
- Independently recalculated byte counts and SHA-256 for all 15 entries in `../verified-inventory.json`: **15/15 match**.
- Compared all 15 files against the previous candidate: **only `api-client.mjs` and `api-client.test.mjs` changed**; all other 13 are identical.
- Fixed client SHA-256: `e4046e4f6d1c0d30c309c92d8a3db80a23ed8208560d3cb19f4b1ac669799d0c`.
- Fixed test SHA-256: `6ae3f36a87c10b1411584bc36a009613f35f32f49f30bd81b0cd6de71095e544`.
- Unchanged app SHA-256: `7a09458daace594cf151746c6b2abdb8791142c80df4f35e6724256c3fa3a3a9`.
- Parent-verified patch/inventory identifier: `c62c8856da489b2465fc11e94cc882dba3fe3a9f4d9976b887108237213ce8cd`; archive/patch bytes themselves were not independently hashed in this review.
- Completed: read-only source/diff/fixture review and file hashes. No source edits. This report is the only deliverable write.
- Pending with separate owner: test execution and any authorized integration/runtime validation. `/health/ready` implementation and actual endpoint constructor remain absent from the snapshot; no SQL/backend/deployment claim is made.
- Denied or retried operations: none. No Windows/browser/deploy/network operation or permission escalation was attempted.
