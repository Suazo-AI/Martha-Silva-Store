# REVISE — R1–R4 exact-source recheck

Task: `savia-runner-r1r4-recheck-20261107`. Mode: VALIDATE. Status: returned.
R1 dispatch boundaries, R2 and R4 pass bounded offline checks.
R3 remains incomplete at final receipt persistence: one P2 finding below.
This return is not primary acceptance, SQL proof, cash acceptance or production READY.

## Identity, scope and binding

Host: `SUAZO-PC`. Harness/provider: T3 Code / Codex.
Requested and exposed model/effort: `gpt-6-astra/xhigh`, confirmed by runtime context and fresh agent-awareness.
Provider-internal reasoning, token usage and USD cost: unknown.
No nested agents or provider substitution.

Managed worktree: `C:/Users/Jason/.t3/worktrees/github/t3-a60b5225`.
Branch: `t3/recheck-runner-safety`.
Initial `git rev-parse HEAD`, exit 0: **457a1576cd782874d1b3159c08e958bac96482eb**.
Initial `git status --short`, exit 0: clean.
The SHA gate preceded dependent work.
Repo instructions, AGENT-START, DATABASE, direct source, orchestration, PROTOCOL, OUTPUT, task-completion, coordination and evidence-first rules were accessible.
No denied instruction access.
Agent-awareness ran at startup and before mutations; it identified this assigned task here.

All three revision-2 LF bindings match.
RAW differences are checkout CRLF; normalization replaces CRLF only, without stripping BOM.
Names below are relative to `tools/`.

| File | RAW SHA256 | LF SHA256 |
|---|---|---|
| run_local_validation.py | 0a6fe4fb577a6a3108baf8b25f0057e06016473aea0b5c866e9423251c3acb48 | e57332b349a40d4bccf7e5f6f81eb4b5d8dd882a45feefe7a59c730e2a8d4995 |
| local-validation/safety.py | 29d93e666f360bf5b9d9d31f9c28faea7ee3ce8bdcebdc5e23fda03b513a9186 | dd0c8b4d3277b690e7d92db2128fa8221d33e102455e024d6047df38f24a84ed |
| local-validation/test_run_local_validation.py | fc2f4397f0114f0d761cd224f85f3837a99e044927311c0a8275d432383e9445 | 873de6f334c7fbf74922d9ad55b078bba955ac49709e5fc0455435ef7c289cff |

`git diff --name-only 754b67eedd70d4234db950f53262d652b83d616c HEAD -- tools/local-validation/evidence_gate.py tools/local-validation/run-stage.sh tools/local-validation/Dockerfile`: exit 0, empty.
Their LF hashes still match the prior review: respectively
`a6f366d76e07578793ed0f2bdb8293a65f8b7aa689e081de92b57df5822f4eb0`,
`a68e165dcf7f613ae718ef67294a20d45d74327e74d2945416e9d1090d2fed3c`,
`86c65a020b06cf3706debff26b181fc8af3e3aacab43c682c399ae1a8225a0e4`.

## Finding and adjudication

**R3.1 — P2 / Medium: durable PASS can contradict failed receipt finalization.**
Source: `tools/run_local_validation.py:166-172,293-301`.
After `result.json` bytes are written, closing the stream can raise an interruption, or the post-write deadline can fail.
The handler changes only the in-memory result.
The saved receipt still says PASS.

Fresh counterexamples injected faults at the final stream-close boundary:

| Fault | Persisted status | Actual outcome | Owned resources remaining |
|---|---|---|---|
| KeyboardInterrupt | PASS | Same interrupt object reraised | 0 |
| SystemExit | PASS | Same interrupt object reraised | 0 |
| Deadline exhausted | PASS | FAILED returned | 0 |

This is demonstrated offline, not a hypothesis about Docker.
All simulated stages and cleanup completed in these cases; this does not reproduce the earlier unfinished-stage PASS defect.
It does violate fail-closed final evidence persistence.
Expected: a failed receipt commit must leave non-PASS or no authoritative success receipt.
Primary should correct receipt commit/failure semantics and add these boundary controls.
Correction/recheck here: NOT RUN; source edits are outside the sole authorized report path, and all three check invocations are consumed.
Owner: primary. Closure: no durable authoritative PASS for these cases, original interrupt preserved, full focused suite passing on new frozen bytes.

| Criterion | Fresh result / source |
|---|---|
| R1 | PASS with limits. Actual log-write delays across prep/C/D block c1/D/E dispatch; cleanup still runs. R:172,230-240,313-320. Independent cleanup slices survive exhaustion; retention exhaustion does not skip cleanup. S:170-202. Synchronous filesystem calls are not preempted. |
| R2 | PASS. Both resource kinds: renamed full ID remains present; abbreviated/missing/non-object rows and failed listings remain unknown. Successful full listing can establish absence. Foreign resources receive no removal. S:178-199. |
| R3 | PARTIAL. Stage, retention, failure-retention, cleanup and ambiguous-create interruptions pass for both exception types. Original interrupt identity survives secondary cleanup interruption; ordinary stage failure survives retention interruption. Final receipt defect remains. |
| R4 | PASS. Dot/doubled-slash/case aliases fail before destination creation in allowlists and members. Normal 0644 files / 0755 directories extract. S:64-114. |
| F1–F10 | Reuse unchanged bounded F1/F3/F4/F6/F8/F9 findings from prior review, supported by direct reads. F2/F5 corrections pass; F7/F10 remain partial because receipt persistence lacks coverage. No safety gate was weakened. |

## Commands and fresh evidence

Adapters were inspected first.
The suite replaces Git/privacy/Docker and intercepts subprocess execution; historical controls also use fakes.
Both independent probes install a global subprocess guard before module loading and recorded **0 subprocess calls**.
Temporary synthetic fixtures were removed; bytecode writes were disabled.

1. `$env:PYTHONDONTWRITEBYTECODE='1'; python tools/local-validation/test_run_local_validation.py`: exit **0**, **46/46**, **3.391s**.
Nine are historical OLD-defect controls, not acceptance of old behavior.
2. Probe below: exit **0**, **27/27** independent cases.
3. Probe below: exit **1**, **9 passes / 3 acceptance violations**.
No harness error or identical-failure retry. Exactly **3/3** offline Python check invocations.

The exact probe commands follow.

<details>
<summary>Invocation 2: independent boundary matrix</summary>

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'; @'
import importlib.util,json,subprocess,sys,tempfile
from pathlib import Path
from unittest.mock import patch
from types import SimpleNamespace
checks=[]
def load():
 p=Path('tools/local-validation/test_run_local_validation.py')
 s=importlib.util.spec_from_file_location('review_support',p);m=importlib.util.module_from_spec(s);sys.modules[s.name]=m;s.loader.exec_module(m);return m
with patch('subprocess.run',side_effect=AssertionError('REAL SUBPROCESS FORBIDDEN')) as guard:
 M=load();R,S=M.R,M.S
 for stage,budget,next_stage in [('build',R.PREP_BUDGET,'c1'),('crest',R.C_BUDGET,'d'),('d',R.D_BUDGET,'e-release')]:
  with tempfile.TemporaryDirectory() as td:
   f=M.Fixture(Path(td));clock=M.Clock();t=M.Fake(f,clock);op=Path.open
   class Slow:
    def __init__(self,s):self.s=s
    def __enter__(self):self.s.__enter__();return self
    def __exit__(self,*a):return self.s.__exit__(*a)
    def write(self,b):v=self.s.write(b);clock.now+=budget+1;return v
   def opened(p,*a,**k):
    s=op(p,*a,**k);return Slow(s) if a==('xb',) and p.name=='stage-'+stage+'.log' else s
   with patch.object(Path,'open',opened):result=R.execute(f.config,t,clock=clock,git_read=f.git,privacy=f.privacy)
   assert result['status']=='FAILED' and next_stage not in t.stages and not t.resources,result
   assert all(x['state']=='absent' for x in result['cleanup'])
   checks.append('budget-'+stage)
 for kind in ('container','network'):
  for mode,expected in [('renamed','present'),('short','unknown'),('missing','unknown'),('nondict','unknown'),('failed-list','unknown'),('absent','absent'),('foreign','unknown')]:
   clock=M.Clock();ident='a'*64;name='owned';ops=[]
   class Listing:
    def call(self,args,timeout,check=True,env=None):
     ops.append(args);clock.now+=.01;assert 0<timeout<=20
     rc=0;out=''
     if args[1]=='inspect':
      labels={'savia.run':'foreign' if mode=='foreign' else 'nonce','savia.scope':'scope'}
      out=json.dumps([{'Id':ident,'Name':name,'Labels':labels}])
     elif args[1]=='rm':rc=1
     elif args[1]=='ls':
      assert '--no-trunc' in args and (kind!='container' or '--all' in args)
      rows=[{'ID':ident,'Name':'renamed'}]
      if mode=='short':rows[0]['ID']=ident[:12]
      if mode=='missing':rows=[{}]
      if mode=='nondict':rows=[[]]
      if mode=='failed-list':rc=1;rows=[]
      if mode=='absent':rows=[]
      out='\n'.join(json.dumps(x) for x in rows)
     else:raise AssertionError(args)
     return SimpleNamespace(returncode=rc,stdout=out,stderr='')
   o=S.Ownership(Listing(),'nonce','scope');o.receipts=[(kind,ident,name)]
   result=o.cleanup(clock);assert result[0]['state']==expected,result
   if mode=='foreign':assert not any(a[1]=='rm' for a in ops)
   checks.append('listing-'+kind+'-'+mode)
 for typ in (KeyboardInterrupt,SystemExit):
  for where in ('stage','retention','cleanup','failure-retention','create'):
   with tempfile.TemporaryDirectory() as td:
    f=M.Fixture(Path(td));clock=M.Clock();t=M.Fake(f,clock);call=t.call;write=R.PrivateStore.write
    original=typ('original-marker');secondary=SystemExit('secondary-marker');raised=False;removals=[]
    if where=='failure-retention':t.failure='c1'
    def wrapped(args,**kw):
     global raised
     if where=='stage' and args[-1:]==['c1']:raised=True;raise original
     if where=='retention' and args[0]=='cp' and args[1].endswith('/evidence/.'):raised=True;raise original
     if args[1:2]==['rm']:
      removals.append(args[-1])
      if len(removals)==1:
       if where=='cleanup':raised=True;raise original
       if where in ('stage','retention','failure-retention'):raise secondary
     if where=='create' and args[:2]==['network','create']:
      call(args,**kw);raised=True;raise original
     return call(args,**kw)
    def wrapped_write(store,relative,content):
     if where=='failure-retention' and relative=='logs/failure-output.log':raise original
     return write(store,relative,content)
    t.call=wrapped;caught=None
    try:
     with patch.object(R.PrivateStore,'write',wrapped_write):R.execute(f.config,t,clock=clock,git_read=f.git,privacy=f.privacy)
    except BaseException as e:caught=e
    assert caught is original,(where,repr(caught))
    receipt=json.loads((f.private/'result.json').read_text())
    assert receipt['status']=='FAILED',receipt
    if where=='create':
     assert not removals and receipt['cleanup'][0]['state']=='unknown'
    else:assert len(removals)==3,(where,removals)
    if where=='failure-retention':assert receipt['failure']=={'stage':'C','type':'SafetyError'},receipt
    checks.append('interrupt-'+typ.__name__+'-'+where)
 print(json.dumps({'probe':'independent-boundaries','passed':len(checks),'cases':checks,'real_subprocess_calls':guard.call_count}))
 assert guard.call_count==0

'@ | python -
$reviewExit=$LASTEXITCODE; Write-Output "OFFLINE_CHECK_2_EXIT=$reviewExit"; exit $reviewExit
```

</details>

<details>
<summary>Invocation 3: archive and finalization counterexamples</summary>

```powershell
$env:PYTHONDONTWRITEBYTECODE='1'; @'
import importlib.util,json,subprocess,sys,tempfile
from pathlib import Path
from unittest.mock import patch
from types import SimpleNamespace
passed=[];violations=[]
with patch('subprocess.run',side_effect=AssertionError('REAL SUBPROCESS FORBIDDEN')) as guard:
 p=Path('tools/local-validation/test_run_local_validation.py')
 s=importlib.util.spec_from_file_location('finalization_probe',p);M=importlib.util.module_from_spec(s);sys.modules[s.name]=M;s.loader.exec_module(M)
 R,S=M.R,M.S
 for mode in ('normal','dot-allow','double-allow','case-allow','dot-member','double-member','case-member'):
  with tempfile.TemporaryDirectory() as td:
   files={'backend/x':b'content'}
   if mode!='normal':
    alias={'dot':'backend/./x','double':'backend//x','case':'backend/X'}[mode.split('-')[0]];files[alias]=b'content'
   allowed=files if mode.endswith('allow') or mode=='normal' else {'backend/x':b'content'}
   hashes={n:M.hashlib.sha256(b).hexdigest() for n,b in allowed.items()};target=Path(td)/'export'
   error=None
   try:S.extract(M.archive(files),target,hashes)
   except S.SafetyError as e:error=e
   if mode=='normal':assert error is None and (target/'backend/x').read_bytes()==b'content'
   else:assert error is not None and not target.exists(),mode
   passed.append(mode)
 clock=M.Clock();calls=[]
 class ExhaustedCleanup:
  def call(self,args,timeout,**kw):
   calls.append((args,timeout));clock.now+=21
   return SimpleNamespace(returncode=0,stdout='[]',stderr='')
 o=S.Ownership(ExhaustedCleanup(),'nonce','scope')
 o.receipts=[('network','a'*64,'net'),('container','b'*64,'sql'),('container','c'*64,'runner')]
 result=o.cleanup(clock)
 assert len(calls)==3 and all(t==20 for a,t in calls) and all(r['state']=='unknown' for r in result)
 passed.append('cleanup-independent-exhaustion')
 with tempfile.TemporaryDirectory() as td:
  f=M.Fixture(Path(td));clock=M.Clock();t=M.Fake(f,clock);call=t.call
  def delayed(args,**kw):
   if args[0]=='cp' and args[1].endswith('/evidence/.'):clock.now+=61
   return call(args,**kw)
  t.call=delayed;r=R.execute(f.config,t,clock=clock,git_read=f.git,privacy=f.privacy)
  assert r['status']=='FAILED' and not t.resources and all(x['state']=='absent' for x in r['cleanup'])
  passed.append('retention-exhaustion-still-cleans')
 for mode in ('KeyboardInterrupt','SystemExit','deadline'):
  with tempfile.TemporaryDirectory() as td:
   f=M.Fixture(Path(td));clock=M.Clock();t=M.Fake(f,clock);op=Path.open
   signal=KeyboardInterrupt('receipt-close') if mode=='KeyboardInterrupt' else SystemExit('receipt-close')
   class Close:
    def __init__(self,s):self.s=s
    def __enter__(self):self.s.__enter__();return self
    def write(self,b):return self.s.write(b)
    def __exit__(self,*a):
     result=self.s.__exit__(*a)
     if mode=='deadline':clock.now+=61;return result
     raise signal
   def opened(path,*a,**kw):
    stream=op(path,*a,**kw);return Close(stream) if a==('xb',) and path.name=='result.json' else stream
   raised=None;returned=None
   try:
    with patch.object(Path,'open',opened):returned=R.execute(f.config,t,clock=clock,git_read=f.git,privacy=f.privacy)
   except BaseException as e:raised=e
   receipt=json.loads((f.private/'result.json').read_text())
   assert not t.resources
   if mode!='deadline':assert raised is signal
   else:assert returned['status']=='FAILED'
   observation={'case':'final-receipt-'+mode,'persisted':receipt['status'],'raised':type(raised).__name__ if raised else None,'returned':returned['status'] if returned else None,'owned_remaining':len(t.resources)}
   if receipt['status']=='PASS':violations.append(observation)
   else:passed.append(observation['case'])
 assert guard.call_count==0
 print(json.dumps({'probe':'archive-finalization','passed':len(passed),'passed_cases':passed,'violations':violations,'real_subprocess_calls':guard.call_count}))
sys.exit(1 if violations else 0)

'@ | python -
$reviewExit=$LASTEXITCODE; Write-Output "OFFLINE_CHECK_3_EXIT=$reviewExit"; exit $reviewExit
```

</details>

## Limits and handoff

Only changed artifact: `docs/completion-20261107/local-validation/runner-corrections/revision-2/astra-recheck.md`.
Report hygiene: initial `git diff --no-index --check -- /dev/null <report>` exited 1 for an extra EOF blank line; removed it before final readback.
Post-correction no-index checks, including `--no-exit-code`, returned 1 for the new-file comparison, without whitespace diagnostics. Direct PowerShell whitespace/EOF validation and final hashes accompany the return; these are artifact bookkeeping, not additional Python probes.
No implementation, generated evidence, index, commit, canonical checkout or external resource changed.
Exact-SHA CI success was supplied in the packet; it was not rechecked and adds no SQL/cash proof.

NOT RUN: actual runner CLI, Docker/SQL/browser, shell campaign, build/restore, network/downloads/installations, CI dispatch, publication or deployment.
Dependency closure/immutable-image qualification remains absent; the deliberate Dockerfile stop is preserved.
Actual protected Windows destination, current cash-inclusive partition inventory and separately authorized runtime remain primary/Jason prerequisites.
No correction to these prerequisites was attempted because this packet excludes those operations.
Closure requires their own reviewed evidence and authorized checks.

Permitted stop: bounded review returned REVISE; implementation authority absent and check budget consumed.
Primary owns the minimal receipt correction, fresh source freeze, regression/re-review and serial integration.
Lesson: a post-write failure must invalidate persisted success, not only change a Python dictionary.
