# ADR-001: arquitectura de SAVIA v2

Fecha: 2026-11-12. Autor: arquitecto (agente primary). Mandato: Jason, 2026-11-12.
Estado: **propuesto, revisión 2**. La revisión 2 incorpora la [crítica independiente](ADR-001-critica.md) (Opus, 15 hallazgos).
Reemplaza T-1 y T-4 de [architecture-20261111](../../../docs/architecture-20261111/README.md). T-2 y T-3 siguen vigentes.

## Contexto verificado

- El repositorio ya tiene un backend que corrió: `backend/` (.NET 10, `savia_internal`, 23 tablas, un solo nodo). No tiene variantes, sucursales offline ni sincronización.
- El handoff trae un rediseño de 77 tablas pensado para offline-first. Tal como viene no instala; con 7 correcciones instala y pasa su smoke test en una sola base ([CP0](../evidence/cp0-sql-install/README.md)).
- El handoff habla de 2 sucursales y Jason pide 3. Se diseña para N y se prueba con 3.
- La crítica verificó en el motor que la versión de Change Tracking se reutiliza tras restaurar (E3) y que 12 tablas tienen filas con más de un nodo escritor (E2a, E7).

## Decisiones

### D1. Sistema de registro

El esquema nuevo (`savia/db/migrations`) es el sistema de registro de SAVIA v2.
`backend/` queda en mantenimiento: sin funciones nuevas, sin borrar nada.
No hay migración de datos todavía. Si la base del piloto tiene datos reales, se hace una migración aparte con conciliación.

### D2. Un solo camino de escritura por invariante

Los procedimientos SQL son el único escritor que **origina** cambios de stock, caja, ventas y anticipos.
El aplicador de sync solo **copia** filas cuyo dueño es otro nodo, sin recalcular. Vive en SQL: un procedimiento por tabla, generado (F4).
C# no repite reglas de negocio. Hace autenticación, autorización, validación de entrada, orquestación, sincronización, impresión y lecturas.
Toda tabla escrita por la operación tiene un procedimiento que la crea; ningún cliente ni prueba de API inserta directo (F10).
Razón: el mismo T-SQL corre igual en la sucursal (SQL Server Express) y en la nube (Azure SQL).
Descartado: reescribir las reglas en C# con EF Core. Duplicaría la lógica que ya existe y que ya pasa el smoke test.

### D3. Un host, dos modos

Un solo programa ASP.NET Core (`Savia.Api`) con `Node:Kind = Cloud | Branch`.
Los módulos son los mismos; cada modo habilita sus endpoints.
Capas: `Savia.Domain`, `Savia.Application`, `Savia.Infrastructure`, `Savia.Contracts`, `Savia.Api`.
Una prueba de arquitectura falla si una capa referencia a otra que no debe.
Descartado: dos APIs separadas. Terminarían con reglas distintas.

### D4. Offline-first

Cada sucursal corre su propio host y su propia base SQL Server en la red local.
Los clientes de la sucursal solo hablan con el host de su sucursal.
Vender, recibir mercadería y cerrar caja nunca dependen de la nube.

### D5. Sincronización por propiedad, basada en estado

**Regla de propiedad.** Ninguna fila cambia en dos nodos.
El dueño de cada tabla, o la columna de la que se deriva, está en el [mapa de propiedad](ADR-001-critica.md#mapa-de-propiedad-de-las-77-tablas), que pasa a ser anexo normativo.
Un derecho que cruza nodos (anticipo de A a B, stock reservado para la web, traslado) se modela como filas de transición inmutables, una por escritor (F2).
La base sabe qué nodo es: `sync.LocalNode`, una fila (F10).

**Mecanismo.** Change Tracking de SQL Server:

1. El emisor lee, dentro de una transacción `SNAPSHOT`, la versión actual, la versión mínima válida y las filas cambiadas desde el cursor (F5; V004 ya activa la instantánea).
2. El emisor envía solo filas cuyo dueño es él. El eco es imposible por construcción y no se usa el contexto de CT (F2).
3. El receptor aplica tabla por tabla en orden topológico, paginando por llave, en varias transacciones. El cursor avanza una vez al final (F8).
4. El cursor lo guarda el receptor como el par `(recovery_fork_guid, versión)` del emisor (F1).

Se envía el estado actual de la fila, no un incremento. Repetir, reordenar o perder la confirmación no duplica efectos.

**Recuperación.**
- Si el `recovery_fork_guid` del emisor cambió, el par entra en recuperación sin comparar versiones (F1).
- Un nodo en recuperación no canjea anticipos ni despacha transferencias. Primero vuelve a descargar de la nube **sus propias filas** y luego reabre.
- Si el cursor es menor que la versión mínima válida de una tabla (retención vencida, migración que reinicia CT), esa tabla se reinicializa con el estado completo filtrado por dueño (F6, F7).
- La retención de CT es mayor que el máximo offline aceptado, con alerta antes de vencer (F7).
- La nube también se puede restaurar: guarda el fork de cada par y vuelve a pedir lo que es de las sucursales (F15).

**Restricciones de esquema.**
- Sin `DELETE` físico ni `TRUNCATE` en tablas sincronizadas; se usa un estado `voided`. Una prueba busca `TRUNCATE` en migraciones (F6, F11).
- El saludo de sync lleva la versión de esquema; la nube acepta N-1. Migraciones aditivas primero, destructivas una versión después (F12).

El outbox queda como bitácora de eventos de negocio para webhooks, avisos y tiempo real. No transporta estado entre nodos.

**Anticipo entre sucursales** ([máquina completa](ADR-001-critica.md#máquina-de-estados-del-anticipo-con-un-escritor-por-transición)):
solicitar (B), aprobar (nube), despachar con `-monto` en A (A), recibir con `+monto` en B (B), cancelar sin despacho (nube).
Conservación: `Original = Σ disponible + Σ canjes + Σ despachos sin recepción`.
`credits.usp_CommitTransfer` actual mueve saldos de dos sucursales en un nodo; se reemplaza con prueba roja antes de usarse entre nodos.

**Stock web** ([detalle](ADR-001-critica.md#stock-web-con-un-solo-escritor)):
la sucursal es dueña del pool `web` de sus ubicaciones. La nube escribe reservas inmutables y nunca toca `StockBalances`.
Retirar stock del pool web exige una liberación previa de la nube.

Descartado: reproducir eventos con un manejador por tipo (el boceto del handoff). Los eventos no llevan los ids de filas hijas y varios procedimientos no emiten evento.
Descartado: replicación nativa de SQL Server y base compartida en tiempo real; rompen la regla de vender sin nube.
Descartado: filtro de eco por `CHANGE_TRACKING_CONTEXT`. Con dos escritores pierde cambios reales (E2a) y no envuelve `EXEC` (E2c).

### D6. El catálogo se crea en la nube

Productos, variantes, códigos y precios se escriben en el nodo nube y bajan a todas las sucursales.
Razón: dos sucursales offline no pueden crear el mismo código para dos variantes distintas.
Los procedimientos de catálogo solo se conceden a roles del nodo nube (F9).

Recepción offline con códigos desconocidos (F9):
- Las líneas con código conocido se pueden publicar y suman stock.
- Las líneas con código desconocido quedan como filas de revisión de la sucursal y no suman stock hasta que el catálogo las registre.
- El manifiesto del contenedor se registra en la nube antes del despacho, para que los códigos lleguen antes que la mercadería.

### D7. Seguridad

El personal inicia sesión contra el host de su sucursal; sus credenciales bajan desde la nube.
Un host de sucursal solo ejecuta operaciones de su propia sucursal, y **los procedimientos lo comprueban** además de C# (F3).
Mientras Martha no decida devoluciones entre sucursales, una devolución de una venta de otra sucursal se rechaza.
En la nube, cada operación se autoriza por rol y por acceso a la sucursal.
Cada nodo se identifica ante la nube con una credencial de nodo. Los secretos viven fuera del repositorio.

### D8. Clientes

| Cliente | Tecnología | Habla con | Motivo |
| --- | --- | --- | --- |
| POS de caja (Windows) | WPF, .NET 10 | Host de la sucursal | Impresión directa de etiquetas, PC viejas, pruebas sin pantalla |
| Móvil y web del personal | Expo (React Native), Android primero | Host de la sucursal | Un código para Android, iOS y web; cámara y escáner |
| Tienda pública | El sitio actual en Cloudflare | Host nube | SEO y velocidad; no se fuerza React Native |

Todos usan el contrato OpenAPI y un cliente generado. Ninguno toca SQL.
Descartado: WinUI o MAUI para caja (menos maduros para impresión y despliegue en PC viejas).
Descartado: PWA con Capacitor (T-4 anterior). El handoff pide escáner e impresora nativos y una app de escritorio.

### D9. Prueba

- Pruebas T-SQL por procedimiento, cada una en una base nueva.
- Pruebas de integración .NET contra SQL Server real, incluida concurrencia.
- Simulador con semilla: 1 nube + 3 sucursales, con fallos inyectados, incluida la semilla de restauración de F1.
- Oráculo de conservación `audit.usp_CheckConservation` (V003) más el oráculo de réplica por dueño (R1), calculado con digestos por nodo porque Azure SQL no consulta entre bases (F13, F15).
- CI corre las pruebas T-SQL también con `MSSQL_PID=Express` (F12).
- Cada bug entra como prueba roja o semilla y pasa por `bug-proof`.

## Respuesta a la crítica

| Hallazgo | Severidad | Decisión | Estado |
| --- | --- | --- | --- |
| F1 restauración reutiliza versiones | P0 | Cursor `(fork, versión)` | adoptado; prueba en el simulador pendiente |
| F2 filas con varios escritores | P0 | Filas de transición; filtro por dueño | adoptado; rediseño de anticipos y web pendiente |
| F3 devolución entre sucursales | P1 | Rechazar en el procedimiento | adoptado; ver [BUG-010](../bugs/BUG-010-devolucion-otra-sucursal.md) |
| F4 aplicador no usa procedimientos | P1 | Aplicador SQL generado, solo copia | adoptado |
| F5 instantánea apagada | P1 | Lectura en `SNAPSHOT` | resuelto por V004 |
| F6 CT se reinicia | P1 | Reinicialización por tabla; sin `TRUNCATE` | adoptado |
| F7 retención | P1 | Retención mayor que el offline máximo, alerta | adoptado; valor exacto pendiente |
| F8 atrasos grandes | P1 | Orden topológico, paginado, cursor al final | adoptado |
| F9 contenedor bloqueado | P1 | Publicación parcial; grants por nodo | adoptado; código pendiente |
| F10 tablas sin dueño o sin creador | P1 | Mapa normativo, `sync.LocalNode`, procedimientos de creación | adoptado; `CashCounts` y `ScanSessions` ya tienen procedimiento (V002) |
| F11 borrados | P2 | Sin `DELETE` físico | adoptado |
| F12 Developer vs Express | P2 | CI con Express; esquema N-1 | suite completa pasa en Express local ([evidencia](../evidence/f12-express/README.md)); CI pendiente |
| F13 oráculo | P2 | V003 y R1 | V003 hecho; R1 pendiente |
| F14 CT en Express y Azure | P2 | Probar antes de aceptar D5 | Express probado ([evidencia](../evidence/f12-express/README.md)); Azure abierto, necesita autorización de Jason |
| F15 restaurar la nube | P3 | Fork por par también en la nube | adoptado |

## Lo que no decide el arquitecto

- Jason: contratar Azure, gastar, fusionar a `main`, qué pasa con el piloto v1.
- Martha y contador: documento fiscal, política de stock negativo, devoluciones entre sucursales, rebaja de precio sin internet, permisos del personal sobre clientas.
- Sin verificar con lo real: impresora de etiquetas, escáner, pasarela de pago, Ley 787.

## Cómo se refuta

| Decisión | La refuta |
| --- | --- |
| D2 | Una regla de stock, caja o anticipo implementada también en C# |
| D4 | Una venta que espera o falla porque la nube no responde |
| D5 | Una semilla donde nube y sucursal difieren después de sincronizar, o un efecto duplicado |
| D5 | Un anticipo canjeado dos veces tras restaurar un respaldo viejo y resincronizar |
| D5 | Una fila escrita por dos nodos distintos en el simulador |
| D6 | Stock que sube por un código que el catálogo no conoce |
| D7 | Una cajera de A que cambia datos de B, por la API o llamando al procedimiento |
