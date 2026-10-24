# Self-contained recovered demo build

`static/` contains the **24 existing, user-owned published snapshot files** other
than the two JavaScript source files. They were copied byte-for-byte from `dist/`
at recovered commit `e6299ee`: nine HTML templates, catalog, stylesheet, demo
notice, and existing image assets. No additional products or invented media were
introduced. There are no orders, SQLite databases, credentials, or npm dependencies.

`prepare.py` assembles these files plus `src/app.js` and `src/demo-api.js` into the
26-file `dist/` tree, using only Python 3's standard library. There is no install,
network access, BeautifulSoup dependency, sibling directory, or ignored recovery
input. Output bytes do not depend on timestamps or absolute checkout paths.

```sh
python3 prepare.py
bash tests/check.sh --install  # first QA run only
bash tests/check.sh
# Alternatively build without touching the published snapshot:
python3 prepare.py --output /tmp/martha-demo-build
```

Edit markup, CSS, catalog data and media in `build-inputs/static/`; edit behavior
in `src/`, then regenerate and check `dist/`. The current catalog remains limited
to the two recovered products. Shared markup is intentionally captured in each
page, so common-header changes must be applied consistently to all nine templates.
The builder refuses unexpected files in the destination; use an empty destination
when comparing builds rather than deleting unknown content automatically.

## Recovery boundary and verification

This is **deterministic assembly of the recovered snapshot**, not a restoration of
the historical editorial generator. The former `prepare.py` transformed an external
`martha-editorial` tree and ignored recovery files. Those original transformations
remain in Git history, but are no longer required to continue this two-product demo.

The recovery build was verified in an isolated clean Git worktree with `dist/`
absent, no adjacent editorial/recovered directory, and no Python third-party
packages required. Generated output matched all **26 baseline files byte-for-byte**
(SHA-256 and path-set comparison); a repeated build was also identical. All 23
backend tests, 11 DOM simulations, nine-page structure checks and seven JavaScript
syntax checks passed afterward. Byte equivalence preserves the existing artifact,
but **does not establish real-browser visual equivalence**: no screenshot, rendering,
responsive, or real-browser interaction test was performed.
