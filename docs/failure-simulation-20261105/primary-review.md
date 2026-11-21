# Primary review and public integration

Scope: bounded SAVIA failure simulations on SUAZO-PC. Base: Tony@7d61524e29b4286055d44d145475a0a76195e1ba.
Primary: T3 Code / Codex, gpt-6.1-sol / xhigh. Accepted with limits after independent critic and jury reviews.
Standing critic: gpt-6.1-sol / high. Standing jury: gpt-6-astra / high. Open material findings: zero.

## Verified artifact

The primary read the test assertions, real module interfaces, worker evidence and independent critic report.
All ten worker hashes matched before review changes. The staff CI glob includes the new test.
No product defect was reproduced. No product source changed; there is no demonstrated product fix to apply.

The critic accepted the bounded claims with two optional P3 observations:

- F03 injects a storage deletion across clear/start generations. This proves an adversarial invariant under that constructed state, not an ordinary user journey. The worker README already discloses the injection. This limitation remains explicit.
- F07 initially had an empty-stock oracle without a populated baseline. The primary replaced its malformed initial stock response with one valid stock row and asserted that SKU SYN-2 is rendered before revocation. The delayed POST, revoked session, hidden receipt, empty DOM and unchanged pending-operation assertions remain.

The jury confirmed the correction. Stock refresh itself clears the table before the 401 arrives.
F07 therefore proves the final revoked state and exclusion of the late sale result; it does not isolate stock clearing specifically to clear().

After the F07 change, the primary ran focused 50/50 and full staff 102/102, exit 0, without skips or cancellations.
Commands, direct process exit codes, before/after source hashes, log hashes and durations are in [PRIMARY-RESULT.json](PRIMARY-RESULT.json).
Source hashes remained stable during both commands. These runs validate the revised test, not the earlier worker test hash.
The original RESULT.json, MATRIX.json, README and critic report remain historical, unedited evidence of the earlier revision.

Ten families include eight receipt corruption classes and 32 deterministic quantity/order samples.
The 192 actions count six fixed steps per sample. This is not an exhaustive failure search or 32 independent business scenarios.
Node counts 48 leaf tests and two parent tests in the focused total of 50.

## Public evidence and exclusions

The hook blocks .log files. Original UTF-16 worker logs stay local and unmodified.
Their reviewed synthetic test output is exported as focused.sanitized.txt and staff-glob.sanitized.txt, UTF-8 with normalized newlines.
RESULT.json hashes named focused.log and staff-glob.log refer to those original bytes, not the public exports.
The revised primary run has separate UTF-8 TAP exports and hashes in PRIMARY-RESULT.json.
No real HTTP payloads, credentials, client sessions or customer data were used in these tests.

Jason separately authorized importing exactly four public agent-awareness files from
C:/Users/Jason/MARTHA-SILVA/test-runs/agent-awareness-20261104/docs/agent-awareness-20261104
to [docs/agent-awareness-20261104](../agent-awareness-20261104/README.md):

- README.md: a8a9ab69c60fe958b6b19d79901c157b17d0782d86dcf4bdfab4661835ce5f2e
- verification.json: eaf3856944383e6c82e2a0bc57e0b5ff5af6f4d2bb6c09537c5b801924f5f905
- bin/agent-awareness.py: fb44b389a11b69b86cca7927de9c574c4fd55b20e6a2f0014dff93bf49af0a19
- tests/test_agent_awareness.py: c67544e5e518be8e2cd4338336c598f0bdca81e08c95305cc11530c2a7d6b8cb

The primary read all four files, checked source hashes against verification.json, and verified byte-exact copies.
An index comparison detected Git normalizing CRLF in the imported README.
Narrow .gitattributes rules preserve both archival folders' bytes, including hashed JSON evidence.
They recognize CRLF line endings and retain trailing-space and space-before-tab checks.
The publication check compares staged blobs with their local originals, including all four authorized imported files.
Excluded the additional bin/__pycache__/agent-awareness.cpython-311.pyc; copied no snapshots, private configuration, conversations or backups.
These are archival source copies, not installers or active hook changes.
The originating worker reports six passing tests, two direct hook invocations and closed critic/jury findings.
The primary verified import integrity and ran the installed read-only detector; it did not independently repeat the hook tests or install configuration.
Actual automatic loading in a new Codex session and a new Claude session remains NOT RUN.

## Acceptance limits and next actions

The fault suite exercises actual staff modules in jsdom with simulated HTTP, storage failures and response scheduling.
It proves no new real backend, SQL durability, browser/device, layout, payment or operational acceptance.
F03's constructed state is an explicit coverage limit, not an unresolved demonstrated product defect.
N5-COV browser criteria and C2/C9/C10 remain open; existing SQL/TLS restrictions are unchanged.

Publication checks and environmental failures are recorded in [PUBLICATION-CHECKS.json](PUBLICATION-CHECKS.json).
The progress-hook regression passed 23/23; export verification exited 0.
The general command python tests/check.py exited 1 at asset-audit.py: three fixture errors creating symlinks, WinError 1314.
The OS denied the fixture operation; subsequent stages of that general command did not run.
No privilege or test expectation was changed. The shortest authorized alternative is the existing Tony source-snapshot CI on Ubuntu, which runs the same general command with locked dependencies.
Owner: primary verifies that run for this publication SHA; a remaining product-contract failure goes to the existing P-LEGACY issue #4 with its exact evidence.
This Windows environment failure remains recorded even if Linux passes.
Tony CI checks publication, digest and historical portable regressions. It does not trigger savia.yml; that workflow includes the new staff test for future main/PR execution.
The new staff-suite evidence in this publication is local; no full SQL workflow is dispatched.

Next action: primary publishes explicit reviewed paths to Tony, verifies remote SHA and applicable CI, and reports any failed check without implying full project readiness.
For automatic hook loading, the next-session coordinator must observe AGENT AWARENESS during a normal new session in each client.
Use the client's normal trust approval if requested; do not edit trusted_hashes.
