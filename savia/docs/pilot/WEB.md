# SAVIA pilot staff web

Owner decisions, 2026-11-12. Local Masaya pilot only. Work continues in the canonical checkout.
No deployment, external service, new dependency, container, commit or push.

## Run locally

Use the running `savia-sqlserver-dev` container. Set distinct temporary passwords in the shell:
`SAVIA_PILOT_PASSWORD_CAJERA`, `SAVIA_PILOT_PASSWORD_SUPERVISORA`, `SAVIA_PILOT_PASSWORD_DUENA`.
Run `python savia/tools/pilot.py reset` then `python savia/tools/pilot.py up`.
Open http://127.0.0.1:5080/. The API serves static files and `/api/v1` on loopback.
Login names remain `cajera.muestra`, `supervisora.muestra`, `duena.muestra`.
See [API-PILOT](API-PILOT.md) for the SQL and HTTP contracts.

## Venta without photos

Every garment screen uses text. Product image assets, the photo helper, its CSS and Sin foto
placeholders are removed. The Venta grid remains beside the ticket. Cards show name, sizes,
price and local available stock. Type/size filters intersect with name/SKU search. Scanning
adds the exact variant. Multiple variants open a size picker with each size's price and stock.

Zero-stock cards say Sin existencia en sistema and stay selectable. Adding above the available
quantity asks: El sistema muestra 0. Confirmar que la prenda está en la tienda. Cancel leaves the
ticket unchanged. Confirm records the physical-stock note with the sale. SQL creates a traced
positive adjustment for the short quantity before the normal negative sale movement. A manager
reviews the pending exception from Excepciones de inventario and enters the result before Revisado.

Ticket quantity and discount controls wrap within their column. The complete ticket can scroll
vertically. Horizontal content and controls must remain within the ticket and page at 1024x768
and 1440x900. No image column remains in reception, review, inventory, history, returns or receipts.

## Cash and discounts

Abrir caja counts every NIO denomination from `GET /cash/denominations`. Each row shows quantity
and line total. The opening total is read-only. SQL rejects a separately supplied total that does
not match the breakdown. Till summaries and Cierre show the stored opening breakdown. Closing
uses the same denomination component and SQL-owned list. Opening counts cannot close the till.

Every discount requires a manager/owner. There is no 10% cashier allowance. Line/ticket percentage
fields are only requests and previews. On Cobrar a cashier gets a second real sign-in. The manager
can change each line's discount amount in cordobas and must enter a reason. The API authenticates
the live manager session separately. SQL independently checks the role and records who approved
and why. A manager selling directly supplies a reason on the ticket. Approval tokens are held in
memory, excluded from parked tickets, and logged out after submission.
A full authorized discount needs no payment. SQL accepts the zero total with an empty tender list.

Guardar ticket, Tickets guardados and the in-page Vaciar ticket confirmation remain. Drafts are
local to this browser and till. They survive reload, reserve no stock and create no server sale.
Closing/replacing the till clears them when the browser next synchronizes. Restored tickets still
need current SQL stock/price checks and fresh approval. Clearing browser storage loses drafts.

## Reports and receipts

Reportes has Día, Semana, Mes and Año views. All summary values come from SQL. The day view also
keeps the prior till/accounting detail. Week starts Monday; dates use Nicaragua time. Exportar CSV
exports the same API values in minor units. Imprimir reporte uses the report print stylesheet.
Customers served are distinct identified customers; new customers have no earlier sale here.

Recibo is a simple store receipt with a sequential branch number. It has no tax breakdown.
Reimprimir retains the 80 mm stylesheet. A browser print check does not test a physical printer.

## Preserved work and boundaries

Ajustes keeps the Bosque, Tinta and Malva palettes and their persistence on this device. Its notice
says Datos de prueba: los productos, precios y personas son ejemplos. Seed display labels omit
MUESTRA; login names stay unchanged. The header shows branch, operator, till state and till cashier.
Reception retains registration, resolution, rejection, approval, posting and labels. Customer
selection, credit returns and split tenders remain. Card and transfer references describe external
payments; there is no gateway. Returns still issue supervised store credit, not cash refunds.
Local storage is not production security. No SISFAIN backend is claimed.

## Verification

Acceptance passed: 129 SQL tests, 43 .NET tests, 42 web unit tests, smoke and two consecutive
browser runs with zero console/page errors. Commands, exits and limits are recorded in
[OWNER-VERIFICATION](OWNER-VERIFICATION.md). The first focused .NET run reproduced three failures:
opening mismatch accepted, unapproved cashier discount accepted, and zero-stock sale rejected.
An intermediate count test exposed the old one-submitted-count-per-till index. V015 separates
opening and closing kinds and preserves V007's close authorization guard.

The browser suite uses only agent-browser against the real local API. Each captured state checks
1024x768 and 1440x900 for page/ticket overflow and product images. It covers opening breakdown
read-back, manager-approved discounts, zero-stock exception and review, reports equal to API,
reception, inventory, customer credit, parked tickets and close. Current captures are in [screens](screens/).

Not verified: production, deployment, bank gateway, physical scanner/printer, multi-node sync,
mobile, full accessibility or performance acceptance. No public URL or remote delivery is claimed.
