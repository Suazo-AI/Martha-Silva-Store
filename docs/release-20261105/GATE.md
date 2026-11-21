# Historical draft — superseded

**Do not execute this interrupted draft. The current plan is [PLAN.md](PLAN.md).**
Its deadline, universal speed target, proposed catalog launch, CSRF implementation and merge sequence were not accepted.
The original bytes were retained privately before this notice; SHA256 `c3f31a0aaec4259dbea529f9f43fc8f6d649246a11785886aa4a31a116b06a49`.
The text below is historical context, not a current task packet or authorization.

# Release gate — 2026-11-05 (America/Managua)

Status: **DRAFT — Step 0.** Started 03:40. Timebox until about 06:40.
Rule: nothing merges to `main` and nothing deploys without an explicit "yes" from Jason. A model judge
confirms that the checks ran; it does not replace a human or external verification.

## Unit A — public website (`build-inputs/static` + `src` → `dist/` → Cloudflare Workers)

Current state, measured from the raw material:
- `dist/` = 450 MB; the largest images are PNGs of 2.4–2.7 MB. No measured performance budget exists.
- `wrangler.jsonc` publishes `martha-silva-preview` on workers.dev. No production domain has been decided.
- S-PAY is open: "La tienda pública no es producción sin cobro con tarjeta" (Jason's earlier criterion).

| # | Check (pass/fail) | Tool | Workstream |
|---|---|---|---|
| A1 | ≤ 200 KB compressed before first interaction on `index`, `catalogo` and one product page | resource sum + brotli/gzip | W1 |
| A2 | LCP ≤ 2.5 s, CLS ≤ 0.1, TBT as a proxy for INP ≤ 200 ms; mobile profile with 6x CPU and Slow 3G (400 kbps / 400 ms RTT) | Lighthouse CLI | W1 |
| A3 | Browse → product → contact/order works **without JS**; no horizontal scroll at 320 px | Chrome with JS disabled | W1/W3 |
| A4 | Catalog pages already visited open offline; the SW never caches admin/checkout/API | Chrome DevTools offline | W1 |
| A5 | WCAG 2.2 AA: axe 0 serious/critical on all public pages; keyboard reaches everything | axe-core + manual keyboard check | W3 |
| A6 | JSON-LD parses and meets Google's required properties (ClothingStore, Product/Offer NIO); sitemap, robots, canonical, OG; noindex while on preview | parser + Google docs; Rich Results Test if reachable | W2 |
| A7 | Privacy notice (Ley 787), prices with tax in córdobas, returns policy and business identity (Ley 842), image rights — marked "pending legal review" | official texts | W3 |
| A8 | CSP, HSTS, no secrets in `dist`; Observatory ≥ B+ once a public URL exists | headers + secret scan | W1/integration |
| A9 | `python tests/check.py` green and CI green on the exact commit | repo checks + GitHub Actions | integration |
| A10 | Rollback tested (`wrangler rollback` / previous version) before any production deploy | wrangler | Jason authorizes |

## Unit B — SAVIA internal

**Expected verdict today: NO-GO.** These blockers are not agent work:

| Blocker | Owner | Why agents can't close it |
|---|---|---|
| C2 Martha walkthrough | Jason + Martha | Real operational data; the script is ready |
| C9 backup/restore, RTO/RPO | Jason (authorization) | TLS/certificate; any new SQL attempt needs fresh authorization |
| C10 supervised in-store trial | Jason + Denis | Requires the store and people |
| P-HOST / P-SEC / P-OPS | Jason | Depend on hosting |
| S-PAY | Jason | Merchant eligibility |

Work that is safe to do on a branch today: W4 (SEC-CSRF tied to the session + N5-COV) and W5 (diagnose C9
TLS only, read-only).

## Workstreams (separate worktrees from Tony@dfc7e65, no commits, report in `docs/release-20261105/Wn/`)

| WS | Model | Owned paths |
|---|---|---|
| W1 performance + offline | GPT-6.1 Terra / high | images, CSS, service worker, `<img>` attributes, `prepare.py` |
| W2 SEO/AEO | GLM-5.3-Flash Free / high | `<head>`, robots, sitemap, FAQ copy in `ayuda.html` |
| W3 legal + a11y | DeepSeek V4.1 Flash Free / high | new legal pages, footer links, a11y attributes |
| W4 SAVIA security | GPT-6.1 Sol / high | `backend/src/Martha.Store.Api/Internal/Security/*`, related tests, `tests/browser-mock-validation.mjs` |
| W5 C9 TLS diagnosis | GPT-6.1 Sol / high | read-only; report only |

Judge: GPT-6 Astra / high, runs the checks on each worktree. Critic: Claude Opus 5.5 (Antigravity) / high,
adversarial, does not edit. At most 2 rounds per workstream, then escalate to Jason.
Integration (Tony → PR #2, then W1–W4): only the orchestrator.

## Decisions Jason owes (yes/no)

1. **D-A1.** Is it acceptable to put the website live **as a catalog without card payment** (contact/WhatsApp
   ordering) while S-PAY stays open? Recommendation: yes, with checkout hidden. Without this, Unit A is NO-GO by definition.
2. **D-A2.** Production domain and Worker: a new Worker or replace `martha-silva-preview`? (The original site stays intact.)
3. **D-A3.** Business data for the legal pages and schema: legal name, RUC, address, phone/WhatsApp, hours,
   return/exchange terms. Placeholders stay `TODO-JASON` until provided.
4. **D-B1.** SEC-CSRF: tie the token to the session? Recommendation: yes (does not block the trial).
5. **D-B2.** C9: authorize a new attempt after W5's diagnosis? (Only once you see the report.)
6. **D-B3.** Date/time for the C2 walkthrough with Martha.

## Results

Filled in with evidence as the workstreams close.
