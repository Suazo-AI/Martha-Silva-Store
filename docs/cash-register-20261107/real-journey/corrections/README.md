# Cash evidence corrections: returned candidate

Task: `savia-real-cash-evidence-corrections-990e23a-20261108-01`.
Frozen source: `990e23a1bac2ef06e40df12ed87a1569586c9b2c`.
Host: SUAZO-PC. Requested and exposed runtime: Codex `gpt-6.1-sol/high`.
Existing T3-managed worktree; no nested workers. Usage/cost unknown.

Corrected offline checks: **102 passed, zero failures, zero skips**.
Final regression suite against original Git source: **21 tests, 29 failing assertions, exit 1**.
Subtests explain why assertion failures exceed test methods.
The initial OLD run also failed: 53 tests, 27 failures, exit 1.

This is a worker candidate. Primary acceptance and Astra/xhigh review remain pending.
Real browser/API/SQL, SQL5, CI, production and deployment are **NOT RUN**.
SQL5 remains **D: REVIEW FIRST, DO NOT EXECUTE**.

## Corrections

- F1: validate cash discriminators before selecting a publication branch. Missing mode and smoke downgrade now reject.
- F2: reuse `browser_checkpoint` admission in `validate_cash_progress`. Require DOM, startup runtime/local source hashes, matching served hashes, and the run source/runtime map. Bind recovered sale/key to command 2. Reject unauthorized network entries and absent/null/non-integer API termination results.
- F3: preserve immutable projections of returned Sales/SaleLines rows. Derive sale state from every line. Both refunds leave the two-line original sale `partially_returned` because its second item remains unreturned.

Failure exports remain supported as `FAIL`; historical smoke exports remain supported.
An incomplete failure cannot become PASS merely by changing its outcome.
All seven REAL-CASH requirements in PREPARATION.md remain unchanged.
No product code or C# helper changed.

## Evidence and reproduction

[RESULT.json](RESULT.json) contains exact source/candidate RAW and LF hashes, command exits/counts, private log hashes, and product preservation checks.
RAW binds exact transferred bytes. LF replaces CRLF with LF only.
Source RAW refers to Git blob bytes at the frozen source, not an unavailable pre-edit working-tree snapshot.
Read-only helper/driver/product bindings include both Git RAW and current working RAW.
Product equivalence uses newline-only normalized comparison against every tracked file in the declared product roots.

Run corrected checks from the candidate worktree without installing dependencies:

```powershell
python -m unittest discover -s tests -p test_golden_path_cash_evidence.py -v
python -m unittest discover -s tests -p test_golden_path_cash.py -v
python -m unittest discover -s tests -p 'test_golden_path_*safety.py' -v
python -m unittest discover -s tests -p 'test_golden_path_stock*.py' -v
git diff --check
```

Results respectively: 21, 35, 41 and 5 passes; every exit 0.
Safety/browser includes the existing 17 safety and 24 browser cases.
The actual stock filename is `tests/test_golden_path_stock_exception.py`.

Final OLD replay loaded both original modules from Git into a temporary directory before importing the final regression suite.
It changed no checkout files. Exact Python stdin body:

```python
import importlib.util, subprocess, sys, tempfile, unittest
from pathlib import Path
sys.path.insert(0, str(Path('tests').resolve()))
import test_golden_path_safety as safety
with tempfile.TemporaryDirectory() as tmp:
    for name in ('golden_path', 'verify_evidence'):
        source = subprocess.check_output([
            'git', 'show', f'990e23a:tests/golden-path/{name}.py'])
        path = Path(tmp) / (name + '.py')
        path.write_bytes(source)
        spec = importlib.util.spec_from_file_location('old_' + name, path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        if name == 'golden_path': safety.GP = module
        else: safety.verifier = module
    suite = unittest.defaultTestLoader.loadTestsFromName('test_golden_path_cash_evidence')
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.exit(not result.wasSuccessful())
```

Raw logs stay in ignored `private-exports/cash-corrections/`.
No raw runtime logs, private data or credentials were used.
Exactly eight focused Python test/probe processes were used.

## Failed attempt and limits

The first corrected check had three positive-fixture errors because cash reload DOM lacked `shell`.
The driver already emits `shell`; the fixture now models it. No production requirement changed.
Imported `CashControls` initially duplicated 35 test methods in discovery; module import fixed the count.
An edit initially decoded UTF-8 through Windows defaults. Original non-ASCII lines were restored from Git before final verification.
All failed attempts remain recorded in RESULT.json and private logs.

Lesson applied: the scan manifest proves byte identity; shared admission plus independent oracles establish the claimed semantics.

Next owner: primary. Integrate serially, verify exact hashes and independently review with Astra/xhigh.
Runtime requires separate authorization and a reviewed cleanup plan.
