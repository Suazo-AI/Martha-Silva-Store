# WP-A evidence — 2026-11-11

Task: `wp-a-bug-pipeline-20261111`.
Host: SUAZO-PC, Windows, T3 Code, Codex `gpt-6.1-sol`, high reasoning.
Base verified by `git rev-parse HEAD`: `391041e471895d1d4862aa81feee0ae96dafcc65`, exit 0.
Branch: `t3/bug-proof-pipeline`.
No nested delegation, push, PR, secret change, SQL or agent execution.

| Check | Evidence | Limit |
| --- | --- | --- |
| A1 | Workflow/job marker dedupe and reopen verified with offline mocked API unit test | Real workflow_run and issue mutation NOT RUN |
| A2 | Label/reference gate and no-changed-test refusal verified locally | Branch protection must require Bug proof separately |
| A3 | Real temp Git repos prove FAIL/PASS accepted, PASS/PASS rejected, head failure rejected, infrastructure errors rejected; real Python and Node execution | .NET command/filter/TRX adapter tested with mock process; real dotnet NOT RUN |
| A4 | CLI emits Markdown/JSON/self-contained HTML; separate job configures one deduplicated comment | GitHub summary/artifact/comment runtime NOT RUN; fork comments unsupported with read-only pull_request tokens |
| A5 | Pinned Claude action; Opus, medium effort; credential guard skips checkout/action and emits summary | Configured only; missing-secret Actions runtime and Claude NOT RUN |
| A6 | Temp repository: seeded arithmetic bug, red-test commit, fix commit => CLI 0/PASS; git revert of fix => CLI 1/FAIL | Local demonstration only; no real PR opened as instructed |

Commands and observed exits:

- `python -m unittest discover -s tests/bugproof -v`: exit 0, 11 tests.
- `python -m unittest discover -s tests/bugproof -p test_prove.py -k test_a6_demo -v`: exit 0; internal CLI exits 0 then 1.
- `python -c "import yaml,pathlib; paths=list(pathlib.Path('.github/workflows').glob('bug-*.yml')); [(yaml.safe_load(p.read_text()),print(str(p)+' YAML PASS')) for p in paths]; assert len(paths)==3"`: exit 0, three workflows parsed.
- `git diff --check`: exit 0.
- `python -m unittest discover -s tests/bugproof -p test_control.py -v`: exit 0, 3 tests after isolating .NET result directories.
- `python tests/check.py`: exit 1, `FAIL: Missing jsdom: run python tests/check.py --install first.`
- `git diff --cached --check`: exit 0.
- `git commit -m "Add differential bug proof pipeline and offline regression demo"`: exit 1, `Progress sync BLOCKED: This hook only publishes Tony; select the approved branch. Local work is preserved.`

`actionlint` was NOT RUN because `Get-Command actionlint -ErrorAction SilentlyContinue` found no local executable.
YAML parsing does not establish GitHub Actions expression validity or runtime acceptance.

## Blockers and handoff

The local commit is blocked by repository hooks, not by implementation tests.
`core.hooksPath=.githooks`; pre-commit calls `tools/progress.py pre-commit`, whose first guard rejects every branch except Tony.
The post-commit hook calls automatic publication, while this packet explicitly prohibits push.
No hook was disabled or bypassed, and no publication setting was changed.
Commit SHA: none; HEAD remains the verified base and all 11 owned files are staged for handoff.
The primary owns serial integration into Tony and its normal receipt/publication path.
Completion check: primary obtains an integration SHA, checks exact owned paths and runs independent acceptance.

The repository-wide runner is blocked before tests because jsdom is absent in this worktree.
No dependency installation was attempted because it writes outside the packet's owned paths and the required runner was already attempted.
The primary can run `python tests/check.py --install` in its integration checkout, then record the exit and distinguish baseline failures.

The GitHub runtime checks need the workflows integrated onto the default branch, then a controlled failing CI run and repair PR.
The primary owns those external mutations; this worker was explicitly prohibited from pushing or opening PRs.
The HTML artifact and comment use file-level test results, with individual runner cases visible in log excerpts.
The intake script loads the trusted workflow SHA from this public repository without contents permission; it never executes failed-run source or artifacts.
GitHub prevents GITHUB_TOKEN-created issues from triggering another workflow; dispatch Bug agent manually for those issues.

Lesson: distinguish assertion failures from missing imports, empty suites and build errors before accepting red-test evidence.
The added infrastructure-failure fixture proves that distinction locally.

## Changed files

- `.github/workflows/bug-intake.yml`
- `.github/workflows/bug-proof.yml`
- `.github/workflows/bug-agent.yml`
- `.github/ISSUE_TEMPLATE/bug.yml`
- `.github/pull_request_template.md` (existing required sections preserved; bug evidence appended)
- `tools/bugproof/prove.py`
- `tools/bugproof/github.py`
- `tests/bugproof/test_prove.py`
- `tests/bugproof/test_control.py`
- `docs/bug-pipeline/README.md`
- `docs/bug-pipeline/EVIDENCE.md`
