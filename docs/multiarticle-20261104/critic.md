# Crítico: venta multiartículo recuperable

Dictamen: propuesta viable con condiciones de aceptación. No es entrega aceptada todavía.

Revisor: rol crítico solicitado con gpt-6.1-sol, razonamiento high. Host de fuentes: SUAZO-PC. Base leída: Tony, b17437a8e1522898a0f304f1ac87ad81f1364456. Lectura estática; no ejecuté producto, SQL, Docker ni certificados.

## Evidencia directa

- client.mjs:71–92 exige una línea y compara solamente esa línea. isId acepta UUID en mayúsculas.
- app.mjs:405–552 guarda clave, cuerpo y actorVersion en sessionStorage antes del POST. Bloquea controles mientras existe pendiente. Cambios de versión o sucursal impiden recuperación/reintento. La recarga carga selectores desde catálogo; hoy no representa visualmente un carrito pendiente.
- InternalStockLedger.cs:63–69 limita 1–100 líneas y rechaza itemId duplicados. Backend usa Guid, cuya identidad no distingue mayúsculas.
- InternalCommerceService.cs:32–75 ordena internamente por itemId, usa precios del servidor y registra una venta con todas las líneas.
- InternalCommandRunner.cs:99–116 revierte el savepoint ante rechazo y conserva el resultado rechazado.
- InternalCommerceCommandSqlTests.cs:13–58 ya contiene venta de dos artículos, replay inmutable tras cambio de precio y rechazo de segunda línea con rollback completo. Son fuentes de pruebas, no resultados ejecutados en esta revisión.
- browser_path.mjs y golden_path.py fijan actualmente una línea por venta, dos POST y cantidades/stock escalares.

## Objeciones materiales y correcciones mínimas

1. **Identidad y recibo.** Comparar cardinalidad y mapa itemId→cantidad después de normalizar UUID. Rechazar duplicados de itemId y saleLineId en recibos, incluso sin expected. Una comparación con Set sin cardinalidad permite omitir una línea y repetir otra. Aceptar permutaciones del recibo. No ordenar ni modificar el cuerpo congelado para compararlo: el fingerprint del servidor pertenece al cuerpo original.

2. **Carrito visible durante recuperación.** Tras pérdida y recarga, reconstruir las filas bloqueadas desde pending.body. No reconstruir cantidades desde valores por defecto. Si un artículo desaparece del catálogo, conservar su identidad pendiente y mostrarla; no eliminarlo silenciosamente. Un fallo de catálogo puede bloquear la operación, pero debe preservar el pendiente.

3. **Una sola operación.** Clonar completamente líneas antes de persistir. Los botones agregar/quitar, cantidades y sucursal deben quedar bloqueados durante pendiente/busy. Ningún handler ni respuesta tardía debe alterar el cuerpo ya persistido. Tras confirmación, limpiar el carrito evita reenviar accidentalmente la misma selección con clave nueva.

4. **Rechazo atómico real.** Dos líneas exitosas prueban el camino feliz. Ejecutar la prueba existente donde la segunda línea carece de stock. Afirmar cero ventas/líneas/débitos parciales y existencia idéntica por artículo; la operación rechazada durable sí puede existir.

5. **Límite de durabilidad.** sessionStorage cubre recarga de la misma pestaña. No acredita cierre de pestaña/navegador, dispositivo distinto ni recuperación productiva. Mantener este límite en la documentación.

## Pruebas adversariales mínimas

- Cliente: 0/100/101 líneas; cantidad 0, fraccionaria y límite; duplicado por UUID con distinta capitalización; ningún POST inválido.
- Recibo: dos cantidades distintas y precios distintos; orden invertido válido; línea ausente/extra, duplicada, cantidad intercambiada o total incorrecto inválidos.
- UI: agregar dos, editar una, quitar y volver a agregar; doble submit emite un POST. Verificar cuerpo completo antes del transporte.
- Recuperación: perder HTTP 200 después del commit; recargar; comprobar mismo cuerpo/clave, dos filas bloqueadas y GET original; repetir recuperación sin nuevas ventas.
- Seguridad: actorVersion/sucursal distintos, 401, pendiente corrupto y fallo de almacenamiento conservan bloqueo y no emiten POST.
- SQL: por cada venta, dos SaleLines y dos movimientos exactos; balances por itemId. Mantener el artículo tercero intacto.
- Reusar rollback/replay existentes y conservar las regresiones N5/C7/C8. No duplicar escenarios equivalentes.

## Comandos, límites y siguiente acción

Leí fuentes mediante Get-Content y rg; verifiqué git status --short y git rev-parse HEAD. No existían .codegraph ni graphify-out/graph.json. Dos rutas supuestas no existían; la búsqueda de archivos ubicó InternalCommandRunner.cs e InternalCommerceCommandSqlTests.cs. No hay bloqueo pendiente de localización.

Pendiente: implementación, ejecución y evidencia antes/después del flujo en navegador real. Owner: primary. Siguiente acción: incorporar estas condiciones y ejecutar la evidencia permitida. Cierre: hashes del candidato, resultados frescos y readback SQL por artículo. C2/C9/C10 y pagos not_processed conservan sus límites.

