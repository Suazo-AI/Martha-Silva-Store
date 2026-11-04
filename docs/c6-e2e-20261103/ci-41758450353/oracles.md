| paso | estado | ms | ventas | ops_venta | movs | movs_venta | existencia | Σmov≠saldo | negativos | claves_dup | sesiones |
|---|---|---|---|---|---|---|---|---|---|---|---|
| sql.migrate_release | PASS | 1629 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| owner.bootstrap_console | PASS | 1366 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| sql.branch_seed | PASS | 1105 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| api.start_readiness_anonymous | PASS | 667 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| owner.login_readiness | PASS | 1494 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| owner.seed_directory | PASS | 353 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| owner.seed_stock_adjustments | PASS | 278 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| owner.seed_staff | PASS | 650 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| owner.scope_and_logout | PASS | 212 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 0 |
| browser.start | PASS | 6599 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 0 |
| browser.cashier_login | PASS | 1468 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| browser.inventory | PASS | 164 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| browser.sale_confirmed | PASS | 442 | 1 | 1 | 4 | 1 | 28 | 0 | 0 | 0 | 1 |
| browser.receipt_reload | PASS | 829 | 1 | 1 | 4 | 1 | 28 | 0 | 0 | 0 | 1 |
| browser.stock_after_sale | PASS | 185 | 1 | 1 | 4 | 1 | 28 | 0 | 0 | 0 | 1 |
| browser.response_loss_committed | PASS | 123 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.recover_after_reload | PASS | 834 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.repeated_reload | PASS | 793 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.stock_after_recovery | PASS | 156 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.logout | PASS | 648 | 2 | 2 | 5 | 2 | 27 | 0 | 0 | 0 | 0 |
| teardown.stop_api_drop_database | PASS | 683 | – | – | – | – | – | – | – | – | – |

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
| tests/golden-path/browser_path.mjs | 178d42bcc034870159ee20b22edf81c93a337edb963ec03430af311bf67d0666 |
| backend/src/Martha.Store.Api/bin/Release/net10.0/Martha.Store.Api.dll | 25fef09a3d9e28f86b4c6fc79344a1e84716c9dc326bdb88143f93fea193a089 |

| paso | DOM comprobado | método/ruta/HTTP/clave |
|---|---|---|
| browser.start | login_ready | GET /internal/login HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/csrf HTTP 200 |
| browser.cashier_login | shell, cashier, sale_enabled | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/security/login HTTP 200<br>GET /internal/api/security/csrf HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.inventory | inventory, stock_current | GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.sale_confirmed | receipt, sale_enabled | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/commerce/sales HTTP 200 key=c6a7a56e-480c-42fd-842f-67340f62314b<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.receipt_reload | receipt, same_receipt, sale_enabled | GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/sales/cfb4a3ba-cd90-4019-8839-1104cc634f55 HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.stock_after_sale | inventory, stock_current | GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.response_loss_committed | pending, pending_key_preserved | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/commerce/sales HTTP 200 key=8c95026a-5eb3-4656-98b9-7862b0bb6db5 (respuesta descartada tras commit) |
| browser.recover_after_reload | receipt, same_receipt, sale_enabled | GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/sales/cfb4a3ba-cd90-4019-8839-1104cc634f55 HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/operations/commerce.sale.record HTTP 200 key=8c95026a-5eb3-4656-98b9-7862b0bb6db5<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.repeated_reload | receipt, same_receipt, sale_enabled | GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/sales/d72d036f-7474-4ce0-8c1e-0c0be5699069 HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.stock_after_recovery | inventory, stock_current | GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.logout | logged_out | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/security/logout HTTP 204<br>GET /internal/login HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/csrf HTTP 200<br>GET /internal/api/security/me HTTP 401 |
