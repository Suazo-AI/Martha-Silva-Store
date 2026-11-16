# Demo entry worker evidence

Task `savia-ux-demo-entry-20261116`. BUILD. Worker return is not primary acceptance.
Host SUAZO-PC. Codex harness, gpt-6.1-sol, high reasoning. Usage unknown.
Managed assigned worktree: `C:/Users/Jason/.t3/worktrees/github/t3-ea8e52f8-ca75655d70399b37`.
Frozen HEAD: `2c96904f49d2df913850bc13cf53b3b03ceebacf`.

Verified before edits: real build at 1440x900 and 390x844 showed password login, no role buttons, no horizontal overflow.
`python savia/tools/build_demo.py` then `python docs/savia-ux-20261116/demo/record.py before`: exit 0.
Original captures: `before-1440.webm`, `before-390.webm`, `before-recording.json`.

Verified after: matching viewport sequence enters manager, reloads, opens reset and returns to entry.
After also cancels once before confirming reset.
`python docs/savia-ux-20261116/demo/record.py after`: exit 0.
Captures: `after-1440.webm`, `after-390.webm`, `after-recording.json`.
After has role entry and no password fields or horizontal overflow at initial entry.

Existing theme source: `savia/web/app.css`; unchanged SAVIA green #124b2d, canvas #f6f5f1, surface #ffffff, ink #182921.
No brand redesign, imagery, motion, dependency or external service added.
Conversion-copy skill applied to explicit role choices and reset consequence.

`node --test savia/demo/api`: exit 0; 68 passed, 0 failed, 0 skipped. Fake API source unchanged.

First updated shell verification: exit 1 after 4 cases.
Cause: preserved etiqueta deep links now expose the fixture's expected no-open-receptions warning.
Correction: allow only that exact warning on receiving roles in etiqueta; all other alerts remain rejected.
Owner worker. Recheck passed: 32/32 viewport/theme/page/role combinations, exit 0.

Actual invented-API browser checks passed in `node --test savia/demo/site/entry.test.mjs`: 3/3 tests, exit 0; 70 browser checks.
Two earlier attempts failed an overly strict test demanding activeElement be exactly the main container.
Diagnostic readback showed `sale-search` focused inside main, role MANAGER, width and scrollWidth both 1440.
The app's working scanner autofocus is preserved. Acceptance now checks that focus is inside main.
The speculative deferred-focus change was removed; the recorded AFTER matches the final presentation.

Final small correction: a failed role switch restores the picker to the still-active role, allowing the same selection to retry.
An injected switch failure checks unchanged session token, restored selection and enabled controls, then retries through the normal switch path.
Final focused invocation passed: `python savia/tools/build_demo.py` and `node --test savia/demo/site/entry.test.mjs`, exit 0; 3/3 tests, 71 browser checks.
Focused budget used: 2 shell runs + 4 entry test runs = 6; separate fake API suite = 1.
The original BEFORE/AFTER recording captures are separate from these focused test invocations.

Verified real-browser coverage includes four roles at desktop/mobile; main focus; next role reachable with Tab;
reload; logout/re-entry; exact localStorage and sessionStorage equality after reset cancel;
confirmation locking; fictional API reset; unrelated sentinel retention; login error recovery;
duplicate login (one request); all four picker switches; duplicate reset/Escape; dialog failure recovery;
expired session; etiqueta query/hash preservation for receiving roles and seller redirect to allowed commissions.
Zero page errors, console errors, off-origin requests or actual API network requests on the completed run.
Main and entry PNGs inspected at 390px; desktop entry inspected at 1440px. No horizontal overflow in checked layouts.
Browser sessions and ephemeral loopback servers close in finally blocks. No user browser session is reused.

Verdict: RETURNED, local scoped verification passed. Primary independent acceptance pending.
Next action: primary reviews the owned diff, source bindings and recordings, then integrates serially in its authorized checkout.
Not run: full repository checks, SQL/API backend, production, physical devices, camera, full accessibility or performance audit.
The shell fixture suite separately preserves its fetch bridge checks; it does not prove real business rules.
The source/packaging test compares real auth, roles, app and etiqueta bytes with the frozen Git blobs;
it also checks test exclusion and same-origin CSP. `source-bindings.json` records SHA256 values.

Lesson: validate focus against the agreed main area, allowing the existing scanner's intentional child focus.
Evidence: failed activeElement `sale-search`, then complete browser acceptance after correcting the oracle.
No SQL, Docker, actual client data, credentials, deployment, Git staging, commit or push.
