| paso | estado | ms | ventas | ops_venta | movs | movs_venta | existencia | Σmov≠saldo | negativos | claves_dup | sesiones |
|---|---|---|---|---|---|---|---|---|---|---|---|
| sql.migrate_release | PASS | 2000 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| owner.bootstrap_console | PASS | 1743 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| sql.branch_seed | PASS | 1442 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| api.start_readiness_anonymous | PASS | 708 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| owner.login_readiness | PASS | 1912 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| owner.seed_directory | PASS | 421 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| owner.seed_stock_adjustments | PASS | 336 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| owner.seed_staff | PASS | 836 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| owner.scope_and_logout | PASS | 245 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 0 |
| browser.start | PASS | 1736 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 0 |
| browser.cashier_login | PASS | 2773 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| browser.inventory | PASS | 185 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| browser.sale_confirmed | PASS | 309 | 1 | 1 | 4 | 1 | 28 | 0 | 0 | 0 | 1 |
| browser.receipt_reload | PASS | 878 | 1 | 1 | 4 | 1 | 28 | 0 | 0 | 0 | 1 |
| browser.stock_after_sale | PASS | 200 | 1 | 1 | 4 | 1 | 28 | 0 | 0 | 0 | 1 |
| browser.response_loss_committed | PASS | 135 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.recover_after_reload | PASS | 904 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.repeated_reload | PASS | 828 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.stock_after_recovery | PASS | 183 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.logout | PASS | 649 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 0 |
| teardown.stop_api_drop_database | PASS | 876 | – | – | – | – | – | – | – | – | – |

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
| backend/src/Martha.Store.Api/bin/Release/net10.0/Martha.Store.Api.dll | 794f1faaf6e67889a0ef13978083d1eba022bfca7d6176a0216c8b81ff4b4106 |

| paso | DOM comprobado | método/ruta/HTTP/clave |
|---|---|---|
| browser.start | login_ready | GET /internal/login HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/csrf HTTP 200 |
| browser.cashier_login | shell, cashier, sale_enabled | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/security/login HTTP 200<br>GET /internal/api/security/csrf HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.inventory | inventory, stock_current | GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.sale_confirmed | receipt, sale_enabled | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/commerce/sales HTTP 200 key=f403bb85-8e19-411b-aa23-8832142111e4<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.receipt_reload | receipt, same_receipt, sale_enabled | GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/sales/ed15f67d-5b7f-44dd-92c8-12a79ec0a148 HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.stock_after_sale | inventory, stock_current | GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.response_loss_committed | pending, pending_key_preserved | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/commerce/sales HTTP 200 key=f11ad76b-163d-400e-b885-a9aaa7a3f4f1 (respuesta descartada tras commit) |
| browser.recover_after_reload | receipt, same_receipt, sale_enabled | GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/sales/ed15f67d-5b7f-44dd-92c8-12a79ec0a148 HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/operations/commerce.sale.record HTTP 200 key=f11ad76b-163d-400e-b885-a9aaa7a3f4f1<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.repeated_reload | receipt, same_receipt, sale_enabled | GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/sales/caf75dd9-f618-4e4d-bb63-43eadce2c9b6 HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.stock_after_recovery | inventory, stock_current | GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.logout | logged_out | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/security/logout HTTP 204<br>GET /internal/login HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/csrf HTTP 200<br>GET /internal/api/security/me HTTP 401 |
