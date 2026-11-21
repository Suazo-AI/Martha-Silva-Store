# SAVIA demo

Static shell for the unchanged staff app. All business data must be invented.
The browser intercepts `/api/v1` before importing either application entry.
The banner uses the staff app's CSS tokens. No external assets or CDN are added.

Build from the repository root with Python 3.10 or later:

```sh
python savia/tools/build_demo.py
```

The default API entry is `savia/demo/api/index.mjs`. A missing entry stops the build.
Use the shell test double while the real fake API is unavailable:

```sh
python savia/tools/build_demo.py --api savia/demo/site/test-double.mjs
```

`--api` accepts a directory containing `index.mjs`, or one self-contained module.
The API must be under `savia/demo`. `--out` accepts an empty destination directory.
Only the default `savia/.out/demo-site` destination may be replaced on rebuild.
Inputs come only from `savia/web` and `savia/demo`.
Tests, verification tools, evidence, hidden files and dependency caches are excluded.
There is no SPA redirect: navigation uses hashes; `/etiqueta/` has its own index.

Preview locally:

```sh
python -m http.server 8876 --bind 127.0.0.1 --directory savia/.out/demo-site
```

Open `http://127.0.0.1:8876/` or `http://127.0.0.1:8876/etiqueta/`.
Stop the server with Ctrl+C.
Select Dueña, Gerente, Vendedora or Bodega in “Entrar como”.
Each selection calls the existing `api.login` with password `demo`, stores its session token,
and reloads the staff app at the role's home.
“Reiniciar demo” resets the fake API and removes `savia.token` from sessionStorage.
The fixture persists its invented user in localStorage.

Live demo (Cloudflare Worker with static assets, separate from the store site):
https://savia-demo.jason-suazof.workers.dev

Deploy from the repository root after building:

```sh
python savia/tools/build_demo.py
npx wrangler deploy --config savia/demo/wrangler.jsonc
```

Never run `wrangler pages ...` from the repository root.
On 2026-11-15, `wrangler pages project create savia-demo` read the root `wrangler.jsonc`
(store preview, `./dist`) and published that store preview as Worker `savia-demo`.
It was public for 36 seconds (01:35:32 to 01:36:08 UTC), with noindex, before version
`7b92388d-b23f-42bc-8e67-d028f3204158` replaced it with this demo.
Every mutating API call targeted `savia-demo`; no other Worker or Pages project changed.
The old version `dff8fa5f-682c-41e9-89b7-ac0a8b960dbe` stays in history; preview URLs are off.
`_headers` restricts sources to this origin, allows local camera access, disables framing,
and sets noindex and no-referrer. Inline styles support the unchanged app's dynamic styles.
A CSP meta tag enforces compatible source restrictions in the Python preview.
The Python server does not apply `_headers`; deployed header behavior needs separate readback.

Acceptance:

```sh
python savia/tools/build_demo.py --api savia/demo/site/test-double.mjs
python savia/demo/site/verify.py
git diff --stat c3606073 -- savia/web savia/src savia/db savia/demo/api
```

The verification script uses agent-browser with a named session and an ephemeral localhost server.
It checks 32 role/page/viewport/theme combinations, login, home, reset, overflow, console,
network isolation and the fetch bridge. It saves PNGs, an after recording and `site/evidence/verification.json`.
Before recording was not captured. Visual approval remains with the reviewer.
The shell fixture proves wiring only. It does not prove sales, stock, money or the parallel fake API.
Camera capture, native device behavior, deployed headers and production are unverified.

The unrelated storefront check `python tests/check.py` stopped with
`FAIL: Missing jsdom: run python tests/check.py --install first.`
No dependency installation was attempted: this task permits localhost traffic only
and writes only inside the assigned shell scope.
The primary can install its pinned storefront test dependencies in its authorized checkout
and rerun that check. This does not replace the shell browser acceptance.

Local commit was attempted with `git commit -m "Add offline SAVIA demo site shell and browser evidence"`.
The hook returned exit 1:
`Progress sync BLOCKED: This hook only publishes Tony; select the approved branch. Local work is preserved.`
The current branch is `t3/demo-site-shell`. No hook bypass, branch switch or push was attempted.
All assigned files remain staged. The primary owns integration into its authorized canonical checkout
and the normal commit flow. Close this blocker only after the authorized commit returns a new SHA.

Lesson: agent-browser's daemon can inherit pipe handles from a Python subprocess.
Capture CLI output in temporary files instead of pipes; `site/verify.py` applies this correction.

## Integration on Tony (2026-11-15)

Both worker outputs were integrated in the canonical checkout; `after.webm` (4 MB) was left out of Git.
`node --test savia/demo/api`: 68 pass, 0 fail. Opening stock per size changed from 120 to 16 (range 2 to 27 after seeded history).
agent-browser at 390 and 1440 against the local build: 31 role/screen pairs each, zero console errors,
page errors, alerts, off-origin requests or horizontal overflow.
Manual flow at 390: Gerente sale paid in cash (receipt issued, stock down by one), return by transfer
(confirmation dialog, stock restored), reset, Vendedora team report with only her own row.
Live URL at 390: Gerente sale with receipt, zero page errors, zero off-origin requests, zero overflow.
Live headers read back: CSP, `X-Robots-Tag: noindex`, `Referrer-Policy: no-referrer`, Permissions-Policy.
`git diff -- savia/web savia/src savia/db`: empty. Name scan and secret scan: no matches.
Not verified: camera capture on a real phone, every screen's business rule against SQL, Safari.
Known app issue seen in the demo: Historial shows the sale UUID as heading instead of the receipt number.
