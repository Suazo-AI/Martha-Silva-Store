# API local de demostración

`index.mjs` exporta `createFakeApi({ storage, now })` y `DEMO_USERS`.
El adaptador llama `handle({method,path,headers,body})` sin el prefijo `/api/v1`.
La respuesta contiene `status`, `headers` y `body`. CSV usa texto y `text/csv`.
`reset()` restaura la semilla y revoca los tokens de esta instancia.
La única clave persistente es `savia.demo.v1`. Un storage nulo conserva todo en memoria.

Boutique Aurora y Centro son ficticios. Todos los nombres y movimientos son inventados.
Se incluyen 40 productos, 120 variantes y 60 días con semilla PRNG `15112026`.
Las fechas siguen `now()` y el calendario de Nicaragua (UTC-6).
Los seis logins exportados usan la contraseña pública `demo`.
El OCR es una sugerencia local con espera de 800 ms. No usa red.
Las importaciones CSV y XLSX se leen localmente, sin paquetes externos.

Ventas, devoluciones, precios, costos, comisiones, caja, recepciones e importaciones modifican el estado.
Reportes y KPIs se calculan del historial. Las comisiones usan la tasa original de cada línea.
El equipo resta devoluciones para que la suma de sus vendedoras coincida con la venta neta del negocio.
Los tickets compartidos cuentan una vez en negocio y una vez para cada vendedora participante.
OWNER cambia precio/costo, tasa de comisión, plazo e importaciones. MANAGER opera caja y ventas.
SELLER recibe solo su fila en equipo y comisiones. INVENTORY recibe precios nulos y 403 en caja/precios.
Esto simula autorización para una demo pública. El almacenamiento del navegador se puede modificar.

## Verificación y límites

Base: `c3606073ae37fc3406d7a97e3140f02f55a0a578`.
Comando obligatorio: `node --test savia/demo/api`. Resultado: 68 PASS, 0 FAIL, 0 SKIP.
Los 62 wrappers HTTP tienen prueba con respuesta 2xx para un rol permitido.
`git diff --stat c3606073 -- savia/web savia/src savia/db`: vacío.
La búsqueda de nombres excluidos en `savia/demo` no encontró coincidencias.
`git diff --check`: PASS. No se añadieron secretos, archivos .env ni imágenes.
El índice `index.js` carga la suite cuando Node recibe una carpeta explícita.
Las pruebas llaman las funciones reales de `web/api.mjs` con fetch interceptado en memoria.
Los campos se extraen de los records C# de Contracts. También se revisan campos anidados.
No se afirma navegador, SQL, pagos reales, seguridad productiva ni despliegue.

`python tests/check.py` falló: `Missing jsdom: run python tests/check.py --install first.`
No se ejecutó `--install`: esta tarea prohíbe red. No se cambió la configuración Git.
El hook exige Tony; la rama administrada es `t3/savia-demo-fake-api`.
El commit local se intentó con los siete paths explícitos.
Comando: `git commit -m "Add local synthetic SAVIA demo API and contract coverage"`.
Resultado: exit 1. `Progress sync BLOCKED: This hook only publishes Tony; select the approved branch. Local work is preserved.`
No se eludió el hook. HEAD sigue en la base. Los siete archivos quedan en el índice.
Dueño del bloqueo: primary. Siguiente acción: revisar e integrar estos paths mediante el checkout autorizado.
Comprobación de cierre: commit válido en el checkout autorizado, sin bypass y sin publicación no autorizada.
El bloqueo de jsdom requiere ejecutar la comprobación general donde las dependencias ya están instaladas, o autorización de red para instalarlas.

## Cobertura

Cada fila HTTP tiene una subprueba homónima dentro de `every web endpoint: real wrappers and Contracts fields`.
Las utilidades sin ruta se distinguen explícitamente. Cero funciones HTTP sin cobertura.

| Función api.mjs | Ruta falsa | Prueba |
| --- | --- | --- |
| `uuid` | Utilidad cliente; sin ruta propia | Suite de wrappers usa request/token; sin endpoint |
| `retryIds` | Utilidad cliente; sin ruta propia | Suite de wrappers usa request/token; sin endpoint |
| `getToken` | Utilidad cliente; sin ruta propia | Suite de wrappers usa request/token; sin endpoint |
| `setToken` | Utilidad cliente; sin ruta propia | Suite de wrappers usa request/token; sin endpoint |
| `setUnauthorizedHandler` | Utilidad cliente; sin ruta propia | Suite de wrappers usa request/token; sin endpoint |
| `toError` | Utilidad cliente; sin ruta propia | Suite de wrappers usa request/token; sin endpoint |
| `request` | Utilidad cliente; sin ruta propia | Suite de wrappers usa request/token; sin endpoint |
| `login` | `POST /auth/login` | `login` |
| `logout` | `POST /auth/logout` | `logout` |
| `me` | `GET /me` | `me` |
| `lookup` | `GET /catalog/lookup` | `lookup` |
| `catalogItems` | `GET /catalog/items` | `catalogItems` |
| `searchProducts` | `GET /catalog/search` | `searchProducts` |
| `registerProduct` | `POST /catalog/products` | `registerProduct` |
| `registerItem` | `POST /catalog/items` | `registerItem` |
| `tagExtract` | `POST /inventory/tag-extract` | `tagExtract` |
| `suppliers` | `GET /suppliers` | `suppliers` |
| `openReception` | `POST /receiving/sessions` | `openReception` |
| `recordScan` | `POST /receiving/sessions/{sessionId}/scans` | `recordScan` |
| `receptionProgress` | `GET /receiving/sessions/{sessionId}` | `receptionProgress` |
| `receptionLines` | `GET /receiving/sessions/{sessionId}/lines` | `receptionLines` |
| `listReceptions` | `GET /receiving/sessions` | `listReceptions` |
| `approveReception` | `POST /receiving/sessions/{sessionId}/approve` | `approveReception` |
| `postReception` | `POST /receiving/sessions/{sessionId}/post` | `postReception` |
| `stock` | `GET /stock` | `stock` |
| `labelJobs` | `GET /labels/jobs` | `labelJobs` |
| `registers` | `GET /cash/registers` | `registers` |
| `approvals` | `GET /approvals` | `approvals` |
| `sellers` | `GET /sellers` | `sellers` |
| `quality` | `GET /receiving/sessions/{session}/quality` | `quality` |
| `recordQuality` | `POST /receiving/sessions/{session}/quality` | `recordQuality` |
| `qualityReport` | `GET /reports/receiving-quality` | `qualityReport` |
| `itemValues` | `GET /catalog/values` | `itemValues` |
| `setItemValues` | `POST /catalog/items/{itemId}/values` | `setItemValues` |
| `commissions` | `GET /reports/commissions` | `commissions` |
| `setSellerRate` | `POST /sellers/{sellerId}/rate` | `setSellerRate` |
| `exchangeRate` | `GET /exchange-rate` | `exchangeRate` |
| `setExchangeRate` | `POST /exchange-rates` | `setExchangeRate` |
| `denominations` | `GET /cash/denominations` | `denominations` |
| `openTill` | `POST /cash/tills` | `openTill` |
| `currentTill` | `GET /cash/tills/current` | `currentTill` |
| `tillSummary` | `GET /cash/tills/{tillId}/summary` | `tillSummary` |
| `recordCashCount` | `POST /cash/tills/{tillId}/counts` | `recordCashCount` |
| `closeTill` | `POST /cash/tills/{tillId}/close` | `closeTill` |
| `postSale` | `POST /sales` | `postSale` |
| `getSale` | `GET /sales/{saleId}` | `getSale` |
| `resolveScan` | `POST /receiving/sessions/{sessionId}/scans/{scanId}/resolve` | `resolveScan` |
| `rejectScan` | `POST /receiving/sessions/{sessionId}/scans/{scanId}/reject` | `rejectScan` |
| `saleTenderKinds` | Utilidad cliente; sin ruta propia | Suite de wrappers usa request/token; sin endpoint |
| `searchSales` | `GET /sales` | `searchSales` |
| `searchCustomers` | `GET /customers` | `searchCustomers` |
| `searchCredits` | `GET /credits/search` | `searchCredits` |
| `dayReport` | `GET /reports/day` | `dayReport` |
| `summaryReport` | `GET /reports/summary` | `summaryReport` |
| `stockExceptions` | `GET /stock/exceptions` | `stockExceptions` |
| `reviewStockException` | `POST /stock/exceptions/{id}/review` | `reviewStockException` |
| `exportSummary` | `GET /reports/summary.csv` | `exportSummary` |
| `exportCommissions` | `GET /reports/commissions.csv` | `exportCommissions` |
| `postCreditReturn` | `POST /sales/{saleId}/returns/credit` | `postCreditReturn` |
| `postReturnOutcome` | `POST /sales/{saleId}/returns/outcome` | `postReturnOutcome` |
| `returnPolicy` | `GET /returns/policy` | `returnPolicy` |
| `setReturnWindow` | `POST /returns/policy` | `setReturnWindow` |
| `kpiBusiness` | `GET /reports/kpi/business` | `kpiBusiness` |
| `kpiTeam` | `GET /reports/kpi/team` | `kpiTeam` |
| `exportKpiBusiness` | `GET /reports/kpi/business.csv` | `exportKpiBusiness` |
| `exportKpiTeam` | `GET /reports/kpi/team.csv` | `exportKpiTeam` |
| `importFile` | `POST /catalog/import/file` | `importFile` |
| `previewImport` | `POST /catalog/import/preview` | `previewImport` |
| `importCatalog` | `POST /catalog/import` | `importCatalog` |
| `endApproval` | `POST /auth/logout` | `endApproval` |

| `send` | Todas las rutas anteriores | Suite de wrappers, CSV y errores |
| `q` | Query strings de las rutas anteriores | `dayReport`, `searchSales`, `kpiTeam` |
| `path` | Segmentos de identificador | `getSale`, `postReception`, `setItemValues` |
| `exportReport` | Las cuatro rutas CSV anteriores | Las cuatro pruebas export |

## Pruebas adicionales

- `new sale, return, reconciliation, permissions, reset, deterministic reports`: venta y devolución cambian reportes; tres vendedoras concilian; roles y reset.
- `persistence, idempotency, rollback, logout and invalid credentials`: persistencia entre instancias, replay, conflicto, rollback y 401.
- `CSV/XLSX parsing uses only local bytes`: CSV con comillas y XLSX almacenado/DEFLATE.
- `catalog, reception, till, labels and history mutate persisted projections`: valores, inventario, importación, recepción y etiquetas.
- `coverage table names every web HTTP wrapper`: cada función HTTP est? documentada.

Siguiente acción: el primary revisa e integra con el adaptador del sitio. La integración móvil no corresponde a este worker.

Lección aplicada: Node resuelve una carpeta explícita mediante index.js. El índice carga la suite real; se verifica el conteo de 68 casos, no solo el exit 0.
