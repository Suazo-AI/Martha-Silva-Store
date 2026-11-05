# Publication and workflow correction

2026-11-05. SUAZO-PC. Primary: T3 Code / Codex / gpt-6.1-sol / xhigh.

Initial publication: `300bf55db29a3559e6ffc1b3c1b15ebcb14f2151`.
Normal hooks returned SYNCED; `git ls-remote origin refs/heads/Tony` matched.
Unrelated untracked files remained excluded. No merge or deployment occurred.

## Reproduced CI configuration failure

Both workflow files failed parsing before executing product tests:

- [Tony source snapshot](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42120653472).
- [Recovered demo CI](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42120655514).

Local PyYAML reproduced `mapping values are not allowed here` at `ci.yml:41:54`
and `tony-snapshot.yml:55:54`. The primary introduced an unquoted YAML command
containing `: ` inside `--only-binary=:all: --disable-pip-version-check`.
This is a workflow defect, not a demonstrated product regression.

Correction: represent both commands with YAML block scalars (`run: >-`).
Dependency versions and command arguments are unchanged. Product bytes are unchanged.
The corrected workflows parse successfully and every `run` step has a string value.
Deployment contract checks remain 13 PASS, 1 SKIP, exit 0.

Next: publish this correction through the same hooks, verify its remote SHA and inspect
that SHA's workflows. The failed runs above remain historical failures.
No Linux success is inferred from local focused checks or parsing alone.

Lesson: validate workflow syntax before publication, including commands containing colons.
Existing deployment contract tests did not detect this parser error; their success was insufficient.
