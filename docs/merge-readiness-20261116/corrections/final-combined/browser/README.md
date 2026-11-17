# Return browser validation

Worker verdict: PASS, 22/22 fresh Chrome cases. Primary acceptance remains pending.

Task: `savia-pr7-return-browser-ba8ff2b-20261116-01`.
Host SUAZO-PC; Codex `gpt-6.1-sol`; requested/exposed reasoning `high` (T3 and harness metadata). Usage/cost unknown.
Base `ba8ff2ba10935e99fc268ebbe5eae130f72c1cca`.
Overlay RAW SHA256 `ac0465e96c6a0f2a5b95023d0bc1cc3b46d7a96235dad2f665ac581fb0a742e9`.
53 exact entries verified before extraction. 17 source paths frozen; all unchanged at close.

Actual return ES module, shared DOM/dialog and actual CSS mounted through a controlled context. Fake HTTP ran only on an ephemeral owned 127.0.0.1 server. No production system proof.
Desktop 1280x900 DPR1. Mobile 390x844 DPR2. Installed channel Chrome headless.

## Fresh results

| Case | Desktop | Mobile |
| --- | --- | --- |
| ordinary-credit | PASS | PASS |
| ordinary-cash | PASS | PASS |
| ordinary-transfer | PASS | PASS |
| exchange-initial-200 | PASS | PASS |
| exchange-loss-remount-404-get-replay | PASS | PASS |
| draft-remount-cancel-keyboard | PASS | PASS |
| wrong-post-status-preserves-uncertainty | PASS | PASS |
| held-post-retire-cleanup-false | PASS | PASS |
| held-post-retire-cleanup-true | PASS | PASS |
| late-approval-retire-no-post | PASS | PASS |
| held-lookup-retire-no-ui-effect | PASS | PASS |

Independent fixtures expect NIO 123.45 from one of three items (370.35 total), a 150.00 replacement, and a 26.55 transfer with PAY-REF.
Checks assert captured exact endpoint/body, sending readback before dispatch, POST counts, durable pending IDs/body, confirmation focus, keyboard Enter/Space, receipt links, monetary rendering and reload.
GET cannot confirm an exchange. Explicit replay produces two identical POST bodies after response uncertainty. Remount and 404 produce zero extra POSTs.
Retirement revokes approval once before releasing held POST. Failed logout notifies once. Late login cannot POST. Held lookup cannot mutate retired UI.

## Commands and preserved attempts

Each invocation used Python subprocess with UTF-8 capture and actual Node returncode, no PowerShell stderr inference:

```powershell
node docs/merge-readiness-20261116/corrections/final-combined/browser/run.mjs run1
node docs/merge-readiness-20261116/corrections/final-combined/browser/run.mjs run2
node docs/merge-readiness-20261116/corrections/final-combined/browser/run.mjs run3
```

- Run1 exit 1: 18/22; pre-header socket loss caused Chrome transport retransmission. Preserved, not product acceptance.
- Run2 exit 1: 12/22; corrected transport fixture passed; runner encoding and async assertion defects remained.
- Run3 exit 0: 22/22; final complete invocation. Three-invocation limit reached.
- Exact argv, elapsed time, stdout/stderr: `run1-child.json`, `run2-child.json`, `run3-child.json`.
- Eight expected console errors in final run: two deliberate truncated responses, one 404 and one failed logout per viewport. Zero page errors and unexpected external requests.
- `run3/RESULT.json` binds served module/CSS RAW/LF bytes and exact request/readback evidence. `bootstrap.json` binds all 17 sources.

## AFTER artifacts

- [Desktop video](run3/desktop-AFTER.webm), VP8 1280x900, 7.20 seconds.
- [Mobile video](run3/mobile-AFTER.webm), VP8 390x844, 8.84 seconds.
- [Desktop result](run3/desktop-exchange-result.png).
- [Mobile result](run3/mobile-exchange-result.png).
- [Mobile uncertainty](run3/mobile-response-loss.png).
- [Mobile recovered result](run3/mobile-exchange-recovered.png).
- Both videos passed ffprobe exit 0; `run3/video-probe.json` contains exact commands.
- Screenshots were directly inspected. Full temporal video review was not performed. Recordings include fast automated transitions.
- Actual BEFORE was not captured. No reconstructed BEFORE exists.

## Closure and limits

Only owned browser/server resources were terminated. Loopback connection probe failed after server close, confirming resource closure. Final source RAW hashes matched all 17 bootstrap inputs.
No product changes after input extraction. No stage/commit/push, GitHub mutation, SQL, Docker, install, real API/account/payment, paid API or external messaging.
SQL runtime, real persistence, full app integration and CI NOT RUN. Emulation does not certify physical devices or accessibility.
Source-bound historical unit/SQL evidence was not rerun or promoted to fresh evidence.

No reproduced product blocker remains in these bounded cases. Earlier failures are classified and preserved in RESULT.json.
Next owner: primary orchestrator verifies evidence and obtains Astra/xhigh independent judgment. This worker does not authorize merge.

Lesson: simulate lost responses after headers to distinguish browser transport retransmission from application replay. Use UTF-8 and await observable async control restoration.
