# Cloudflare skills and focused security review

Host: SUAZO-PC. Date: 2026-11-05. Primary: T3 Code / Codex / gpt-6.1-sol / xhigh.

## Installed and verified

Four skills are installed in this project's `.agents/skills/` directory.
The existing design skill and global settings were preserved.

| Skill | Purpose | Upstream revision |
| --- | --- | --- |
| `cf-cli` | Find Cloudflare API commands and verify their request shape. | `cloudflare/skills@1f2cd0a19588e2c6197c91dd7c71729df1fb6156` |
| `wrangler` | Use this project's existing Wrangler configuration. | Same revision |
| `workers-best-practices` | Review Worker source, configuration and runtime assumptions. | Same revision |
| `security-audit` | Trace security boundaries and independently verify candidate findings. | `cloudflare/security-audit-skill@c1c8a8c1471069fb0e188eeaff69b8e8db6564a8` |

Sources: [Cloudflare skills](https://github.com/cloudflare/skills) and
[Cloudflare security-audit skill](https://github.com/cloudflare/security-audit-skill).
Installation used the official Codex `install-skill-from-github.py` helper with explicit revisions and a project destination.
Both install commands returned exit 0.

The parent read the four SKILL instructions, inspected executable import and I/O sites,
and checked documentation for suspicious instruction patterns.
All 29 installed upstream files match the reviewed copies by SHA256.
Four upstream license files were added without editing their contents.
[INSTALL.json](INSTALL.json) records source revisions, paths and hashes.
Its RAW hashes describe installation bytes. Its LF hashes support Git checkout verification across line endings.
No bundled script was executed. This review does not prove that third-party code has no defect.

Fresh-session automatic discovery is NOT RUN. The primary loaded the reviewed instructions directly.
A new agent turn/session can discover the installed project skills.
No global rule, MCP connection, authentication profile, Cloudflare account or deployed Worker changed.
The native plugin and its remote MCP servers were not installed.
Initial Git staging excluded `.agents/` under the existing sparse checkout.
Explicit `git add --sparse` staged only the four installed skill directories; sparsity rules were preserved.

## Bounded first use

Mode: focused guidance and read-only source review, not the skill's full six-phase audit.
Review source: public `Suazo-AI/Martha-Silva-Store`,
`6d8d53c964ca07cf173e3683a7660624d955aa4c`.
GitHub's repository API returned `private: false`, `visibility: public` during this setup.
Uncommitted frontend and hardening candidates are outside this source revision.

The first worker uses `opencode/glm-5.3-flash-free` through OpenCode,
with `variant: high` and `agent: build`, in a managed worktree.
Scope: API mounting, session lifecycle, CSRF, role/branch checks and the static deployment boundary.
The worker may inspect only committed public source and the pinned public skill documents.
No credentials, `.cloudflare/` state, environment values or client data enter the task.
One bounded worker is followed by independent Gemini 4 Argon review through Antigravity,
with `thinking_level: high`. No paid model fallback is authorized.
Actual admission, effective settings and returned evidence remain unverified until each task returns.

Acceptance: exact source locations, principal/input/control/result for each candidate,
explicitly traced existing protections, smallest proposed correction and a safe validation check.
Missing headers or generic best-practice deviations alone are hardening notes.
No candidate becomes a confirmed vulnerability without independent evidence.
Primary retains final acceptance. The frontend completion worker keeps its separate ownership.

## Execution limit and next action

The skill requires an OS-enforced sandbox for target-code execution:
no external network, an allowlisted environment, read-only source/toolchain,
scratch-only writes and explicit resource limits.
It states: "If every control cannot be enforced, do not execute target code".
See [the installed skill](../../../.agents/skills/security-audit/SKILL.md).

Those combined controls have not been established on this Windows audit route.
Cause: a managed Git worktree isolates edits; it does not provide those OS controls.
Correction applied: restrict this pass to static source inspection and prohibit target builds,
tests, browsers, PoCs, dependency installs and external probes.
Dynamic hypotheses must remain `needs_validation` with an exact check.
Owner: primary. Completion check: verify every required sandbox control before executing such a check.
No sandbox, TLS or access control was weakened.

Next: collect the free worker's bounded result, then obtain independent Gemini verification.
Only findings tied to the reviewed bytes may influence acceptance.
Recheck affected source after frontend/hardening integration before applying this review to a release.
This setup does not replace the complete SAVIA store-day trial, API/SQL acceptance or restore evidence.

Lesson: a worktree protects concurrent source edits; a sandbox protects the host during adversarial execution.
Treat those as separate checks.
