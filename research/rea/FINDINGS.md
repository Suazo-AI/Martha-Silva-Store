# REA: payment-flow deltas from public JavaScript

Date: 2026-10-24 UTC. Root folder: `local REA audit workspace (not deployed)`.

## Method and scope

REA 6.7.0 static `analyze-javascript-application` output was read first, then the exact saved sanitized JavaScript was cross-checked as inert text. No application execution, requests to payment endpoints, card entry, checkout submission, or private-backend inspection was performed for these findings. Source URLs, retrieval details and sanitized hashes are in `inputs/manifest.json` and `inputs/other-four-manifest.json`.

Six artifact groups are NOT six fully analyzed websites: four merchant-related samples (Aguamarina, La Cosmetiquera, Chunche and Limoncello), plus two provider SDKs (Tilopay and Cybersource). Berry and YoungSkin have no REA JavaScript results in this set. All six outputs have zero syntax parse failures, but semantic coverage is `unknown`. Structural graph coverage is `partial` for Tilopay and Cybersource and `complete` only within the selected artifacts for the other four. None establishes whole-site completeness or successful live payments.

## Strongest useful new findings

### La Cosmetiquera: hosted card fields and tokenization flow

Evidence: `evidence/lacosmetiquera.json`, ID `ev_63bf5040280c557999e13b9b8c5f7c6297293c36f4351cd1c78b85c3f3c2ee67`; one parsed file, 7,650 bytes. Public merchant-hosted wrapper: `inputs/lacosmetiquera/wc-cybersource.min.js`.

Manual cross-check of the REA-analyzed source confirms the implementation path: receive `capture_context`; instantiate `new Flex(...)`; create a card microform; load hosted `number` and `securityCode` fields; collect expiry; call `createToken`; insert the returned token and capture context into hidden WooCommerce fields; submit the form. A saved-payment-method branch exists. Errors clear Flex data rather than blindly resubmitting.

Exact source references: line 1, columns 3413 (`init_cybersource_microform` call), 3596 (`saved_payment_method_selected`), 6106 (`createToken`); also named definitions `init_cybersource_microform`, `create_token`, `clear_flex_data`. Columns are zero-based positions in the saved text.

**Decision value:** a concrete hosted-field/tokenized checkout architecture, not just a gateway logo. Still unknown: whether this merchant's current session enables the gateway, usable capture-context provisioning, backend authorization/capture behavior, and 3DS policy. The wrapper alone does not demonstrate a 3DS challenge.

### Limoncello: Square card token + verification context + optional card storage

Evidence: `evidence/limoncello.json`, ID `ev_a3ae1935eadea98e2c104036b09949cccd4d2a062984d90a0219fa781c0ddfb8`; two parsed files, 21,385 bytes.

`inputs/limoncello/wc-square.js` initializes `window.Square.payments(applicationId, locationId)` (line 1, column 4287), then a card form. `handleSubmission` supplies billing contact, charge intent, currency and amount to `payment_form.tokenize`; successful tokenization writes a payment nonce and submits checkout. `get_intent` distinguishes `CHARGE`, `STORE`, and `CHARGE_AND_STORE`. A separate saved-card path obtains a token through the merchant's AJAX action and requests tokenization with verification details before resubmitting.

Exact definitions: `handleSavedCardSubmission`, `handleSubmission`, `get_verification_details`, `get_intent`, `should_charge_order`, `get_amount`; main flow is in saved line 1, approximate columns 5000–10000. Second captured wrapper is `inputs/limoncello/wc-square-payment-gateway-payment-form.js`.

**Decision value:** another concrete card-first checkout architecture with optional storage and customer-initiated verification context. Do not equate a public Square wrapper with confirmed live merchant eligibility, active payments, wallet enablement, or successful 3DS. No Apple Pay/Google Pay implementation was found in these two selected wrappers; this is not evidence of site-wide absence.

### Tilopay: multiple SDK branches, merchant-conditioned methods

Evidence: `evidence/tilopay.json`, ID `ev_31614a62f279c0dbf41d149e448d5795893863632b865d9c8785547e2882b8bf`; one parsed file, 42,743 bytes; graph partial. Provider public SDK, **not a captured merchant configuration**: `inputs/tilopay/sdk_tpay.min.js`.

REA recovered nine fetch endpoint occurrences, all with partial resolution. Examples with REA source ranges (line 1): `api/v1/processSdk` columns 4446–4861 and 8561–8867; `admin/processPaymentFAC` 9770–12113; `admin/processPaymentTokenex` 12673–12846; Apple Pay merchant validation 27969–28033; SINPE check 29364–29599 and update 30315–30502. Manual source inspection finds `baseUrlTilopay="https://app.tilopay.com/"` at column 368; resolving those strings against this assignment is a manual inference, not a runtime network observation.

`Init` receives available methods/cards from the provider response (`o.methods`, column 4916), so a generic SDK's supported branches are not necessarily offered to every merchant. `InitTokenize` (column 6717) is separate from ordinary payment initialization. The SDK has returned-HTML/form handling and `PowerTranz`/`3dserror` branches (around column 13033), indicating an implemented authentication handoff path, not proof a particular transaction will challenge. Apple Pay checks browser support and merchant ID and uses merchant validation; its request includes a CR country code. SINPE paths likewise must not be generalized to Nicaragua merchant availability.

**Decision value:** Tilopay is a candidate integration family supporting more than one backend/payment route; obtain merchant-specific availability before comparing costs or promising wallets, stored cards, installments, or country support. No credentials were used; one JWT-like literal was redacted before analysis, so hashes describe sanitized files.

## Useful negative boundaries

- **Aguamarina:** `evidence/aguamarina.json`, ID `ev_c26028f6e459da94b6774d0581ef5d2520fdc832631bb9449f20c9e817872cb5`; `inputs/aguamarina/wc-credomatic-paycom-gateway-frontend.js`, 547 bytes. Captured script only applies `.alpha()` to cardholder-name inputs initially and on `updated_checkout`. It adds no evidence about tokenization, hosted fields, 3DS, processor endpoints or card authorization. Gateway filename alone must not become a claim about those capabilities.
- **Chunche:** `evidence/chunche.json`, ID `ev_ea210fa531f4c255a8ba00444975db243f14bf3b1e40fdb4ddb4870c0b8c500a`; `inputs/chunche/wc-payment-method-cod.js` and `wc-payment-method-bacs.js`, 1,543 bytes total. These are WooCommerce cash-on-delivery/bank-transfer registration wrappers, not a card gateway. COD has virtual-order/shipping-method conditions. Public assets do not establish that either method is currently enabled or that no card option exists.
- **Cybersource SDK corroboration:** `evidence/cybersource.json`, ID `ev_ba995627e3c2d9a67473c41a84fd2a56132b94a8cfb69075d7e854fc5725e903`; `inputs/cybersource/flex-microform.min.js`, 28,618 bytes, 81 recovered bundle modules. Confirms provider-side frontend machinery includes iframe fields, origin-scoped message communication and `createToken` (saved line 5, column 26832). This corroborates the wrapper architecture but does not expose merchant backend configuration or prove compliance/security guarantees.

## Conclusion for the later decision

Keep three distinct card-integration possibilities on the comparison board: Cybersource hosted microform/tokenized WooCommerce checkout, Square tokenized checkout with verification context, and Tilopay SDK's merchant-conditioned payment/tokenization branches. Treat BAC/PayCOM implementation depth as still unresolved from the tiny captured frontend helper. This pass has not selected a provider, established merchant eligibility, or implemented payment processing.
