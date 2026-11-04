# SISFAIN → SAVIA: migración, operación y QA

Modo `DISCOVER`. Task `SISFAIN-MIG-QA-20261104`.
Host `SUAZO-PC`. Modelo autorizado `gpt-6.1-sol`, razonamiento `high`.
Checkout observado: `C:/Users/Jason/MARTHA-SILVA/github`, rama `Tony`, HEAD `82402c74f36b6e983e058b8710ca55c0882f40d6`.
La inspección terminó con ese mismo HEAD.
El checkout fue solo lectura. No se ejecutaron pruebas, builds, SQL, Docker ni conexiones del piloto.

**Resultado:** SAVIA tiene un núcleo transaccional útil, pero la evidencia disponible no acepta el reemplazo completo de SISFAIN.
La brecha inmediata es venta multirenglón en la interfaz.
La brecha de sustitución incluye caja, saldos, migración verificable y recuperación operativa.
Recomiendo aprobar primero un contrato de equivalencia operativa, con ejemplos sintéticos y criterios por flujo.
No recomiendo cortar el servicio actual sobre la base de CI verde.

Las rutas siguientes son relativas al checkout indicado.
`E` significa el artefacto histórico `docs/c11-next-20261104/ci-53dd23b5/savia/savia-backend-outcomes-41774927960-1/sanitized-results.json`.
`B` significa `docs/c11-next-20261104/ci-53dd23b5/root-ci-binding.json`.
Los identificadores completos y las fuentes públicas están en `sources.json`.

## Verificado: matriz de capacidad y evidencia

| Flujo | Implementado, por lectura directa | Evidencia histórica revisada | Pendiente para sustitución |
| --- | --- | --- | --- |
| Factura con varios artículos | API acepta 1..100 líneas de artículos distintos. Calcula precio y total desde servidor. `InternalStockLedger.cs:63-69`; `InternalCommerceService.cs:32-69`, dentro de `backend/src/Martha.Store.Api/Internal/Commerce/`. | Prueba SQL con dos artículos: total 1075; stock final 8 y 7; replay conserva recibo tras cambio de precio. `InternalCommerceCommandSqlTests.cs:13-32`; E:173-175. | UI construye una línea y cliente rechaza más de una. `dev/savia-staff-ui/app.mjs:544-549`; `client.mjs:71-91`. Falta carrito y prueba browser→HTTP→SQL de varios artículos. El recibo actual no demuestra factura fiscal. |
| Stock cero y atomicidad | El ledger impide `OnHand < Reserved` y negativos; un saldo nuevo comienza en cero. `InternalStockLedger.cs:25-41`. | Segunda línea sin stock revierte la primera; venta posterior puede dejar ambos saldos en cero. `InternalCommerceCommandSqlTests.cs:36-57`; E:165-167. Dos consumidores compiten por una unidad: solo uno gana. `InternalCommerceSqlTests.cs:76-85`; E:181-183. | La entrega de prenda física existente con registro 0 ya está decidida; falta aceptar el mecanismo de conciliación. No habilitar negativos silenciosamente. Probar cero, saldo inexistente, reservas y simultaneidad a través de UI. |
| Anulación y devolución | API exige Manager/Owner y CSRF. Reposición y crédito contable interno; devolución parcial y total. `InternalCommerceEndpoints.cs:27-32`; `InternalCommerceService.cs:73-136`. | Idempotencia, límites de devolución y carrera cancelación/devolución tienen resultados históricos PASS. Pruebas: `InternalCommerceCommandSqlTests.cs:61-165`; E:145-175. | No procesa devolución de dinero: `BankRefundStatus=not_processed`, servicio:205-207. Falta validar la operación de caja asociada y sus permisos. |
| Cobros, caja, crédito y saldos | El recibo de venta fija `PaymentStatus=not_processed`. `InternalCommerceService.cs:202-207`. El contexto configura Directory, Commerce, Supply, Security y Branches. `InternalDbContext.cs:7-11`. | No se identificó evidencia de caja, pagos mixtos, cuentas corrientes o vencimientos en los modelos/endpoints inspeccionados. | Diseñar apertura/cierre/arqueo, cobros, cargos/abonos, pagos parciales y mixtos, saldos por documento y moneda. Un `RecordedCreditMinor` de reversión no demuestra una cuenta corriente. |
| Compras y recepción | Órdenes y recepción están separadas; inventario aumenta al recibir. `Supply/InternalSupplyService.cs:86-162`; `InternalSupplyEndpoints.cs:19-34`. | La suite histórica cubre backend completo; no se volvió a ejecutar. | Conciliar órdenes abiertas, recepciones parciales y deuda a proveedor por separado. Compras no equivale a pagos a proveedor. |
| Clientes y artículos | Modelos de artículo: SKU, nombre, precio, moneda, activo. Cliente/proveedor: tipo, nombre, email, teléfono, activo. `Directory/InternalDirectoryModels.cs:6-32`. | Existe suite Directory en el artefacto histórico completo. | Confirmar campos reales: variantes, código de barras, costos, impuestos, unidades, crédito e identificación fiscal. No suponer que esos datos caben en el modelo actual. |
| Permisos y auditoría | Roles por comando y alcance de sucursal. `InternalCommandRunner.cs:22-37`; endpoints Commerce:10-32. Operaciones/movimientos/reversiones append-only por EF. `InternalDbContext.cs:23-33`. | C11 registra denegaciones HTTP+SQL; E y B las vinculan al candidato histórico. | Revisar privilegios efectivos Windows/SQL, cuentas individuales, operación por turno y acceso al respaldo. La guarda EF no prueba protección contra un administrador SQL. |
| Backup y restore | Prueba de migraciones reales, CHECKSUM, VERIFYONLY y restore a otra base. `PrivatePilotReleaseTests.cs:107-144`. | El fixture contiene Branch, Item, Location, Stock y Staff; sus cuatro filas de negocio verificadas no incluyen venta/cobro. | C9 Windows bloqueado por TLS. Faltan restore con ventas/oráculos, RTO/RPO y pérdida del último Owner. `docs/PROJECT-STATUS.md:25-32`. |

Todos los archivos C# de pruebas citados están en `backend/tests/Martha.Store.Api.Tests/`.
La suite histórica registra 601/601 y cero no aprobadas, E:1-7.
Corresponde al candidato `53dd23b5cfec2cb5dd717395b9095a71d29669f0`, B:3 y B:145-149.
No es una ejecución fresca sobre HEAD `82402c74…`.

El proveedor [CGA describe SISFAIN Pro 4.0](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/) con pagos mixtos, bodegas, caja, proformas, crédito, reportes y permisos.
Son afirmaciones del proveedor, no una auditoría de la instalación que usa Martha Silva.
Faltan versión instalada, módulos contratados, documentos de ejemplo y exportación autorizada.

## Propuesto: migración con corte y reconciliación

1. **Contrato de reemplazo.** Martha describe un día completo y un cierre mensual mediante ejemplos anonimizados o sintéticos. Jason aprueba qué comportamientos debe conservar SAVIA. Incluir venta multirenglón, crédito, abonos, descuentos autorizados, devoluciones, compras, reportes y documentos emitidos. Clasificar cada comportamiento como obligatorio, sustitución aceptada o exclusión explícita.
2. **Inventario de datos.** Obtener una exportación autorizada y documentada, sin asumir API SISFAIN. Congelar diccionario, identificadores externos, fechas, monedas, unidades y reglas de redondeo. Clasificar catálogo, existencias por bodega, documentos, movimientos, caja, CxC, CxP y pendientes. Conservar origen y hashes privadamente.
3. **Mapeo y ensayo sintético.** Diseñar staging sin escribir tablas operativas hasta validar. Registrar `source_system`, `source_id`, lote y hash. Repetir un lote debe producir cero duplicados. Rechazar huérfanos, SKU duplicado, moneda desconocida y valores fuera de rango. Los módulos financieros e importador faltantes requieren diseño y autorización propia.
4. **Reconciliación independiente.** Comparar cantidades y valores por identificador, no solo totales globales. Exigir equivalencia por artículo/bodega, cliente/documento/moneda, proveedor/documento/moneda y caja/medio de pago. Explicar cada diferencia y aprobar cada transformación. No compensar un faltante con un sobrante distinto.
5. **Historia y apertura.** No volver a registrar ventas históricas como ventas nuevas si las existencias iniciales ya incluyen su efecto. Separar archivo histórico consultable, documentos abiertos y movimientos de apertura trazables. Las órdenes parcialmente recibidas deben conservar su pendiente sin duplicar inventario. Elegir el tratamiento de numeración e impuestos antes del corte.
6. **Ensayo de jornada.** Una base sintética debe reproducir apertura, venta de varios artículos, cobro, crédito, abono, devolución, recepción y cierre. Un verificador separado consulta stock, documentos, caja y saldos. Añadir reinicio, pérdida de respuesta después de commit, red interrumpida, impresión fallida y reconexión. Cada paso conserva sus identificadores y resultado esperado.
7. **Corte aprobado.** Fijar hora, responsable, ventana de indisponibilidad, respaldo verificado y procedimiento de vuelta. Congelar escrituras en SISFAIN; exportar delta final y contar pendientes. Importar en destino independiente, reconciliar y aceptar antes de habilitar escrituras SAVIA. Mantener un solo sistema autoritativo para ventas durante el cambio.
8. **Vigilancia inicial.** Conciliar cada cierre de caja y los primeros cierres diarios. Conservar SISFAIN en consulta conforme al acuerdo y protección de datos aplicables. Retirar el servicio solo después de la aceptación del reemplazo y de la recuperación probada.

**Criterios de aceptación propuestos:** cero documentos duplicados, cero diferencias sin explicar, correspondencia completa de claves, conservación exacta de cantidades e importes por moneda y evidencia de permisos.
Esto define checks concretos; no promete cero defectos.
Los objetivos RTO/RPO y la ventana de reversión requieren decisión del negocio.

### Rollback sin perder ventas posteriores

Antes de habilitar escrituras SAVIA, una reconciliación fallida conserva SISFAIN como autoridad y descarta el destino solo bajo permiso específico.
Después de aceptar ventas SAVIA, restaurar solamente el respaldo anterior perdería operaciones nuevas.
La vuelta exige congelar SAVIA, capturar el diario posterior al corte y reconciliarlo contra documentos y cobros.
Un operador autorizado aplica un procedimiento revisado de traslado/replay con identificadores originales y deduplicación.
Debe contar documentos, unidades, saldos e importes antes de reabrir SISFAIN.
Si ese procedimiento no existe o no pasa el ensayo, no se autoriza el corte.
No usar `Down` de EF como recuperación: la prueba destruye explícitamente el fixture, `PrivatePilotReleaseTests.cs:116-125`.

## Propuesto: CI verificable y uso de no-mistakes

La base actual ya separa jsdom, browser con API simulada, backend SQL y golden path real.
Fuentes: `.github/workflows/savia.yml:20-150`; `golden-path.yml:1-40`.
Conservar esa separación y los oráculos SQL independientes.

1. **Contrato de casos obligatorio.** `verify_full_suite.py:20-52` rechaza duplicados y exige todos los casos presentes PASS. Sin embargo, su aprobación es `len(cases) >= minimum`. El mínimo 601 no demuestra que sigan presentes todos los casos críticos anteriores. Añadir un manifiesto revisado por identidad/subcaso y detectar eliminaciones o sustituciones.
2. **Gate agregado requerido.** Evaluar explícitamente resultados de cada suite obligatoria. Fallar ante `skipped`, cancelación, artefacto ausente, SHA incorrecto o evidencia inválida. Las exclusiones de fork se mantienen; un fork necesita validación confiable antes de aceptación. GitHub documenta que un [job omitido puede aparecer exitoso y no impedir merge](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-jobs-with-conditions).
3. **Vinculación exacta.** Publicar commit candidato, merge SHA/tree si aplica, run ID/attempt, versiones, hash del manifiesto de pruebas y hashes de artefactos saneados. Verificar readback de checks sobre ese SHA. Separar la evidencia sintética del ensayo Windows y del negocio.
4. **Pruebas independientes y fallos inyectados.** El implementador no debe definir el único oráculo. Probar segunda línea sin stock, última unidad concurrente, replay distinto, devolución excesiva, fallo después de commit, revocación de sesión y lote importado dos veces. Para caja: cobrar y devolver parcialmente con cierre exacto por medio de pago. Añadir ensayos de mutaciones controladas que retiren un guard de stock, dupliquen un abono o alteren redondeo; la suite debe detectar cada cambio.
5. **Rama protegida.** Proponer PR obligatorio, revisión independiente, descarte de aprobaciones obsoletas, checks de nombres únicos con origen esperado y prohibición de bypass/force push según permisos del repositorio. [GitHub documenta estas opciones](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches). La configuración remota vigente no fue consultada; no afirmo que falte ni que esté activa.
6. **no-mistakes como orquestación opcional.** `docs/NO-MISTAKES.md:1-8` y `docs/no-mistakes.example.yaml:1-16` mantienen un ejemplo inerte. Puede ordenar revisión, pruebas y reparación bajo alcance explícito; no prueba equivalencia comercial. No activarlo durante esta investigación. Antes de una futura activación, revisar versión efectiva, permisos, límite de reparaciones y publicación única. Retener cada fallo y exigir aprobación humana del resultado final.

## Bloqueos, dueños y cierre esperado

| Bloqueo y evidencia | Causa o hipótesis | Corrección realizada aquí | Próximo actor / cierre |
| --- | --- | --- | --- |
| No hay exportación ni contrato de equivalencia de la instalación actual. | Falta información de origen autorizada. | Matriz y datos requeridos definidos; ningún acceso real. | Martha/Jason: aportar ejemplos y aprobar contrato. Cierra con mapeo y ensayo representativo. |
| C9: `The certificate chain was issued by an authority that is not trusted.` Preflight:1 Open, 0 consultas, 88 ms; `PREFLIGHT-RESULT.md:14-31`. | Cadena no confiable; certificado/CA exactos desconocidos. | Ningún cambio de seguridad ni reintento; se conserva bloqueo. | Coordinador existente: recibir el inspector OS revisado y ejecutar solo el alcance vigente; corrección de seguridad y nuevo SQL son separados. Cierra con TLS validado y posterior ensayo autorizado. |
| Último Owner perdido. | Bootstrap cierra si existe cualquier Staff, `InternalSecurityService.cs:185-191`. | Se documenta límite; no hay bypass ni reset. | Jason: aprobar un procedimiento nuevo o aceptar límite explícito. Debe ensayarse antes del corte. |
| Caja/saldos/migración y UI multirenglón no aceptados. | Modelos y flujo actual no cubren el reemplazo completo. | Investigación y checks propuestos; cero implementación. | Primary: convertir brechas confirmadas en entregas acotadas. Cierra cada entrega con flujo real y oráculos. |

Lección aplicada: conservar la prueba SQL multirenglón no convierte una interfaz monorrenglón en reemplazo operativo.
La corrección propuesta exige aceptación por flujo completo, sin reutilizar CI histórico como ejecución nueva.


Nota de exportación del primary: se corrigieron dos recomendaciones de estado al contrastar D-022 y Trello C9 el 4-nov. La entrega con prenda física existente ya está decidida; la inspección OS está en etapa de entrega, no a la espera de volver a pedir la misma decisión. El original del agente se conserva fuera del checkout.
