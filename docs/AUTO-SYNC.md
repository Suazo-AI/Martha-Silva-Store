# Validated local progress sync (opt-in)

**Delivered but not activated.** No hook is installed by checking out these files.
Authentication and a successful real push must be established before calling sync
active. This implementation has only offline mocked-network regression coverage;
it does not provision credentials, log in, retry automatically, or bypass branch
protection. Git hooks run on this computer, not in GitHub or API-created commits.

## Prerequisites and activation

Use a trusted POSIX shell/Git installation, Python 3, Node.js, GitHub CLI (`gh`),
and the QA dependencies documented by `tests/check.py`. Authenticate GitHub CLI
and Git transport manually using the user's approved credential method. They
are separate requirements: `gh` access alone does not ensure `git push` works.
The authenticated account must be able to read this repo's visibility and push
`main`. `Suazo-AI/Martha-Silva-Store` must remain **private**.

From the repository root on `main`:

```sh
# Inspect before replacing any existing hooks configuration; preserve it if set.
git config --show-origin --get core.hooksPath
# After authentication, initialize/update the tracking reference manually.
git fetch origin main
python3 tests/test_sync_progress.py
python3 tools/sync_progress.py
# Only after the validated real push succeeds, opt in for this repository:
git config --local core.hooksPath .githooks
# Confirm the effective value and its origin:
git config --show-origin --get core.hooksPath
```

Never set global hooks configuration. This setting applies to this repository
(and may be shared by its worktrees); only `main` can publish. Preserve the hook's
executable bit on checkout. Environments without executable shell hooks should
use the explicit Python command instead. No service or background watcher runs.

## Meaningful progress

After an ordinary explicit commit, `post-commit` validates and pushes that commit.
It **does not commit every keystroke** or decide which files constitute progress.
For one command that validates, commits explicitly selected tracked files, and
then validates/pushes, run from the repository root:

```sh
python3 tools/sync_progress.py --commit "Describe this completed progress" src/app.js dist/app.js
```

Supply exact tracked file paths, not globs/directories. New files must be reviewed
and committed explicitly using normal Git first. Existing staged work, unrelated
modified files, and untracked files block this convenience command. It never uses
`git add .`, resets changes, rewrites history, or force-pushes. QA may regenerate
build outputs; include intended output changes explicitly and review any failure.
The convenience command suppresses hooks only on its own commit to avoid invoking
the sync twice; it does not modify configuration. Push still respects pre-push
hooks and remote branch protections.

## Gates and failure handling

Before pushing, the helper requires:

- Exact expected `origin` fetch and push destination (one each), `main`, and a
  GitHub CLI query confirming the exact repository is private.
- A clean index/worktree, including untracked files, before **and after** QA.
- No recognizable private-key/GitHub/AWS/OpenAI token patterns in committed
  tracked blobs or outgoing patches relative to local `origin/main`; sensitive
  filenames and submodules are blocked. This is a conservative heuristic, **not
  a comprehensive secret scanner or a guarantee**. Review changes yourself.
- Successful `python tests/check.py`, followed by another repository/HEAD check.

The only publication is a non-force `git push origin HEAD:main` with automatic
tag following and mirror mode disabled. Remote rejections, missing dependencies,
missing `origin/main`, authentication/visibility errors, or potential secrets
stop publication. Commands are noninteractive, bounded to five minutes each,
and never automatically retried. Captured output is not printed to avoid leaking
credentials or source content; run `python3 tests/check.py` manually for QA details.

A post-commit failure **cannot undo the already completed local commit**, and Git
may still report the commit as successful. Read the `Auto-sync blocked` message;
do not interpret a successful commit as a successful push. Once the cause is
resolved, retry explicitly with `python3 tools/sync_progress.py`. If a suspected
secret was committed, do not retry publication until it has been removed from
all outgoing history and any actual exposed credential has been rotated.
No background retries or pending queue are created.

## Disable / uninstall

If this project setting was newly installed and no prior value existed:

```sh
git config --local --unset core.hooksPath
```

If there was a prior local value, restore that exact value instead. Do not change
global configuration. The tracked hook/helper may remain inert in the repository.

## Offline tests

```sh
python3 tests/test_sync_progress.py
```

These tests mock command execution: they perform no network calls, do not commit,
and do not push. They are separate from `tests/check.py` and should be run when
changing this helper. A mocked success message is not evidence of a real push.
