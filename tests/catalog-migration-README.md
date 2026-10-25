# Catalog expansion safety

Run `node --test tests/backend.cjs tests/catalog-migration.cjs` (32 tests).

`fixtures/catalog-expansion.json` is the captured 40-product / 120-variant
`martha-editorial/parity-v2/catalog-fixture.json`, copied as test data only.
Image references are provenance, not newly created or published assets.
The shipped `dist/catalog.js` now serves the 40-product demo enriched with the observed media mapping. `fixtures/legacy-catalog.json` preserves the exact earlier two-product / six-variant input explicitly, so these regression tests still exercise the real six-to-120 migration rather than starting from an already expanded catalog. `original-catalog.cjs` also verifies migration against the catalog currently served.

The migration is limited to snapshots with exactly the six known legacy stock
keys and a valid legacy state, when loaded against the exact captured product
and variant identities. It adds only missing new-variant stock defaults, leaving
all existing fields intact. A normal successful API response persists it; a failed
write leaves the original storage bytes intact and can be retried. Existing
reservation expiry still applies and terminal payment/refund retries stay inert.
Other missing-stock or malformed snapshots follow the existing exact recovery
backup path; an occupied different backup prevents destructive overwrite.

Coverage includes full-state preservation, old quote checkout, pending reservations,
checkout/payment/refund retries, expiry, reloads, failed writes, invalid legacy
snapshots, partial expanded-stock loss, unknown catalogs and occupied backups.
This is browser-local demo state only, not a WooCommerce or payment migration.
Frontend checks are DOM simulations, not real-browser visual verification.
