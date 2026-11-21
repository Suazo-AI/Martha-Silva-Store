# SAVIA — Handoff de implementación: 1 contrato API, 3 clientes, 2 sucursales offline

**Estado del handoff:** instrucciones de ejecución para un agente de ingeniería; NO certifica código construido, SQL instalado ni despliegue.  
**Fecha:** 2026-11-12  
**Idioma de trabajo:** español. Código y contratos según estándares del equipo.

## Mandato

Actúa como principal engineer responsable de implementar SAVIA, un POS/inventario/e-commerce de ropa con **dos sucursales** y operación **offline-first**. El usuario ha aportado el esquema SQL original (23 tablas) y un rediseño greenfield generado (77 tablas, 15 esquemas, 41 procedimientos reportados). **No aceptes ninguno como listo para producción sin ejecución y revisión real.**

El objetivo es entregar **tres clientes funcionales sobre una sola lógica de negocio**:

1. **Web**: e-commerce y, según adecuación técnica, backoffice web; proyecto Expo/React Native Web o web React si la evidencia lo favorece.
2. **Móvil**: recepción por escáner, consulta/operación de inventario; React Native/Expo, compartiendo componentes y contratos viables con web.
3. **Desktop Windows**: POS, caja, arqueo, etiquetas e integración con periféricos; C# WPF (o WinUI/MAUI si el análisis y la prueba de hardware justifican cambiarlo).

La implementación central preferida es **ASP.NET Core .NET 10 LTS**, monolito modular con límites Clean Architecture donde aporten claridad, **Azure Container Apps** y **Azure SQL Database** administrado, **Azure Blob Storage** para imágenes. **Sin Redis, AKS ni broker por defecto**; incorporar solo con evidencia de necesidad.

Para desarrollo y pruebas utilizar **SQL Server 2022 en Docker** con volumen persistente. **No confundir SQL Server en contenedor con Azure SQL Database (PaaS)**. No desplegar recursos cobrables en Azure sin autorización expresa.

### Invariante arquitectónica que no puedes romper

Cada sucursal debe continuar facturando e inventariando si falla Internet. Para ello existe un **servicio de aplicación local + DB local transaccional** accesible por LAN. El backend central y el local **comparten los módulos y reglas** que sea seguro compartir, aunque tienen dependencias, permisos y operaciones diferentes. Solo la nube sincroniza entre sucursales y atiende la tienda online. El acceso a una base local no debe depender del navegador ni de Azure para ventas offline.

Define si se reutiliza el mismo host API parametrizado por `Cloud`/`Branch` o si hay dos hosts mínimos que referencian la misma Application/Domain. **No implementes dos códigos de negocio divergentes.** Los clientes deben usar OpenAPI/contratos versionados y clientes generados; no acceder directamente a SQL.

## Material primario que debes abrir primero

- `db/Texto pegado.txt`: migraciones SQL históricas de `savia_internal` (23 tablas).
- `db/SAVIA_DB_SQLServer2022_COMPLETA.sql`: nuevo instalador local, ~197 KB.
- `db/SAVIA_DB_AzureSQL_Instalar_En_BD_Existente.sql`: versión propuesta para Azure SQL.
- `db/SAVIA_DB_Verificar_Instalacion.sql` y `db/SAVIA_DB_Prueba_Smoke_Rollback.sql`: pruebas propuestas, **no ejecutadas** en el ambiente de origen.
- `db/SAVIA_DB_GUIA_INSTALACION.md`: reglas del diseño, excepciones y restricciones conocidas.
- El repositorio real, si está montado: inspecciona `AGENTS.md`, `README`, solución .NET, tests, paquetes, lockfiles y migraciones antes de crear algo.

Nota: el paquete nuevo es un diseño greenfield; **no es una migración sobre datos reales de la BD vieja**. Si la BD ya tiene información real, inventaría y define migración no destructiva con conciliación antes de cambiarla.

## Cuatro controles profesionales previos a generar pantallas

1. **Auditoría ejecutable del SQL:** levantar SQL Server real, instalar una base vacía, validar compatibilidad de scripts, objetos, roles, procedimientos, claves, índices, bloqueos y transacciones; corregir lo que falle. No basta el conteo de objetos ni revisión estática.
2. **Mapa de invariantes y ownership:** quién puede escribir ventas, saldo de anticipos, stock y pagos; dónde se hace la confirmación en sucursal y en nube; qué se replica y qué no; cómo se recuperan fallos.
3. **Prueba vertical end-to-end:** escanear código proveedor → reconocer variante → recibir N unidades sin duplicar SKU → imprimir etiqueta (mock/verificada) → vender offline → realizar arqueo → reconectar → sincronizar sin duplicar efectos.
4. **Prueba independiente de recuperación:** desconectar A y B, forzar reintentos, perder ACK, restaurar BD local vieja y reproducir canjes concurrentes. La prueba FALLA si hay doble canje, inventario negativo indebido, pérdida o duplicación de ventas.

## Estructura de monorepo orientativa (puedes mejorarla)

```text
savia/
  apps/
    api-cloud/          # Host ASP.NET Core cloud
    api-branch/         # Servicio LAN y worker local .NET
    universal/          # Expo/React Native: móvil + web donde convenga
    desktop-windows/    # WPF / WinUI, C#
  src/
    Savia.Domain/
    Savia.Application/
    Savia.Infrastructure/
    Savia.Contracts/
    Savia.Sync/
  db/
    migrations/
    scripts/
    tests/
  infra/
    docker-compose.dev.yml
    azure/              # IaC preparada, NO aplicar sin permiso
  tests/
    unit/
    integration/
    e2e/
    offline-chaos/
  docs/
    adr/
    business-rules/
    evidence/
  skills/
    savia-engineering/SKILL.md
    savia-engineering/files/INDEX.md
    savia-engineering/examples/
    savia-engineering/notes.md
```

Este árbol es una **propuesta**, no obligación de generar directorios vacíos. Reducirlo si mejora la mantenibilidad. Usar Clean Architecture pragmática, no crear 77 repositorios/clases solo por 77 tablas.

## Reglas de negocio obligatorias

- **Catálogo:** `Products` agrupa `Items` variantes (talla/color). Misma prenda/variante comparte código proveedor. Un SKU/identificador no puede apuntar a dos variantes indistinguibles. Preservar ceros a la izquierda. Soportar ~50k productos, escenario de 250k variantes.
- **Recepción:** contenedores importados; escaneo USB/Bluetooth, reconocimiento automático, desconocidos en staging, suma de cantidades por variante, confirmación atómica de stock. Nunca aumentar stock por simple lectura no aprobada.
- **Etiquetas:** colocar **SKU original escaneado + nombre de tienda + barcode legible**. Cola persistente, reintentos y control de reimpresión. Validar impresora real antes de afirmar integración.
- **Inventario:** por sucursal/ubicación, cantidades y reservas diferenciadas para e-commerce. Movimientos auditables no destructivos, ajuste/versionado de catálogo, stock web previamente asignado para no vender dos veces mientras una sucursal esté desconectada.
- **POS:** venta+líneas+pagos+stock+outbox en transacción local; cierre diario y arqueo de caja, diferencias. Documento contable se envía al contador **sin emitir segunda factura fiscal** salvo aprobación de requisito fiscal real.
- **Devoluciones:** origina anticipo/saldo cliente, canje parcial y total. Transferencia A→B solo tras autorización y bloqueo **persistente en A**; B dispone saldo offline únicamente tras recepción durable del derecho; reintentos no duplican crédito. Evitar saldos negativos.
- **Sincronización:** outbox/inbox idempotente, push/pull incremental por nodo, cursor duradero, eventos ordenados por agregado, reconciliación y auditoría, sin base de datos compartida en tiempo real entre sucursales.
- **E-commerce:** consume API central, pagos verificados del lado servidor, reserva stock online, carrito/pedido/control de cancelaciones. No acceder a la base local desde Internet.
- **Seguridad:** identidades dispositivo/sucursal, RBAC, secretos fuera de repo, auditoría, backups verificables, autorización por recurso; excepciones de stock y finanzas con aprobación.

## Prioridades de ejecución (autonomía técnica)

**Fase 0 — inspeccionar y probar**: revisar artefactos, compilar SQL en una instancia de prueba si hay Docker/SQL Server; documentar resultados y riesgos. Crear ADRs solo para decisiones materiales. Si falta ejecución local, no afirmar PASS.

**Fase 1 — contrato y backend**: un primer slice útil sobre ASP.NET Core y OpenAPI. Evitar dos APIs con lógica divergente. Crear tests para endpoints/producto/stock/recepción con DB real y transacciones. Validar cuándo usar EF Core vs stored procedures existentes; no duplicar la misma lógica transaccional en dos capas.

**Fase 2 — LAN offline y sync**: servicio local durable, Sync worker, diferencias de responsabilidad cloud/branch, fallos y recuperación. Incluye dos sucursales simuladas y Azure central sustituido por entorno local controlado para tests.

**Fase 3 — clientes incrementales**: **primero** construir el flujo funcional de escaneo/recepción/POS en el cliente adecuado y lograrlo contra API local; después web/móvil/escritorio con contratos generados. Reutilizar componentes RN para móvil+web cuando sea viable; NO forzar React Native para el e-commerce público si se perjudica SEO/performance. Desktop Windows puede usar WPF y drivers/spooler locales.

**Fase 4 — caja, anticipos, etiquetas, e-commerce**: cerrar cada workflow con prueba automatizada y auditoría. El cierre contable/fiscal, marca y periféricos requieren verificación de condiciones reales.

**Fase 5 — hardening y aprobación**: load test con 50k/250k y 1M movimientos; permisos, backups/restores, observabilidad, pruebas de recuperación. Preparar IaC de Azure y estimación de costos, **no desplegar sin aprobación**.

## Criterios de aceptación y pruebas independientes

| Aserción | Condición de aprobación | Contraejemplo que la invalida |
|---|---|---|
| SQL instalable | Script ejecutado de cero, sin errores, consultas y SP funcionan | Un procedimiento no compila o deja invariantes rotas |
| Escaneo | 100 lecturas del mismo barcode incrementan en 100 el detalle de recepción, no generan 100 SKUs | Duplicado o stock posteado antes de confirmar |
| Venta offline | Caja realiza venta sin Internet con DB local y outbox durable | Timeout por Azure o venta sin registro de sincronización |
| Sync idempotente | Reintento de evento ya procesado no repite efectos | Doble stock/venta por pérdida de ACK |
| Anticipos | Monto transferido no queda gastable en origen y destino simultáneamente | Doble canje bajo corte de red o rollback |
| Caja y contabilidad | Arqueo y documento contabilizan una sola vez | Segunda factura fiscal o ingreso duplicado |
| Etiquetas | Spool refleja SKU original y tienda; reintentos sin impresiones silenciosamente perdidas | SKU alterado o job descartado sin aviso |
| Privilegios | Cajero de A no modifica datos restringidos de B | Acceso indebido cross-branch |
| Recuperación | Restaurar copia antigua no reintroduce derechos gastados | Saldo antiguo se reactiva y canjea |
| Rendimiento | p95 y recursos medidos con escenario realista | Solo afirmaciones teóricas de escalabilidad |

## Protocolo de trabajo y permisos

Antes de tocar archivos lee las instrucciones existentes del repo; no pidas al usuario decisiones de bajo riesgo que puedas resolver con evidencia. Implementa cambios reversibles en rama de trabajo. Antes de publicar, gastar, crear recursos Azure cobrables, borrar/migrar datos reales, fusionar a rama protegida o decidir aspecto final de marca, solicita aprobación.

Organiza instrucciones repetibles en una habilidad canónica `SKILL.md` y herramientas/referencias en `files/INDEX.md`; ejemplos solo aprobados en `examples/` y correcciones fechadas en `notes.md`. No simules subagentes ni auditorías. Cada prueba debe poder FALLAR y tiene que ejecutarse antes de anunciar éxito.

No prometas finalizar un sistema de múltiples clientes si el entorno carece de SDKs, impresoras o credenciales; ejecuta todo lo que sí sea verificable y comunica bloqueos reales. No añadas infraestructura costosa como Redis, Kubernetes o colas externas sin necesidad medida.

## Tu primera salida y acción

1. Resumen ejecutivo del estado real, diferencias respecto al audio y hallazgos del SQL.
2. ADR con arquitectura elegida y alternativa descartada, incluida decisión universal Expo/web vs React puro, WPF vs otra UI Windows, DB local y hosts cloud/branch.
3. Checklist con comandos reproducibles para levantar SQL Server 2022 en Docker, cargar scripts y ejecutar pruebas.
4. **Ejecución real** del primer checkpoint que permita el entorno: levantar DB y probarla; si no hay Docker, emitir comandos y log de bloqueo, no inventar éxito.
5. Primer slice verificable y pruebas; después continuar de forma autónoma las fases aprobadas.
6. Reportar siempre `STATUS / DONE / NEXT / BLOCKER / EVIDENCE` con rutas, commits y salida de comandos reales.

**No confundir plan escrito con software ejecutado. La medida de éxito es dos sucursales que operan offline y vuelven a sincronizar sin perder inventario ni dinero.**

## Fuentes oficiales consultables

- SQL Server 2022 Docker: https://learn.microsoft.com/en-us/sql/linux/quickstart-install-connect-docker
- Azure SQL Database PaaS: https://learn.microsoft.com/en-us/azure/azure-sql/database/sql-database-paas-overview
- Expo para web: https://docs.expo.dev/workflow/web/
- Expo Router universal: https://docs.expo.dev/router/introduction/
- WPF Windows: https://learn.microsoft.com/en-us/dotnet/desktop-wpf/overview/index
- Ciclo soporte .NET: https://learn.microsoft.com/en-us/dotnet/core/releases-and-support
- Azure SQL serverless: https://learn.microsoft.com/en-us/azure/azure-sql/database/serverless-tier-overview
