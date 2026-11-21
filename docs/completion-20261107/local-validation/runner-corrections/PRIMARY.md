# Primary integration: local runner

Status: imported for independent review; runtime NOT READY; production NO-GO.

Host: SUAZO-PC. Primary: T3 Code / Codex / gpt-6.1-sol, exposed xhigh.
Worker: Codex gpt-6.1-sol/high; base `70e7549062e6919f36c0f36ba21d7a54999a7d9d`.
Canonical import base: `92b90683a3e8a1b1ba01f372fe33c115a58b2469`.

Primary verified the seven declared file bindings, then imported those files and the worker result.
All eight destination paths were absent. Existing inputs and unrelated changes were preserved.
The shared [import receipt](../../../session-csrf-20261107/primary-integration.json) records exact RAW and LF hashes.

Primary ran `python tools/local-validation/test_run_local_validation.py` in the canonical checkout.
Result: 39/39 PASS, exit 0, 44.309 seconds. This includes nine controls reproducing old defects.
The private log is `private-exports/integration-20261107/runner-tests.log`.
Python compilation and Git Bash syntax parsing also exited 0.
These checks use fake process adapters. They did not start Docker, SQL, a browser or a network installation.

The Dockerfile deliberately stops before creating a runtime image. The offline result does not qualify it.
Current blockers and concrete next actions:

| Blocker | Cause or evidence | Next action and owner | Completion check |
| --- | --- | --- | --- |
| Independent acceptance | Corrected source has not received a new Astra verdict | Primary freezes source and requests Astra/xhigh | Exact-source verdict and findings resolved |
| Image/dependency qualification | No completed image or reviewed dependency closure | Primary prepares the bounded build inputs and scope; Jason approves material network/runtime effects | Immutable image receipt with dependency and tool checks |
| Private evidence destination | Actual Windows destination privacy is not yet proved | Primary checks an existing empty target without changing ACLs | Protected DACL and current-user-only permitted access |
| C77, D and E2 | Neither this import nor fake-process checks ran them | Primary prepares exact-source campaign after the previous gates; Jason authorizes runtime scope | Real outcomes, full evidence checks and owned-resource cleanup |

No new runtime scope is inferred from the import. No source, image or evidence is declared production-ready.
The canonical `python tests/check.py` exited 0. Staff passed 152/152 and localization passed 17/17.
`python tests/test_progress.py` passed 23/23; the progress exporter preserved 15 historical hashes.
Next: publish the explicit candidate paths and request Astra/xhigh review. The runtime blockers above remain open.
