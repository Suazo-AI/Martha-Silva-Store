# Critic review: SISFAIN reference and SAVIA readiness

task_id: `opus-agy-critic-20261105` · mode: VALIDATE · part B of 2
Verdict: **ACCEPT WITH LIMITS.** Material findings: 0 High/Medium, 2 Low.

Identity: Antigravity harness in T3 Code; model `claude-opus-5-5` per runtime identity. Effective reasoning is not measurable.
Reviewed: `github/docs/sisfain-reference-20261105/README.md` and `EVIDENCE.json` at Tony `70e55716…`, plus the frames and source excerpts listed below.

## Verified

Pixels: I inspected `check-17s.jpg`, `check-27s.jpg` and `check-32s.jpg` directly.
- 17 s: multi-line POS cart; I.V.A. line; `Total C$ 30.00` / `Total U$ 0.82`; Ciudad `GRANADA`; Tipo Pago `CONTADO`.
- 27 s: sales and cash-flow report list, date filters, `Exportar XLSX`.
- 32 s: customer ledger with `Abono`, running `Saldo`, a `Nota de Débito` row and button, and `Anular Movimiento`.

These frames match README rows 19, 21 and 22. They support rejecting the AGY Peru/SUNAT/IGV/credit-note claims.

Source:
- `dev/savia-staff-ui/index.html:97-99` shows purchasing and receiving as "aún no disponible".
- `client.mjs:81` requires `paymentStatus === 'not_processed'`.
- Purchase-order create, receipt and cancel routes: `InternalSupplyEndpoints.cs:27,30,33`.
- Adjustment, sale, cancel and return routes: `InternalCommerceEndpoints.cs:21,24,27,30`.

README lines 36-44 match this source and are bounded correctly.

Gates:
- D-029 is selected but not performed: README:54, 67; PROJECT-STATUS:51.
- C9: one consumed preflight, TLS-blocked, "newly authorized" attempt only, no retry: README:69; PROJECT-STATUS:4, 73, 80.
- No production-ready or three-hour guarantee: README:62-63, 75.
- Speech is reported as absent output, not absent speech: README:30-32; EVIDENCE:90-99.
- Sampled versus continuous coverage is separated: README:12-13; EVIDENCE:72-73.

Public export: no media, frames, raw responses, job identifiers or config contents are present. Global file paths and hashes are not contents.

## L1 — Low: historical global hashes read as current

Evidence: `EVIDENCE.json:100-141` lists `after_sha256` for nine global files without any snapshot or supersession marker.
Five of these values are the **before** hashes of the later orchestration edit (`global-orchestration-20261105/verification.json:18,25,32,39,46`). For example, `AGENTS.md` is `c739b3…` here and `cfadb3…` currently.
`recorded_at_utc` (08:39 UTC) gives a time. It does not tell a reader that the hashes are no longer current.

Smallest correction: add one field under `global_routing`:
`"hash_scope": "snapshot after video-routing change; superseded by later global orchestration edits; not current"`.
Alternatively, rename the key to `after_video_routing_sha256`.

## L2 — Low: the store-day case omits cutover parameters visible in the sample

Evidence: the 17 s and 32 s frames show:
- dual C$/U$ totals with an implied exchange rate;
- an I.V.A. line;
- four price tiers (`Precio1`–`Precio4`);
- CONTADO/CREDITO tender, with an automatic credit-invoice charge to the customer balance;
- movement voiding.

The README acceptance case (line 57) and the C2 gate (line 67) name payment, document, return and reconciliation only at a general level.
The SAVIA staff shell formats one `currency` per row and per receipt (`dev/savia-staff-ui/app.mjs:223, 499`).
Inference: the staff UI does not show dual-currency tender. Backend currency handling was not checked.

Impact: the D-029 reconstruction could finish without recording currency, tax, price-tier or credit rules. These rules decide whether one store day reconciles.

Smallest correction: add one sentence after README:57 or to the D-029 question list:
"Confirm accepted currencies and exchange-rate source, IVA treatment, price-tier rules, and cash versus credit sales for cutover."
This is a question for Martha, not a product requirement and not a blocker.

## Not verified by this critic

- Frames at 8, 12, 22 and 39 s, and the overview.
- Directory write endpoints.
- The canonical `AI-OS/rules/video.md` and `.agents/skills/youtube-video-workflow/SKILL.md`. The harness denied those paths, and I did not bypass the denial.
- Any runtime.
