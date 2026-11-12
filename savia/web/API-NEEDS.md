# Staff web API contract

The pilot web uses the implemented same-origin `/api/v1` contract.
The source of truth is [API-PILOT.md](../docs/pilot/API-PILOT.md).
There are no missing-endpoint fallbacks or manual GUID fields.

| Area | Implemented contract |
| --- | --- |
| Site | Authenticated `/me` supplies branch and operator names; no public `/node` request. |
| Reception | Suppliers use `supplierId`; session lists use `open=true&limit=50`; lines preserve `scanId`. |
| Unknown codes | Register product then item with approved cost; resolve the original scan; or reject with a reason. |
| Stock | `/stock` supplies `onHand`, `reserved` and `available`; scanning and approval do not change stock. |
| Till | Registers use `registerId`, `openTillId`, `openTillCashierId`; summary is `/cash/tills/{id}/summary`, with `expectedCashMinor`. |
| Current till | `/cash/tills/current` has no register query; register rows locate available tills before summary reads. |
| Catalog | Search and lookup are available; local writes require the pilot flag and manager or owner. |
| Sizes | No sizes endpoint exists; this pilot creates unclassified variants with the supplied name. |
| Errors | Preserve the API code, message and trace id; display unknown HTTP errors without inventing business codes. |

The sample marker describes this local pilot, not a per-row API property.
All persisted quantities and financial results are read from API responses.
Ticket previews and denomination counts calculate the staff member's pending input.
