# ADR-001: arquitectura de SAVIA v2

Fecha: 2026-11-12. Autor: arquitecto (agente primary). Mandato: Jason, 2026-11-12.
Estado: **propuesto**. El código de sincronización no empieza hasta que un crítico independiente lo revise.
Reemplaza T-1 y T-4 de [architecture-20261111](../../../docs/architecture-20261111/README.md). T-2 y T-3 siguen vigentes.

## Contexto verificado

- El repositorio ya tiene un backend que corrió: `backend/` (.NET 10, `savia_internal`, 23 tablas, un solo nodo). No tiene variantes, sucursales offline ni sincronización.
- El handoff trae un rediseño de 77 tablas pensado para offline-first. Tal como viene no instala; con 7 correcciones instala y pasa su smoke test en una sola base ([CP0](../evidence/cp0-sql-install/README.md)).
- El handoff habla de 2 sucursales y Jason pide 3. Se diseña para N y se prueba con 3.

## Decisiones

### D1. Sistema de registro

El esquema nuevo (`savia/db/migrations`) es el sistema de registro de SAVIA v2.
`backend/` queda en mantenimiento: sin funciones nuevas, sin borrar nada.
No hay migración de datos todavía. Si la base del piloto tiene datos reales, se hace una migración aparte con conciliación.

### D2. Un solo camino de escritura por invariante

Los procedimientos SQL son el único lugar que cambia stock, caja, ventas y anticipos.
C# no repite esas reglas. C# hace autenticación, autorización, validación de entrada, orquestación, sincronización, impresión y lecturas.
Razón: el mismo T-SQL corre igual en la sucursal (SQL Server Express) y en la nube (Azure SQL).
Descartado: reescribir las reglas en C# con EF Core. Duplicaría la lógica que ya existe y que ya pasa el smoke test.

### D3. Un host, dos modos

Un solo programa ASP.NET Core (`Savia.Api`) con `Node:Kind = Cloud | Branch`.
Los módulos son los mismos; cada modo habilita sus endpoints.
Capas: `Savia.Domain` (tipos sin dependencias), `Savia.Application` (casos de uso y puertos), `Savia.Infrastructure` (SQL, migraciones, sync), `Savia.Contracts` (DTO de la API), `Savia.Api` (host).
Una prueba de arquitectura falla si una capa referencia a otra que no debe.
Descartado: dos APIs separadas. Terminarían con reglas distintas.

### D4. Offline-first

Cada sucursal corre su propio host y su propia base SQL Server en la red local.
Los clientes de la sucursal solo hablan con el host de su sucursal.
Vender, recibir mercadería y cerrar caja nunca dependen de la nube.

### D5. Sincronización por propiedad, basada en estado

Cada fila tiene un único nodo que la escribe.
Lo que es de la sucursal sube a la nube: recepción, stock de sus ubicaciones, ventas, caja, etiquetas, cierres.
Lo que es de la nube baja a las sucursales: sucursales, personal, catálogo, proveedores, plantillas.
El mecanismo es Change Tracking de SQL Server, que existe en Express y en Azure SQL:

1. El emisor lee, en una instantánea consistente, las filas que cambiaron desde la última versión confirmada.
2. El receptor aplica las filas por llave primaria, en orden de llaves foráneas, dentro de una transacción.
3. El receptor marca lo aplicado con un contexto para que no rebote hacia el emisor.
4. El cursor lo guarda el receptor y solo avanza después de aplicar.

Se envía el estado actual de la fila, no un incremento. Por eso repetir, reordenar o perder la confirmación no duplica efectos.
Una restauración se detecta porque la versión del nodo retrocede frente al cursor guardado; el nodo entra en recuperación y no canjea anticipos hasta resincronizar.
El outbox que ya trae el esquema queda como bitácora de eventos de negocio para webhooks, avisos y tiempo real. No transporta estado entre nodos.

Los derechos que cruzan nodos (anticipo de A a B, stock apartado para la web, traslados) son máquinas de estados donde cada transición tiene un solo nodo escritor.
`credits.usp_CommitTransfer` hoy cambia los saldos de dos sucursales en un nodo; se rediseña con prueba roja antes de usarse entre nodos.

Descartado: reproducir eventos con un manejador por tipo (el boceto del handoff).
Evidencia: los eventos no llevan los ids de las filas hijas, varios procedimientos no emiten evento, y exige un manejador por evento y por destino.
Descartado: replicación nativa de SQL Server y base compartida en tiempo real; rompen la regla de vender sin nube.

### D6. El catálogo se crea en la nube

Productos, variantes, códigos y precios se escriben en el nodo nube y bajan a todas las sucursales.
Una sucursal sin internet recibe mercadería de códigos conocidos.
Un código desconocido queda en revisión y no suma stock hasta que el catálogo lo registre.
Razón: dos sucursales offline no pueden crear el mismo código para dos variantes distintas.

### D7. Seguridad

El personal inicia sesión contra el host de su sucursal; sus credenciales bajan desde la nube.
Un host de sucursal solo ejecuta operaciones de su propia sucursal.
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
- Simulador con semilla: 1 nube + 3 sucursales, con fallos inyectados.
- Oráculo de conservación: una consulta que devuelve cero filas cuando stock, caja y anticipos cuadran.
- Cada bug entra como prueba roja o semilla y pasa por `bug-proof`.

## Lo que no decide el arquitecto

- Jason: contratar Azure, gastar, fusionar a `main`, qué pasa con el piloto v1.
- Martha y contador: documento fiscal, política de stock negativo, permisos del personal sobre clientas.
- Sin verificar con lo real: impresora de etiquetas, escáner, pasarela de pago, Ley 787.

## Cómo se refuta

| Decisión | La refuta |
| --- | --- |
| D2 | Una regla de stock, caja o anticipo implementada también en C# |
| D4 | Una venta que espera o falla porque la nube no responde |
| D5 | Una semilla donde nube y sucursal difieren después de sincronizar, o un efecto duplicado |
| D5 | Un anticipo canjeado dos veces tras restaurar un respaldo viejo y resincronizar |
| D6 | Stock que sube por un código que el catálogo no conoce |
| D7 | Una cajera de A que cambia datos de B |
