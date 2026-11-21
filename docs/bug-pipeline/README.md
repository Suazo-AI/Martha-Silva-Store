# Bug pipeline

A failed Tony CI job opens or updates one `bug` issue keyed by workflow ID and job name.
The issue links to the latest failing job and reopens when the failure returns.
A human can also use the Bug issue form.
A PR labeled `bug`, or containing `Fixes #N` or `Closes #N`, must change a supported test.
References conservatively require proof even when the referenced issue has no bug label.
The agent commits the failing test first, then fixes the behavior in a second commit.
Run `python tools/bugproof/prove.py --base <sha> --head <sha>` from the repository root.
The tool snapshots both commits into temporary directories and overlays each changed test onto the base.
Python unittest files, Node `.test.mjs` files, and backend `*Tests.cs` classes are supported.
Each changed non-SQL test file must fail with an actual test failure on base and pass on head.
Import, build, timeout and empty-suite errors cannot prove a bug.
SQL tests are reported `SKIPPED` and never count as proof, even when SQL credentials exist.
A SQL-only change fails the proof requirement until a portable regression is supplied.
Reports include exact revisions, file-level results and bounded log excerpts.
The job summary and one marker-deduplicated PR comment show the before/after table.
The `bugproof-report` artifact contains a self-contained HTML report, Markdown and JSON.
Fork PRs receive the summary and artifact; their read-only token cannot post a comment.
Test execution has read-only repository permissions and receives no Claude credential.
Comment publication runs separately and never executes PR code.
Add the single repository Actions secret `CLAUDE_CODE_OAUTH_TOKEN` to enable Claude Opus with medium effort.
Without this secret, the agent job succeeds with an explicit skipped summary and no provider call.
The agent can open a repair PR but cannot merge or deploy.
Issues created by `GITHUB_TOKEN` do not trigger another workflow automatically under GitHub event rules.
For intake-created issues, run Bug agent through `workflow_dispatch` with the issue number.
These workflows must be present on the repository default branch for workflow_run and issue events.
The pipeline does not establish runtime, SQL, production or independent acceptance.

## Local evidence

Pending local verification is recorded in `EVIDENCE.md` before handoff.
