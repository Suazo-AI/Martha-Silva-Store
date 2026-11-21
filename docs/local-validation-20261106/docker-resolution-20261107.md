# Docker startup: resolved; inability diagnosis corrected

Mode: VALIDATE. Host: SUAZO-PC. Primary: T3 Code / Codex, gpt-6.1-sol/xhigh.
Scope: explain the earlier failed handoff, verify the successful launch, and correct the shared procedure.
No product implementation, SQL test, container mutation, merge, or deployment is part of this update.

## Observed sequence

1. At `2026-11-06T21:53:08.212Z`, the primary's composite command was rejected before process creation: `blocked by policy`.
   The command combined a hidden Docker Desktop launch with a Python evidence check.
   Native call: `call_c345f6b3bdbf4591ade28c8897ad8c39`; original rollout lines 10660 and 10662.
2. The primary treated the rejection as a general inability to start Docker and repeatedly handed startup to Jason.
   That conclusion exceeded the evidence. The result did not identify the rejecting rule or the component that triggered it.
3. In Jason's supplied Codex Desktop session, he explicitly instructed the assistant to perform startup after it explained the rejection.
   The assistant submitted this standalone command through `exec_command`, using Windows PowerShell with `login=false`:

   ```powershell
   Start-Process -FilePath 'C:/Program Files/Docker/Docker/Docker Desktop.exe' -WindowStyle Hidden
   ```

   Native call: `call_fd138fcf535346689f50aac22bf61235`, rollout line 162.
   The command returned exit 0 at `2026-11-07T08:28:11.980Z`, rollout line 167.
4. That session then verified server version `29.7.2`, Linux engine readiness, and WSL's running Docker distribution.
   Its readiness report was recorded at `2026-11-07T08:29:55.159813+00:00`.
5. This primary independently ran `docker info --format '{{.ServerVersion}}'` during this correction.
   Result: `29.7.2`, exit 0, empty stderr. The startup blocker is closed.

## What explains the difference

The demonstrated operational cause was an engine that was not running. An ordinary launch resolved that condition.
The primary's process failure was an overbroad inability claim followed by an incomplete resolution path.
The successful session separated the action, used Jason's explicit authorization, and checked the real engine.

Both native session contexts declared `approval_policy=never` and `sandbox_policy.type=danger-full-access`.
Those declarations do not explain the historical policy rejection. Its exact internal cause remains unknown.
The evidence does not prove that splitting the command alone caused approval, or that administrator elevation was necessary.
The successful launch step ran under `gpt-6-astra`; that session later changed to `gpt-6.1-sol`.
This comparison therefore does not establish identical models at the two launch attempts.

Earlier documents called the failure an automatic approval review rejection.
The raw result establishes a generic policy rejection, without identifying that subsystem.
[OpenAI's current documentation](https://learn.chatgpt.com/docs/sandboxing/auto-review) distinguishes interactive Auto-review from `approval_policy=never`.
This update corrects the attribution without inventing a replacement cause.

## Applied correction and completion

The canonical `C:/Users/Jason/AI-OS/rules/task-completion.md` now requires a layer-specific inability claim,
inspection of the exact rejection, current authorization/control checks, and verification of the original failed operation.
Its existing shared pointers remain in place. No approval setting, security control, certificate, or permission was changed by this correction.
Jason explicitly requested durable learning; a small Codex memory update note records the same lesson and source identifiers.

The previous blocked command remains historical evidence. A fresh successful engine query closes its runtime-readiness consequence.
There is no reason to repeat startup while the engine is already ready.

Remaining work: the owner of the local SAVIA validation campaign must report and review its actual SQL and browser results.
This update accepts no such results, changes no runtime authority, and makes no production-readiness claim.
Fresh-session adoption by every provider remains untested; editing instructions does not prove future agent behavior.

## Source and privacy boundary

Jason supplied native Codex session `01a1b47c-2d33-7081-95e8-668b0af12c8b`.
The primary compared its launch/result records with original session `01a1aa1a-7202-7d41-a423-8bc5d06fc4b3`.
The public share URL returned no readable transcript; the local native records supplied the evidence.
Raw conversations, private prompts, local runtime reports, and machine configuration were not copied into this repository.
Historical frozen receipts remain unchanged. The global rule's original bytes were backed up before the edit.

## Validation of this correction

- `python tests/test_progress.py`: 23/23 PASS, exit 0, 204.834 seconds.
- `python tools/export_progress.py --verify`: exit 0; 15 preserved evidence hashes. No runtime executed.
- `git diff --check`: exit 0.
- Global rule verification: the added section is the only byte change; all seven existing shared pointers remain intact.
- These checks validate this documentation/rule correction. They do not accept SQL or production behavior.
