APTO CON REPAROS. The gate correction and revised packet meet the source preflight contract. This is advisory approval of preparation, not permission to create the PR or acceptance of runtime, merge, or production.

Task: `savia-merge-preflight-edd2e09-astra-20261116-01`, VALIDATE, 2026-11-16.
HEAD verified: `edd2e097f6b4f22c9dbbffa897e9ed7f7a063055`.
Reviewed delta: `670d4a8e6fab650ef1ee2b0fba64d7e810b7dbe3..HEAD`.
Host: SUAZO-PC. T3 Code / Codex exposes `gpt-6-astra/xhigh`, matching requested `reasoningEffort=xhigh`.
Independent provider telemetry, token/cache/reasoning usage and USD are unavailable. Review began at 21:58:24 UTC; no retries.
Managed worktree: `C:/Users/Jason/.t3/worktrees/github/t3-9af55c6a-eec87f7c56c44215`; branch `t3/savia-merge-preflight-review`.
Initial tree/index clean; ownership rechecked before writing. Only this report is delivered. No access gap prevented adjudication.

**Material findings**

No new P0/P1/P2 source defect or concrete gate bypass demonstrated. Earlier omissions are corrected in the packet. Remaining conditions below are pending evidence or authority, not new source failures.

**Seven frozen checks**

1. **PASS — bootstrap and trust.** [bug-proof.yml:17](/C:/Users/Jason/.t3/worktrees/github/t3-9af55c6a-eec87f7c56c44215/.github/workflows/bug-proof.yml:17) checks out the base. Lines 33–41 preserve the exact `bug` / case-insensitive local `Fixes #N` / `Closes #N` predicate from `tools/bugproof/github.py:59–65`. Ordinary changes need no scripts. Required proof fails before producing an output when either trusted script is absent. Proof has read permissions; the separate comment job checks out base and gets write permission only there (lines 73–93). No PR-head execution with comment authority was introduced.

2. **PASS — actual gate exercised.** [test_control.py:20](/C:/Users/Jason/.t3/worktrees/github/t3-9af55c6a-eec87f7c56c44215/tests/bugproof/test_control.py:20) extracts the workflow's actual Python; it does not copy the predicate. Three methods/eight cases passed. Four independent cases below verified either missing script, inert present scripts, and script-like PR text. This tests Python behavior, not GitHub's YAML/shell runner.

3. **PASS — packet coverage, conditional on refresh.** [RUNTIME.md:13](/C:/Users/Jason/.t3/worktrees/github/t3-9af55c6a-eec87f7c56c44215/docs/merge-readiness-20261116/RUNTIME.md:13) matches four SQL jobs: `savia.yml:63–70`, `golden-path.yml:30–37`, `savia-v2.yml:33–40`, `savia-azure.yml:29–36`. All seven recorded protected contexts map to source, including both portable matrix jobs. Twelve envelopes total 225 minutes; conditional bug-comment raises this to 230. Digest narration/publication predicates match `progress-digest.yml:54–67,152–168`. Zero secrets/variables and public User ownership are primary-recorded metadata, not my live verification. Recheck before creation. Path-filter scheduling, artifacts, no retries, cash-only automatic journey and conditional restart limits are explicit. Backend's separate SQL job requires main push/manual (`backend.yml:39–42`); Azure deploy requires dispatch (`savia-azure.yml:114–124`); Cloudflare excludes PRs (`ci.yml:81–86`). Local recorded-main tree inspection also found no bug-intake workflow.

4. **ACCEPTABLE PROPOSAL ONLY — hosted boundary.** [RUNTIME.md:45](/C:/Users/Jason/.t3/worktrees/github/t3-9af55c6a-eec87f7c56c44215/docs/merge-readiness-20261116/RUNTIME.md:45) discloses synthetic failure-log publication. Line 51 accurately limits acceptance to fresh standard hosted jobs. `savia-v2.yml:83–85` and `savia-azure.yml:107–112` suppress teardown errors; green jobs therefore cannot prove individual absence. That remains **NOT PROVEN**. Accept this disclosed boundary for Jason's proposed fictional-data decision. No local/self-hosted/production waiver follows. Hosted service guarantees and billing were not independently refreshed. Primary must verify runner selection; Jason must grant the exact attempt.

5. **PASS — scope preserved.** RUNTIME line 9, PLAN lines 78–79 and PR-BODY line 9 preserve PR5 OPEN/deferred and PR6 optional/separate. PR2 containment remains historical verified evidence from `astra-merge-route.md:14`; ancestry was not rerun. No feature closure, protection change or fabricated pipeline success appears in this delta.

6. **PASS — workaround specified; execution PENDING.** [PLAN.md:76](/C:/Users/Jason/.t3/worktrees/github/t3-9af55c6a-eec87f7c56c44215/docs/merge-readiness-20261116/PLAN.md:76) and line 85 retain the recorded three `WinError 1314` fixture errors. `tony-snapshot.yml:38–57` runs the full `python tests/check.py --install` on Ubuntu. No assertion skip or Windows security correction was introduced. This reviewer made no correction because runtime is outside scope. Primary owns closure: read the existing Linux run at the exact published SHA and confirm the failed fixture path passed. Current remote CI remains pending/unverified here.

7. **PASS — prepared body.** [PR-BODY.md:1](/C:/Users/Jason/.t3/worktrees/github/t3-9af55c6a-eec87f7c56c44215/docs/merge-readiness-20261116/PR-BODY.md:1) contains `Por qué / Alternativas / Evidencia / Qué falta`, matching `tools/delivery_status.py:27,156`. It distinguishes historical counts, final head/base/merge proof, cleanup limits, and excluded merge/deployment/production. Primary must reconcile any base/head change before acceptance.

**Fresh commands and results**

`python -B -m unittest discover -s tests/bugproof -p test_control.py -k workflow -v` → exit 0; 3 tests, 0.834s.

Independent probe command: the following PowerShell here-string piped to `python -B -` → exit 0. Four child exits: `[1,1,0,0]`; required outputs: absent, absent, true, false. The invocation also printed the source bindings below.

```powershell
@'
from pathlib import Path
import hashlib, json, os, subprocess, sys, tempfile, textwrap
p = Path('.github/workflows/bug-proof.yml')
s = p.read_text(encoding='utf-8').split("python - <<'PY'\n", 1)[1]
code = textwrap.dedent(s.split('          PY', 1)[0])
cases = [('github.py', 'Fixes #12', 1), ('prove.py', 'Closes #12', 1), ('both', 'Fixes #12', 0), ('none', "ordinary $(exit 1) ${{ secrets.GITHUB_TOKEN }} `__import__('sys').exit(99)`", 0)]
for present, body, expected in cases:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        names = ['github.py', 'prove.py'] if present == 'both' else ([] if present == 'none' else [present])
        for name in names:
            target = root / 'tools/bugproof' / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('raise RuntimeError("BASE_SCRIPT_MUST_NOT_EXECUTE_IN_GATE")\n')
        event = root / 'event.json'
        event.write_text(json.dumps({'pull_request': {'labels': [], 'body': body}}))
        output = root / 'output'
        r = subprocess.run([sys.executable, '-B', '-c', code], cwd=root, env={**os.environ, 'GITHUB_EVENT_PATH': str(event), 'GITHUB_OUTPUT': str(output)}, capture_output=True, text=True)
        actual = output.read_text() if output.exists() else ''
        assert r.returncode == expected, (present, r.returncode, r.stderr)
        assert actual == ('' if expected else 'required=' + str(present == 'both').lower() + '\n'), (present, actual)
        if expected:
            assert 'Base branch lacks trusted bug-proof tooling' in r.stdout
        print(f'{present}: child_exit={r.returncode}, output={actual!r}')
for name in ('.github/workflows/bug-proof.yml', 'tests/bugproof/test_control.py', 'docs/merge-readiness-20261116/RUNTIME.md'):
    blob = subprocess.check_output(['git', 'show', 'HEAD:' + name])
    oid = subprocess.check_output(['git', 'rev-parse', 'HEAD:' + name], text=True).strip()
    print(name, 'git_blob=' + oid, 'blob_sha256=' + hashlib.sha256(blob).hexdigest(), 'raw_sha256=' + hashlib.sha256(Path(name).read_bytes()).hexdigest())
print('PASS: 4 discriminating cases; 3 source bindings')
'@ | python -B -
```

`git diff --check 670d4a8e6fab650ef1ee2b0fba64d7e810b7dbe3..HEAD` → exit 0.
`git ls-tree -r --name-only 3b0049163ece2d9431cee01f1bea624a66d9d8d4 -- tools/bugproof .github/workflows/bug-intake.yml` → exit 0, empty.
`git rev-parse HEAD` → exit 0, expected SHA.

**Source bindings**

SHA256 below hashes immutable Git blob bytes, not checkout bytes.

| File | Git blob | SHA256 |
| --- | --- | --- |
| .github/workflows/bug-proof.yml | 3c3321bf0e1978e8ed17ab29cdef3d0f42a0eb15 | 88a3d268d57c09bdeb036557ccbb9a155ec9699a7d259af3adf4fff08f4b8073 |
| tests/bugproof/test_control.py | c432b3ff3a272e81d31967006b21a7b1096dd208 | d956519d6c40ced67d37b6fdffa4427aebeec3a9e6f279f40371f22fd20dbd01 |
| docs/merge-readiness-20261116/RUNTIME.md | 2c33324450b82e672ede97413f90fd9601cc5d7d | cbe9159e1a55be831b850eb713feca14cc6b0ee5e87ee7109d387a7ca525a46e |

**Recorded, not rerun:** semantic red exit 1/child 2; complete bugproof 14/14; YAML 3/3; progress 23/23; export 15 hashes; repository check exit 1/131.813s. Source: PLAN/OUTCOMES.

Lesson retained: test first-main gates with absent base tooling; preserve required-proof rejection. Both conditions passed here.

**NOT RUN:** broad suite, SQL, Docker, API/browser, network/GitHub, installs, security/services/accounts, commits/push/PR/merge/deploy, external messages or delegation.

One next action: primary imports this report, verifies final exact-SHA Linux CI and metadata, then presents RUNTIME for Jason's concrete grant. Do not create the PR before that grant.

APTO CON REPAROS — `docs/merge-readiness-20261116/astra-final-preflight.md` — source `edd2e097f6b4f22c9dbbffa897e9ed7f7a063055`.
