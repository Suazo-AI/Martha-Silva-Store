# Security and publication boundaries

## This repository is a demonstration and recovery archive

- The static storefront in `dist/` uses `src/demo-api.js`: orders, stock,
  checkout and administrative actions are browser-local simulations, not a
  production commerce service. Client-side administrative UI is not an access
  control boundary. Payments, refunds and fulfillment are demonstrations.
- Use synthetic contacts and addresses only. Browser local/session storage can
  retain entered details; clear site data after testing on shared computers.
  Never enter real card details, customer records or production passwords.
- The recovered Cloudflare Worker under `originals/cloudflare/` is preserved
  source, not an approved deployment. `env.ADMIN_PASSWORD` is a runtime secret
  reference, not a password value. Database bindings and secret values must be
  provisioned separately. Do not copy live database rows or admin sessions here.
- Research payment-provider scripts in `research/rea/inputs/` are untrusted,
  historical evidence, not supported dependencies. In particular the archived
  Tilopay SDK evaluates provider-returned script content. Do not execute these
  files during builds or add them to the storefront. Retain attribution and
  review redistribution rights before any public release.
- Repository creation or a Git push does not authorize deployment, DNS changes,
  database migration, real payments or production configuration changes.

## Pre-publication review (2026-10-24)

The inherited seven-commit history through `10118d1` was inspected across 90
unique file blobs, including all six compressed research evidence JSON files.
Checks covered recognizable provider tokens, private keys, credential literals,
embedded URL passwords, bearer tokens, JWTs, suspicious data/export paths,
email/contact fixtures and executable artifacts. Matches were reviewed rather
than treated as proof of a leak. The tracked storefront email is a placeholder;
test contacts are synthetic. The 11 distinct storefront raster images have no
EXIF fields. The separately recovered Worker was also checked for publication
risk; its administrator password is referenced through the environment.

No embedded credential or customer-data export was identified in this scoped
review. This is not a guarantee of absence, a full dependency audit, a production
security assessment or approval to expose a live store. Recheck the final
integrated tree and newly reachable commits before pushing: later integrations
are outside the inherited snapshot described above. Preserve valid history;
no history rewrite was performed.

## Checklist before each push or release

1. Review `git status --short`, `git diff --cached --stat` and the staged diff.
   Check all reachable history, not just current files, with a suitable secret
   scanner. Decompress archives for review; inspect binary metadata where useful.
2. Confirm the intended repository visibility is **private** and its owner and
   remote are correct. Inspect newly introduced assets, recovery metadata and
   third-party code before publication. Private repositories still must not hold
   secrets or personal/customer data.
3. Keep `.env`, `.dev.vars`, private keys, local `.wrangler` state, databases,
   database dumps and browser-session/customer exports outside Git. The ignore
   rules are guardrails, not data-loss prevention: renamed files, tracked files
   and `git add -f` bypass them. SQL migrations/schema and synthetic fixtures may
   remain tracked; review their contents individually.
4. Use secret references or sanitized `.example` files only. Store actual secrets
   in the authorized platform secret store, not source, URLs, screenshots, logs,
   build output or browser bundles. Never print secret values in audit reports.
5. Run the documented offline build and regression checks. Confirm the static
   demo does not load archived research payment SDKs or point to live payment,
   customer, administrative or inventory endpoints.
6. Treat recovered deployment configuration as historical. Before a separately
   authorized production deployment, review authentication/authorization, session
   expiry and cookie protections, CSRF/origin validation, rate limits, payment
   webhook verification/idempotency, privacy/retention, logging and backups.
7. Verify the intended commit on the remote after pushing; check any CI results.
   Do not make a private recovery repository public without a fresh review.

## If a secret or personal data is found

Stop the affected publication. Report only the path, credential/data type and
scope; do not paste the value. Rotate/revoke exposed credentials with the owner's
approval as required. Removing a current file does not remove it from history.
Agree an authorized history-cleanup and collaborator/reclone plan before
rewriting or force-pushing; do not erase valid history silently. For suspected
customer data, restrict access and coordinate removal and incident handling with
the owner through a private channel.
