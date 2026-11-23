# W9 legal and contact copy: sources

Status: drafted from public sources on 2026-11-23. Not confirmed by the business or a lawyer.
Page: `build-inputs/static/ayuda.html` (sections `devoluciones`, `terminos`, `privacidad`, `contacto`).
Checkout notice: `src/app.js`, contact step, class `checkout-legal`.

## Business details

| Detail | Value used | Source | Confidence |
|---|---|---|---|
| Name | Martha Silva Store | Waze place name; Instagram `marthasilva.store` | public listing |
| Address | Plaza Natura, de la Rotonda Universitaria 200 m al oeste, Pista Suburbana, Managua | Waze "Martha Silva Store - Plaza Natura"; a Facebook result gives the same place | public listing |
| Phone and WhatsApp | +505 8856 5666 | already on the site; Waze listing | public listing |
| Hours | Monday to Saturday 10:00-19:00, Sunday 11:00-17:00 | Waze only | single source |
| Email | not published | none found | missing |
| Legal name, RUC | not published | none found | missing |

Other branches and phones seen in search results (Km 15.7 carretera a Masaya, Paseo Masaya) were not verified and are not published.

## Sentence to law

| Page sentence (short) | Law | Article |
|---|---|---|
| Seller identity, address, phone before buying | Ley 842, consumer protection | Art. 78, 82 |
| Price, delivery cost and total before confirming | Ley 842 | Art. 82 |
| Repair, exchange or refund for a defect or a mismatch | Ley 842 | Art. 41, 45, 46 |
| Withdraw within five business days of receiving the item | Ley 842 | Art. 81 |
| Complaint within 30 business days; reply within 10 business days | Ley 842 | Art. 100 |
| Data controller, purpose, data collected | Ley 787, personal data | Art. 7 |
| News only with consent; can ask to stop | Ley 787 | Art. 6, 25, 26 |
| See, correct or delete data; reply within 10 business days | Ley 787 | Art. 7, 17, 19 |

Ley 1061 (2021) reformed Ley 842 Art. 5, 9, 53, 54 and 120. No reform of Art. 81 was found.

## Privacy claims checked against code

- Checkout details and the last order use `sessionStorage` (one browser tab); key `martha-${integrationMode}-${name}-v1` in `src/app.js`.
- The checkout newsletter box starts unchecked; the order payload carries `newsletter` only as the buyer's choice.
- The footer email form sends nothing.

## Open for the business or a lawyer

1. Email address for Art. 78.
2. Legal name and RUC for the seller identity.
3. Registration of the data file under Ley 787 Art. 22.
4. Confirm the hours (one source only).
5. Reglamento of Ley 842 Art. 41 limits distance withdrawal to defective or mismatched goods; the law (Art. 81) does not. A lawyer should choose the wording.
6. Ley 842 Art. 10(5) and 23(4) ask for prices in córdobas with taxes. The store shows USD. Ley 732 Art. 37 exceptions were not read.
7. Whether staff can correct or blank a buyer's contact details on the hub when asked.
