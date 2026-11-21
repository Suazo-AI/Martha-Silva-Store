| paso | estado | ms | ventas | ops_venta | movs | movs_venta | existencia | Σmov≠saldo | negativos | claves_dup | sesiones |
|---|---|---|---|---|---|---|---|---|---|---|---|
| sql.migrate_release | PASS | 1983 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| owner.bootstrap_console | PASS | 1696 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| sql.branch_seed | PASS | 1390 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| api.start_readiness_anonymous | PASS | 709 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| owner.login_readiness | PASS | 1842 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| owner.seed_directory | PASS | 428 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 |
| owner.seed_stock_adjustments | PASS | 344 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| owner.seed_staff | PASS | 817 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| owner.scope_and_logout | PASS | 245 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 0 |
| browser.start | PASS | 1381 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 0 |
| browser.cashier_login | PASS | 1742 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| browser.inventory | PASS | 190 | 0 | 0 | 3 | 0 | 30 | 0 | 0 | 0 | 1 |
| browser.sale_confirmed | PASS | 464 | 1 | 1 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.receipt_reload | PASS | 932 | 1 | 1 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.stock_after_sale | PASS | 183 | 1 | 1 | 5 | 2 | 27 | 0 | 0 | 0 | 1 |
| browser.response_loss_committed | PASS | 205 | 2 | 2 | 7 | 4 | 25 | 0 | 0 | 0 | 1 |
| browser.recover_after_reload | PASS | 932 | 2 | 2 | 7 | 4 | 25 | 0 | 0 | 0 | 1 |
| browser.repeated_reload | PASS | 821 | 2 | 2 | 7 | 4 | 25 | 0 | 0 | 0 | 1 |
| browser.stock_after_recovery | PASS | 186 | 2 | 2 | 7 | 4 | 25 | 0 | 0 | 0 | 1 |
| browser.logout | PASS | 660 | 2 | 2 | 7 | 4 | 25 | 0 | 0 | 0 | 0 |
| teardown.stop_api_drop_database | PASS | 847 | – | – | – | – | – | – | – | – | – |

## C6: Chrome y eventos saneados

Runtime: {"chrome": "Chrome/156.0.8078.47", "node": "v24.22.1", "playwright": "1.63.0"}

TLS: perfil privado; pin SPKI del certificado efímero; sin modificar almacenes.

| fuente | SHA-256 |
|---|---|
| dev/savia-staff-ui/app.mjs | 7499bfdd63ce02507a1df22867d27f78f33af04c667769652a8212676f14a092 |
| dev/savia-staff-ui/client.mjs | 33e8fc65f75215e7e0f7d511ccfdeb2563c257872cd513d3aded8fa2a2497f59 |
| dev/savia-staff-ui/login.mjs | 139fb119d215df458f67d3cb5916dbe3bd6db8682da113297d45121c2725cf66 |
| dev/savia-staff-ui/login.html | b9068478b46b9786c18dbe54ffa1172e1fb325e283ca944f9c2a840b37d1a686 |
| dev/savia-staff-ui/index.html | 79a97d04380755114f243de2bf552f387b305567dbfb08e1d7423a0b6fd1a038 |
| dev/savia-staff-ui/styles.css | e87afda331f5a2ce1a028eb65bafe12f4bb7a30b8d8577846e1435371df9df01 |
| tests/golden-path/golden_path.py | 0a71d09bbcaf28c971e3386451135a2fe3cb4189490bfc2a9b10dcb73ab986fb |
| tests/golden-path/browser_path.mjs | ea84dc9186201b7a74b1bcd3b5dfb0515ddb781e97d2872d38ab4943b492becc |
| backend/src/Martha.Store.Api/bin/Release/net10.0/Martha.Store.Api.dll | a268ff01faf78860f369412ec665f4223115c6e8c88f939d27037ef4b6a9f4ed |

| paso | DOM comprobado | método/ruta/HTTP/clave |
|---|---|---|
| browser.start | login_ready | GET /internal/login HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/csrf HTTP 200 |
| browser.cashier_login | shell, cashier, sale_enabled | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/security/login HTTP 200<br>GET /internal/api/security/csrf HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.inventory | inventory, stock_current | GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.sale_confirmed | receipt, sale_enabled | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/commerce/sales HTTP 200 key=b7344f47-5ea3-4e43-99c8-f3912eb3bef9<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.receipt_reload | receipt, same_receipt, sale_enabled | GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/sales/688ee69b-40fa-4ba8-a8c9-c710186bc83c HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.stock_after_sale | inventory, stock_current | GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.response_loss_committed | pending, pending_key_preserved | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/commerce/sales HTTP 200 key=1a529185-a0b7-4926-9eb9-ec8cdfc7c8f3 (respuesta descartada tras commit) |
| browser.recover_after_reload | receipt, same_receipt, sale_enabled | GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/sales/688ee69b-40fa-4ba8-a8c9-c710186bc83c HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/operations/commerce.sale.record HTTP 200 key=1a529185-a0b7-4926-9eb9-ec8cdfc7c8f3<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.repeated_reload | receipt, same_receipt, sale_enabled | GET /internal/ HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/app.mjs HTTP 200<br>GET /internal/client.mjs HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/me HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/directory/locations HTTP 200<br>GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/sales/257452ea-3918-4541-acd3-0af467cc031f HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.stock_after_recovery | inventory, stock_current | GET /internal/api/directory/items HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200<br>GET /internal/api/commerce/inventory HTTP 200 |
| browser.logout | logged_out | GET /internal/api/security/csrf HTTP 200<br>POST /internal/api/security/logout HTTP 204<br>GET /internal/login HTTP 200<br>GET /internal/styles.css HTTP 200<br>GET /internal/login.mjs HTTP 200<br>GET /internal/api/security/csrf HTTP 200<br>GET /internal/api/security/me HTTP 401 |
