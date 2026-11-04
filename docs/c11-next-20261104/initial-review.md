# C11 / N10 — revisión independiente

**NEEDS WORK.** Ocho criterios tienen evidencia técnica suficiente dentro de las capas indicadas. **N5 queda PENDING** por un subcaso original sin prueba directa. No se demostró un defecto de producto.

Candidato: `e4b7910835bf2c9901aa06989e296997875a3636`.
HEAD al revisar: el mismo SHA. Las fuentes focales no tienen diff frente al candidato.
Revisor: `gpt-6-astra / high`, SUAZO-PC.
Contrato congelado: `docs/delivery-20261031/NEXT-INCREMENT.md`, N1–N10; ledger C11: «Veredicto escrito: ledger antes/después sin segundo débito ni éxito inventado».
Se conserva la excepción C7 aceptada en `docs/c7-closure-20261103/README.md`.

## Hallazgo que impide aceptar N10 completo

**C11-N5-01 — falta evidencia de la cookie vieja tras reasignación real del Cashier.**

N5 exige que la sesión vieja pierda acceso después de cambiar de sucursal. Los cinco casos browser N5 pasan, pero responden mediante API simulada. Prueban manejo del recibo 403/404/503, preservación de un intento incierto y cierre ante 401. No ejecutan la reasignación real del usuario.

`InternalBranchScopeSqlTests.cs:93-118` prueba un Manager con sesión nueva válida. Su fixture, líneas 352–360, cambia BranchId, rota SecurityVersion, revoca sesiones y fabrica la nueva sesión directamente. No ejercita el endpoint Owner ni presenta la cookie HTTP anterior del Cashier.

Los casos HTTP existentes de revocación cubren cambio de rol y deshabilitación. `InternalSecurityService.cs:101-116` sí llama a `RotateSecurity` después de cambiar BranchId. Esa lectura apoya que la implementación prevista revoca; no reemplaza el subcaso ejecutado.

**Acción mínima:** el integrador agrega una regresión HTTP+SQL sintética: Cashier entra y vende en A; Owner lo reasigna a B mediante endpoint normal; cookie guardada de A recibe 401; nuevo login confirma B y no accede al recibo de A. Comparar ledger comercial antes/después y permitir únicamente los cambios de seguridad/auditoría esperados. El método debe aparecer 1/1 en el artefacto del candidato resultante, conservando la suite verde.

Owner de la resolución: principal/integrador autorizado. Esta revisión no ejecutó la corrección ni pidió runtime adicional. La brecha pertenece al N5 original; no es uno de los tres extras N5-COV.

## Juicio por criterio

| Criterio | Veredicto técnico | Evidencia y límite |
| --- | --- | --- |
| N1 | APTO | Método N1 real HTTP+SQL 1/1: identidad/rol servidor, cinco identidades, listas y totales por ámbito, usuario no asignado sin acceso global. Huella de 19 tablas igual tras rechazos. Fuente `InternalAcceptanceHttpSqlTests.cs:25-86`. |
| N2 | APTO | C6 combina Cashier, Chrome, API y SQL reales: recibo, recargas y recuperación conservan una operación por venta. Browser N2×3 pasa para Cashier/Owner/Manager; permisos positivos del servidor están cubiertos por la suite SQL. Los recorridos UI de Owner/Manager usan API simulada, no un E2E real adicional. |
| N3 | APTO | N3 1/1: rechazos de comandos directos Cashier, costos y venta Inventory; respuestas sin datos prohibidos; 19 tablas iguales y controles positivos válidos. Fuente `InternalAcceptanceHttpSqlTests.cs:90-144,327-344,474-498`. |
| N4 | APTO | N4 1/1: IDs, ubicación, paginación e identidad ajenos no amplían acceso. Dos remap devuelven409; historia original y18tablas de negocio iguales, Operations+1durable sin duplicación. Esa excepción está aceptada en C7. Fuente `:148-225`. |
| N5 | PENDING | Cinco browser N5 PASS y rojo-verde-revert histórico documentado. Falta el subcaso C11-N5-01. No se exige la venta adicional completa de N5-COV para este cierre. |
| N6 | APTO | Tres browser N6 preservan intento y clave, no reenvían ni reasignan al nuevo actor/versión/ámbito y no muestran recibo anterior. SQL scope/replay conserva estado comercial. La conciliación combinada tras cambio real de sucursal no se ejecutó. Fuente `browser-mock-validation.mjs:153-183`. |
| N7 | APTO | Logout real204→401 con sesiones activas0. Expiración API 1/1 usa ticket protegido, reloj local falso, dos401 y control no expirado que alcanza el validador. Browser descarta respuestas tardías y cancela venta esperando CSRF. No se prueba una sesión browser/SQL de ocho horas ni se cambia reloj global. Fuentes `InternalSecurityTests.cs:261-322`, `browser-mock-validation.mjs:185-219`. |
| N8 | APTO | N8 1/1: CSRF ausente, incorrecto, anónimo o de otra identidad rechazado sin cambiar19tablas; par actual válido genera exactamente una venta/línea/movimiento/operación. Fuente `InternalAcceptanceHttpSqlTests.cs:229-275`. |
| N9 | APTO | N9 1/1: Cashier no cambia nada; Owner+3 conserva motivo, actor y ubicación en SQL; replay devuelve mismo ajuste sin segundo efecto. Fuente `:279-320`. |

APTO aquí es un juicio técnico limitado a las capas declaradas. No convierte todas las filas en un único ensayo operativo real.

## Ledger y recuperación comprobados directamente

[CI backend/browser 41765611859](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41765611859): backend600/600, notPassed0; N1/N3/N4/N8/N9 y expiración1/1 por método. Browser Chromium45/45, errores runtime0, solicitudes externas0. Staff45/45 es otra suite con dobles DOM; no se suma como SQL ni como browser real.

[CI combinado 41765611979](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41765611979): browser21/21 y smoke19/19, 38capturas SQL, cero oracle_failures. El dictamen C6 previo es APTO17/17; también leí sus artefactos directamente.

| Checkpoint real | POST venta acumulados | Ventas/líneas/movimientos de venta/operaciones de venta | Stock |
| --- | --- | --- | --- |
| Antes de vender | 0 | 0/0/0/0 | 30 |
| Primera venta, cantidad2; recarga | 1 | 1/1/1/1 | 28 |
| Segunda venta, respuesta200 perdida después del commit | 2 | 2/2/2/2 | 27 |
| GET recuperación; recargas; logout | 2 | 2/2/2/2 | 27 |

La clave y sale_id de la segunda venta coinciden antes y después de recuperar. El recibo vuelve visible y el control de venta queda habilitado. Los casos browser de401/403/500, recibo malformado y rechazo confirmado evitan éxito inventado y permiten o bloquean controles según el estado conocido. La pérdida de respuesta usa CDP después del commit; no prueba caída física de red o proceso.

## Vinculación y hashes

Los bindings suministrados registran head e4b79108 y checkout merge `f1a0bb1d0cd0258838f920ec8f811315820c7587`, con compare files vacío. Comparé bytes Git: seis hashes UI del browser coinciden y ocho fuentes C6 coinciden. No reconstruí la DLL registrada: es un producto del build, no un blob Git.

SHA256 calculados de los dos artefactos C6 coinciden con el sello del juez: browser `6f1eb9cb175d00c5abaaf4a01bf337363af0547e9fffacdc38e1030d22f6bb0d`; smoke `2ab7c5982f68b248fead2644c1e706abe016bbd792610a7639533fa39a1e6184`.

El backend tiene SHA256 `4afe8bcf8e774f8845cc1ecc800cea2db64fa9f6f750ebbef75815311d6a486d`. Browser simulado: `b2431b8f822d452ed3ab4c68ce659f243b33bf34e8baba5c02216894675b40d0`. Rutas completas relativas, otros hashes, métodos y checkpoints están en `evidence.json`.

No se exportan cookies, tokens, sesiones, claves operativas ni snapshots SQL crudos. Las igualdades de19tablas son aserciones del método aprobado; el artefacto saneado publica su resultado, no cada fila.

## Entrega y límites

`task_id=FIX-PR2-C11-N10-INDEPENDENT-20261104`; `status=returned`; `verdict=NEEDS WORK`.
`changed`: solo REVIEW.md y evidence.json de esta carpeta, aptos para revisión pública.
`verification`: lecturas de fuentes/JSON; hashes SHA256 y blobs Git; comparación de fuentes; sin suites ni runtime ni consultas de red nuevas.
`blockers`: C11-N5-01, evidencia faltante del subcaso original.
`unverified`: ensayo operativo completo, tres extras N5-COV, C9/backup/restore, Windows y dispositivos, producción y despliegue.
`next_action`: el principal verifica el dictamen y resuelve la regresión indicada antes de aceptar N10 completo. No se cambió ledger, Trello ni siete TONY.
`usage`: tokens, coste y tiempo no expuestos; desconocidos.
