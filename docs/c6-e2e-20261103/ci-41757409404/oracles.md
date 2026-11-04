| paso | estado | ms | ventas | ops_venta | movs | movs_venta | existencia | Σmov≠saldo | negativos | claves_dup | sesiones |
|---|---|---|---|---|---|---|---|---|---|---|---|
| sql.migrate_release | PASS | 1661 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| owner.bootstrap_console | PASS | 1372 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| sql.branch_seed | PASS | 1102 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| api.start_readiness_anonymous | PASS | 666 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| owner.login_readiness | PASS | 1464 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| owner.seed_directory | PASS | 343 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| owner.seed_stock_adjustments | PASS | 276 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| owner.seed_staff | PASS | 656 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| owner.scope_and_logout | PASS | 198 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 0 |
| browser.start | PASS | 2033 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 0 |
| browser.cashier_login | PASS | 1320 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| browser.inventory | PASS | 156 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| browser.sale_confirmed | PASS | 311 | 1 | 1 | 4 | 1 | 28 | 0 | 0 | 0 | 1 |
| browser.receipt_reload | PASS | 859 | 1 | 1 | 4 | 1 | 28 | 0 | 0 | 0 | 1 |
| browser.stock_after_sale | PASS | 178 | 1 | 1 | 4 | 1 | 28 | 0 | 0 | 0 | 1 |
| browser.response_loss_committed | PASS | 127 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.recover_after_reload | PASS | 853 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.repeated_reload | PASS | 760 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.stock_after_recovery | PASS | 153 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.logout | FAIL | 20126 | – | – | – | – | – | – | – | – | – |
| teardown.stop_api_drop_database | PASS | 660 | – | – | – | – | – | – | – | – | – |

## C6: Chrome y eventos saneados

Runtime: {"chrome": "Chrome/156.0.8078.47", "node": "v24.22.1", "playwright": "1.63.0"}

TLS: perfil privado; pin SPKI del certificado efímero; sin modificar almacenes.

| fuente | SHA-256 |
|---|---|
| dev/savia-staff-ui/app.mjs | 1ace7445e2f05e224dad969346eaf29e4a46ef48a9b6acfb87f338fe1beaf3ac |
| dev/savia-staff-ui/client.mjs | 3ca499eaed1a2ff636e4ed385b25bd96122488c94fad38be6bc80460f49fa6b9 |
| dev/savia-staff-ui/login.mjs | 27e733a269f38b542913c80b97b722e0f899f48d65336eb376c2db34032ae0dd |
| dev/savia-staff-ui/login.html | b9068478b46b9786c18dbe54ffa1172e1fb325e283ca944f9c2a840b37d1a686 |
| dev/savia-staff-ui/index.html | d4fcaa074c039b2f50783b3209a1429587b38f0c7e4335726dc0210be5c74c6f |
| dev/savia-staff-ui/styles.css | e43e99b50b19aeadc6ebadae63e64cf3902c96ca923d08943fa6daadff9d9ae8 |
| tests/golden-path/golden_path.py | 21a9b0185db76cdbf202793dbf24835aba23eba5ac8455cc722f2f0dd16c0661 |
| tests/golden-path/browser_path.mjs | ed2ff6dd3264b1625d1f342a003eab23dffcb3bd66512dbc2274e6d9f86766b2 |
| backend/src/Martha.Store.Api/bin/Release/net10.0/Martha.Store.Api.dll | fa990456e6f6182735d14338094c3fd5e9340557b9169e6d0e727f59cbe0a229 |

| paso | DOM comprobado | método/ruta/HTTP/clave |
|---|---|---|
| browser.start | login_ready | GET /internal/login HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/csrf HTTP 200 |
| browser.cashier_login | shell, cashier, sale_enabled | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/security/login HTTP 200<br>GET /internal/api/security/csrf HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.inventory | inventory, stock_current | GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.sale_confirmed | receipt, sale_enabled | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/commerce/sales HTTP 200 key=629ad445-952d-41c0-b02e-84091191a616<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.receipt_reload | receipt, same_receipt, sale_enabled | GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/sales/550b08b9-2978-436d-b902-ebb7c9461d2b HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.stock_after_sale | inventory, stock_current | GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.response_loss_committed | pending, pending_key_preserved | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/commerce/sales HTTP 200 key=8825b4ae-0b4e-4f99-8ccf-4f92efe59527 (respuesta descartada tras commit) |
| browser.recover_after_reload | receipt, same_receipt, sale_enabled | GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/sales/550b08b9-2978-436d-b902-ebb7c9461d2b HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/operations/commerce.sale.record HTTP 200 key=8825b4ae-0b4e-4f99-8ccf-4f92efe59527<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.repeated_reload | receipt, same_receipt, sale_enabled | GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/sales/a39b1c77-bf74-4efe-9f70-bc61d02ef253 HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.stock_after_recovery | inventory, stock_current | GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.logout |  |  |
