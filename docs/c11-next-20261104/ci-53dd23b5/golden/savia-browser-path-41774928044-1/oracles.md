| paso | estado | ms | ventas | ops_venta | movs | movs_venta | existencia | Σmov≠saldo | negativos | claves_dup | sesiones |
|---|---|---|---|---|---|---|---|---|---|---|---|
| sql.migrate_release | PASS | 1858 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| owner.bootstrap_console | PASS | 1328 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| sql.branch_seed | PASS | 1049 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| api.start_readiness_anonymous | PASS | 678 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| owner.login_readiness | PASS | 1486 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| owner.seed_directory | PASS | 363 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| owner.seed_stock_adjustments | PASS | 298 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| owner.seed_staff | PASS | 714 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| owner.scope_and_logout | PASS | 204 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 0 |
| browser.start | PASS | 748 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 0 |
| browser.cashier_login | PASS | 1574 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| browser.inventory | PASS | 160 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| browser.sale_confirmed | PASS | 474 | 1 | 1 | 4 | 1 | 28 | 0 | 0 | 0 | 1 |
| browser.receipt_reload | PASS | 815 | 1 | 1 | 4 | 1 | 28 | 0 | 0 | 0 | 1 |
| browser.stock_after_sale | PASS | 164 | 1 | 1 | 4 | 1 | 28 | 0 | 0 | 0 | 1 |
| browser.response_loss_committed | PASS | 122 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.recover_after_reload | PASS | 822 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.repeated_reload | PASS | 764 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.stock_after_recovery | PASS | 151 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.logout | PASS | 640 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 0 |
| teardown.stop_api_drop_database | PASS | 650 | – | – | – | – | – | – | – | – | – |

## C6: Chrome y eventos saneados

Runtime: {"chrome": "Chrome/156.0.8078.79", "node": "v24.22.2", "playwright": "1.63.0"}

TLS: perfil privado; pin SPKI del certificado efímero; sin modificar almacenes.

| fuente | SHA-256 |
|---|---|
| dev/savia-staff-ui/app.mjs | 65b9c09dacfc858b9e70ef8baf303560e26cbc0d406c99b989b5a31d5da42327 |
| dev/savia-staff-ui/client.mjs | 3ca499eaed1a2ff636e4ed385b25bd96122488c94fad38be6bc80460f49fa6b9 |
| dev/savia-staff-ui/login.mjs | 139fb119d215df458f67d3cb5916dbe3bd6db8682da113297d45121c2725cf66 |
| dev/savia-staff-ui/login.html | b9068478b46b9786c18dbe54ffa1172e1fb325e283ca944f9c2a840b37d1a686 |
| dev/savia-staff-ui/index.html | d4fcaa074c039b2f50783b3209a1429587b38f0c7e4335726dc0210be5c74c6f |
| dev/savia-staff-ui/styles.css | e43e99b50b19aeadc6ebadae63e64cf3902c96ca923d08943fa6daadff9d9ae8 |
| tests/golden-path/golden_path.py | b957230ab923f34f56d61f1853c967f938baa8009601212dbb5dec7973ff7fbb |
| tests/golden-path/browser_path.mjs | 5a09272ffb8a1c433813bc4cad626921cd1b0ef329f0097a008122e41eb6df21 |
| backend/src/Martha.Store.Api/bin/Release/net10.0/Martha.Store.Api.dll | 986b0d7bebd700ab2fd13b7e52ac07c81d2591933604d19e2f5084442b00c694 |

| paso | DOM comprobado | método/ruta/HTTP/clave |
|---|---|---|
| browser.start | login_ready | GET /internal/login HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/csrf HTTP 200 |
| browser.cashier_login | shell, cashier, sale_enabled | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/security/login HTTP 200<br>GET /internal/api/security/csrf HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.inventory | inventory, stock_current | GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.sale_confirmed | receipt, sale_enabled | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/commerce/sales HTTP 200 key=993f48ae-4582-40e7-a45d-23087e239fd8<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.receipt_reload | receipt, same_receipt, sale_enabled | GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/sales/eeef7378-0b22-4adb-bf88-89ce255d20ec HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.stock_after_sale | inventory, stock_current | GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.response_loss_committed | pending, pending_key_preserved | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/commerce/sales HTTP 200 key=2d336f2a-27d9-492f-8101-6b6201243a2b (respuesta descartada tras commit) |
| browser.recover_after_reload | receipt, same_receipt, sale_enabled | GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/sales/eeef7378-0b22-4adb-bf88-89ce255d20ec HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/operations/commerce.sale.record HTTP 200 key=2d336f2a-27d9-492f-8101-6b6201243a2b<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.repeated_reload | receipt, same_receipt, sale_enabled | GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/sales/ff478784-411e-4e5b-9ae5-571d7f560fd0 HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.stock_after_recovery | inventory, stock_current | GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.logout | logged_out | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/security/logout HTTP 204<br>GET /internal/login HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/csrf HTTP 200<br>GET /internal/api/security/me HTTP 401 |
