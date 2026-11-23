# Day zero: empty databases to a paid and fulfilled web order

Checklist rows D0, D1 and D3 in [README.md](README.md).
This is the operator sequence that worked in [run 2](day-zero-evidence/run2.md), with shipped commands, routes and screens only.
[Run 1](day-zero-evidence/run1.md) is the same sequence before the fixes; its BLOCKED rows are the gaps closed below.
The local driver `savia/tools/rehearsal/dayzero.py` runs these steps against the dev SQL container; this page is the human form.

Every staff, branch, location, register and node row is local to one database: these tables are not synced (V053).
So steps 2 to 4 run on the hub database and on every store database, with the same ids.
Passwords are per database too: a person signs in on the hub and on a store with the password set on each.

## Ids to choose first

Choose these GUIDs once and keep them in the operator's protected notes (no secrets among them):
hub node, store node, branch, location, register, owner, and one per staff member.

## 0. Databases

Create the hub database and one database per store (Azure SQL Database for the hub; the store's SQL Server on site).
Migrate each one with the production migrator, and give the API host's database user its role:

```powershell
$env:Savia__Sql__ConnectionString = '<database, as an admin>'
dotnet Savia.Migrator.dll --migrations db/migrations --grant-app-user <API host user>
```

The API host user gets `savia_api_host` only (V035).

## 1. First hub owner

```powershell
$env:Savia__Sql__ConnectionString = '<hub database>'
dotnet Savia.Migrator.dll --provision-staff --staff-id <owner id> --login <login> --display-name '<name>' --role OWNER --set-password
```

The last output line is `staff-password: <password>`, printed once; SQL keeps only its hash.
Give it to the owner in person.
It is a one-time password (V064): at the first sign-in the web app shows only "Cambie su contraseña temporal", and every other route answers 403 `auth.password_change_required` until the owner changes it.
To set a password you chose instead, put it in `SAVIA_STAFF_PASSWORD` for that one command; the migrator never prints it then, and no change is forced.
On Azure, always use `SAVIA_STAFF_PASSWORD` from Key Vault: the job's output goes to Log Analytics ([RUNBOOK.md](../../savia/docs/deploy/RUNBOOK.md) section 3.1).
There is no default password, and a retry with the same id and login is a no-op.

## 2. Branch, location and register, on the hub and on the store

Run the same command on the hub database and on the store database:

```powershell
dotnet Savia.Migrator.dll --provision-branch --branch-id <branch id> --branch-code <CODE> --branch-name '<name>' `
  --store-name '<name on receipts>' --location-id <location id> --location-code <CODE> --location-name '<name>' `
  --register-id <register id> --register-code CAJA1 --register-name 'Caja 1'
```

The hub then also holds the branch's web location (`WEB-<location code>`, V047), used for web stock.

## 3. Staff, on the hub and on the store

Run on both databases, once per person, with the same id each time:

```powershell
$env:SAVIA_STAFF_PASSWORD = '<this person's password on this database>'
dotnet Savia.Migrator.dll --provision-staff --staff-id <id> --login <login> --display-name '<name>' --role MANAGER --branch-id <branch id> --approver --set-password
dotnet Savia.Migrator.dll --provision-staff --staff-id <id> --login <login> --display-name '<name>' --role CASHIER --branch-id <branch id> --set-password
Remove-Item Env:SAVIA_STAFF_PASSWORD
```

Also run the owner's command on the store database, without `--set-password`.
The owner's row must exist there because rows the owner writes on the hub (catalog, prices, suppliers) reach the store with the owner as author.

## 4. Nodes and the store credential

```powershell
# hub database: the hub's own node
dotnet Savia.Migrator.dll --provision-node register --node-id <hub node id> --node-kind azure --node-code <HUB CODE>
# store database: the hub node and the store node
dotnet Savia.Migrator.dll --provision-node register --node-id <hub node id> --node-kind azure --node-code <HUB CODE>
dotnet Savia.Migrator.dll --provision-node register --node-id <store node id> --branch-id <branch id> --node-code <STORE CODE>
# hub database: the store node and its credential
dotnet Savia.Migrator.dll --provision-node create --node-id <store node id> --branch-id <branch id> --node-code <STORE CODE>
```

The last command prints `node-secret: <secret>` once.
To pass a secret you generated instead, put it in `SAVIA_NODE_SECRET` for that one command: the migrator checks it (43 to 256 base64url characters), stores its hash and prints no secret.
On Azure, always use `SAVIA_NODE_SECRET` from Key Vault ([RUNBOOK.md](../../savia/docs/deploy/RUNBOOK.md) section 3.1).
The hub's own node row must exist on the hub database: without it the hub refuses every store round with `sync.node_unknown` (run 1, step 5).
Details and rotation: [PROVISIONING.md](../../savia/docs/sync/PROVISIONING.md).

## 5. Start the hosts

| Setting | Hub | Store |
| --- | --- | --- |
| `Savia__Node__Kind` | `Cloud` | `Branch` |
| `Savia__Node__NodeId` | hub node id | store node id |
| `Savia__Node__BranchId`, `Savia__Node__LocationId` | — | branch id, location id |
| `Savia__Sync__HubUrl`, `Savia__Sync__NodeSecret` | — | hub address, secret from step 4 |
| `Savia__Public__AllowedOrigins` | storefront origin | — |
| `Savia__Public__Turnstile__Secret` | Turnstile secret (local run instead: `Savia__Public__BotCheck=disabled`) | — |
| `Savia__Public__OrderPageUrl` | storefront origin + `/pedido` | — |

The store's log shows `Sync round: pulled 0, pushed 0` within one interval.

## 6 and 7. Catalog on the hub; it reaches the store

The owner signs in on the hub and first replaces the one-time password (`POST /api/v1/auth/password`).
Then the owner opens "Importar catálogo" (`#/importar`), loads the file, reviews and imports.
Prices: "Precios" (`#/precios`).
Routes behind the screens: `POST /api/v1/catalog/import/preview`, `POST /api/v1/catalog/import`, `POST /api/v1/catalog/items/{id}/values`.
The store refuses catalog changes (`catalog.managed_by_hub`, D-042) and receives the items and prices on its next rounds.

## 8. Receiving on the store

1. Supplier, once, on the hub: "Importar catálogo" → "Nuevo proveedor" (name only), or `POST /api/v1/suppliers` as OWNER, body `{ "supplierId": "<new id>", "name": "<name>" }`. It reaches the store by sync.
2. On the store, "Recepción": open a session for the supplier, scan each item, the manager approves and posts.
   Routes: `POST /api/v1/receiving/sessions`, `.../scans`, `.../approve`, `.../post`.

## 9. Till and counter sale on the store

"Caja" opens the till (`POST /api/v1/cash/tills`); "Venta" records the sale (`POST /api/v1/sales`).

## 10. Stock for the web

On the store, a manager consigns units to the web: `POST /api/v1/stock/web-consignments`.
The units leave the store's pool at once and reach the hub's web location on the next round and sweep.
The hub's `GET /api/v1/public/catalog` then shows them as available.

## 11. Storefront and a buyer's order

1. In `site.config.json`, set `storefront.apiBase` to the hub address, `storefront.turnstileSiteKey`, and `storefront.skus`: storefront slug to hub SKU, one entry per size sold.
2. `python prepare.py`, then publish `dist/` as in [STOREFRONT-DEPLOY.md](STOREFRONT-DEPLOY.md).
   The local run used `prepare.py --config <copy> --output <scratch folder>` and `wrangler dev` on 127.0.0.1:8787, so `site.config.json` stayed unchanged.
3. The buyer adds the item, checks out with "Pago manual" and confirms; the order page shows "Reservado, pago pendiente".

The public order route takes the hub SKU, not the storefront slug.
One order sent twice with the same `Idempotency-Key` is stored once (W2, run 2 row 11.1).

## 12. Staff record the payment and fulfil

The owner or a manager signs in on the hub, opens "Administración → Pedidos web" (`#/pedidos-web`).
"Sin pagar" lists the order.
"Registrar pago" with the bank reference, confirm; then "Por enviar", "Marcar enviado", confirm.
The buyer's order page shows "Pago aprobado", then "Pedido completado".

## 13. What the store sees

The store's stock for the item is the received units minus the consigned units; the web sale moves hub stock only.
The store gets no web order and no payment notice: by design, web orders are worked on the hub (open gap 1).

## 14. Store upgrade (D3)

The hub refuses a store on another schema version with `sync.schema_mismatch`, so every hub migration stops each store's sync until it upgrades.
Order: hub first, then each store.

1. Stop the store host. Sales wait; nothing is lost (the store keeps its own database).
2. Run the migrator of the hub's release on the store database (`--migrations db/migrations`).
3. Start the store host. The log shows `Sync round: pulled ...` again.

Runbook form: [RUNBOOK.md section 5](../../savia/docs/deploy/RUNBOOK.md).

## Customers and credit transfers (D1)

On a store, "Clientes" (`#/clientes`): "Nueva clienta" creates a customer (`POST /api/v1/customers`; the store owns the row, D-039).
"Consultar" shows the customer's credit per store.
For credit held at another store, "Traer a esta sucursal" requests it with an amount and a reason (`POST /api/v1/credit-transfers`).
"Traslados de anticipo" (`#/traslados`) lists transfers on both nodes, with only the steps the node owns:

| Step | Node | Route |
| --- | --- | --- |
| request | store that wants the credit (or the store that holds it) | `POST /api/v1/credit-transfers` |
| approve, cancel | hub | `POST /api/v1/credit-transfers/{id}/approve`, `.../cancel` with a reason |
| dispatch | store that holds the credit | `POST /api/v1/credit-transfers/{id}/dispatch` |
| receive | store that asked | `POST /api/v1/credit-transfers/{id}/receive` |

Run 2 row 15 did the customer and the two transfer lists in a browser with one store.
The rehearsal's `credit_transfer` scenario runs the four transfer steps over HTTP across three stores and the hub.

## Open gaps

1. **The store is not told about web orders.**
   Web stock moves to the hub when a store consigns it, and staff work web orders on the hub screen (ORDER-PATH.md).
   A store team that packs the order has no view of it unless it signs in to the hub.
   Proposed design: a hub-to-store event per paid order (order code, lines, source location, buyer's name and delivery zone, no payment data), applied into a read-only store table and shown in a store screen "Pedidos web por preparar".
   Needs a business decision first: who packs and ships web orders (open gap 1 in the answer to Jason).
2. **Closed: staff change their own password** (V064, tested locally, not run on Azure).
   `POST /api/v1/auth/password` (signed in, current and new password) writes the hash on that node only, keeps the caller's session and revokes the others.
   A wrong current password answers 403 `auth.current_password_wrong` and counts toward the lockout.
   A printed one-time password forces the change at the first sign-in; "Ajustes" → "Cambiar mi contraseña" changes it at any time.
   A person with rows on the hub and on a store changes each one separately.
3. **Closed: supplier form.** "Importar catálogo" on the hub has a name-only "Nuevo proveedor" form that calls `POST /api/v1/suppliers`.
4. **Staff, branches and nodes are created per database.** Each store's staff must be provisioned on the hub and on that store.
   Proposed design: keep the migrator commands (no secrets travel), and add a hub screen later only if the number of stores grows.
