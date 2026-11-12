# Staff web pilot (Sucursal Masaya)

The staff web is plain static files in `savia/web/`.
It calls the real branch API through `savia/web/api.mjs`.
Gaps in the API are listed in [API-NEEDS](../../web/API-NEEDS.md).

## Run locally

1. Run the branch API on `http://127.0.0.1:5081`.
2. Run `python savia/tools/web_dev.py`.
   It serves the web on `http://127.0.0.1:5090` and proxies `/api` to the API on the same origin, on loopback only.
3. Open `http://127.0.0.1:5090/`.

## Checks

- Unit: `node --test savia/web/tests/` (22 tests).
- End to end: `SAVIA_E2E_PASSWORD=<fixture password> python savia/web/tests/e2e_pilot.py`.
  It drives a real Chrome through the `agent-browser` CLI and compares each number on screen with an API read-back.
  The run of 2026-11-12 is in [e2e-run-20261112.txt](e2e-run-20261112.txt).
- Screenshots at 1024x768 are in [screens/](screens/).

## Known differences from the SAVIA 08 reference

- Garment photos are placeholders ("Sin foto"). The API has no image field.
- At 1024 px the rail becomes a top row. The reference does the same below 1050 px.
- The left side of Venta stays empty until a search endpoint exists (API-NEEDS row 2).
- A reception line shows "—" for quantity until the lines endpoint exists (API-NEEDS row 1).
