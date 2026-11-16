# Gallery test controls

In-memory equivalence and negative controls for `tests/desktop-gallery.cjs`.
The script never writes product bytes or the candidate test. Each variant rewrites
only the data returned by `fs.readFileSync` inside the test process.

## Run

```powershell
$env:MARTHA_JSDOM_PATH='C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules/jsdom'
node docs/gallery-contracts-20261107/controls/check-variant.cjs <variant>
```

Variants: `baseline`, `tabindex-zero`, `valid-measured-sizes`, `bad-sizes`, `no-activation`.

## Intended and observed

| Variant | Transform | Intended | Observed |
|---|---|---|---|
| `baseline` | none | 14/14, exit 0 | 14/14, exit 0 (`logs/baseline.log`) |
| `tabindex-zero` | add `tabindex="0"` to the first photo button | 14/14, exit 0 | 14/14, exit 0 (earlier invocation; no persisted log) |
| `valid-measured-sizes` | replace every `sizes` with `430px` | 14/14, exit 0 | 14/14, exit 0 (earlier invocation; no persisted log) |
| `bad-sizes` | replace every `sizes` with `1px` | exit 1 | 11/14, exit 1; fails DG04, DG05, DG09 (`logs/bad-sizes.log`) |
| `no-activation` | rewrite `if(!b)return;go(` to `if(b||!b)return;go(` | exit 1 | 4/14, exit 1; 10 cases fail (`logs/no-activation.log`) |

`bad-sizes` proves the hint contract is independent of the captured value.
`no-activation` proves the suite detects a real loss of gallery activation.
`tabindex-zero` and `valid-measured-sizes` prove harmless equivalent
implementations are not rejected.

Machine-readable results: [`observed-runs.json`](observed-runs.json).
