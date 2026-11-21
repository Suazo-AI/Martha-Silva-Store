# Seller ticket UUID correction

Status: implemented and verified offline; independent acceptance pending.

Source base: `ba8ff2ba10935e99fc268ebbe5eae130f72c1cca`.
Host: `SUAZO-PC`. Primary: T3 Code/Codex, `gpt-6.1-sol/xhigh`.

The seller ticket called `crypto.randomUUID()` directly, although the shared
`uuid()` helper supports environments where that API is unavailable.
`sale-logic.mjs` now uses the existing helper. No new generator was added.

## Verification

- Before correction: `node --test savia/web/tests/uuid.test.mjs` exited `1`;
  one pass and one failure: `TypeError: crypto.randomUUID is not a function`.
- After correction: `node --test savia/web/tests/*.test.mjs` exited `0`;
  **83 passed, zero failures and zero skips**.
- The regression removes the API temporarily, checks distinct seller-line keys,
  merging, quantity changes, removal and seller attribution, then restores the API.

[RESULT.json](RESULT.json) binds the two sources and records the commands.
Full output is retained in ignored
`private-exports/merge-readiness-20261116/corrections/uuid-checks.json`.

This models an unavailable browser API in Node. It does not prove operation in a
real LAN browser, on a physical phone, against SQL or in CI.

Next: review the integrated correction with Astra/xhigh and verify the final
candidate under a separately authorized runtime packet. No push or merge occurred.

## Primary architecture correction

The first reuse imported the HTTP module into sale logic; `savia/tools/rules.py` rejected that dependency. The existing generator now lives in `uuid-logic.mjs`; the API keeps its public export. Fresh web: **83/83**, zero skips, exit 0. Fresh architecture/migration rules: **9/9**, exit 0. See `RESULT.json` for commands, bindings and private log hashes. No browser or LAN execution.

Lesson: verify architectural dependencies when reusing a working helper; behavior-only tests do not prove module boundaries.
