# Roadmap V1 — Martha Silva Store

**Estado: primer lote técnico aprobado el 2026-10-24; R01/R04 en curso. No es aprobación de producción.** Base técnica: `a972e1148487349d975a845b0acbd07132fcdcba`. Fecha: 2026-10-24.

## Objetivo y límite

Entregar una venta completa y verificable: producto real → pedido → reserva de stock → tarjeta confirmada por servidor → actualización de inventario → gestión del pedido. Conservar la interfaz y las fotos disponibles; no reescribir el frontend ni esperar recuperar todo el catálogo.

Propuesta técnica: **ASP.NET Core + SQL Server, monolito modular**, con catálogo, inventario, pedidos, pagos y administración. Se propone por la participación del responsable técnico que recomienda este stack; versión soportada, edición, hosting y presupuesto deben acordarse en R01/R12. El Worker estático de Cloudflare no aloja este backend .NET.

**V1 piloto propuesta:** un conjunto pequeño de productos/variantes con precio, fotos, disponibilidad y condiciones aprobados; una moneda de cobro acordada con el adquirente; un proveedor de tarjeta; envío/pickup sencillo; administrador y operador; pedidos e inventario de ese canal. No sustituye un ERP completo.

**Fuera de V1 salvo dependencia real:** microservicios, multi-moneda, fidelización, campañas, reportes avanzados, transferencias entre sucursales, recuperación de todas las fotos y réplica completa de SISFAIN. Si las ventas físicas comparten el mismo stock, resolver su autoridad/sincronización es P0: no se puede posponer y prometer ausencia de sobreventa. Una alternativa de piloto es un cupo de stock online físicamente separado y aprobado por el negocio; no se asume que exista.

## Línea base comprobada

- Repositorio público y copia independiente; original Cloudflare sin cambios realizados por este trabajo.
- 9 páginas, 2 productos/6 variantes de **demo**; no son inventario real. 40 productos/120 variantes recuperados como metadatos; no activados comercialmente.
- 11 medios de la demo y 14 fotos sociales adicionales, estas últimas fuera de la tienda y sin SKU/stock verificados. No se recuperaron videos en la última entrega.
- CI de `a972e114`: Windows, Ubuntu y artefacto **PASS** en [run 40137304489](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/40137304489). CD **SKIPPED**. Pruebas de simulador/DOM no prueban backend SQL ni navegación real.
- CD de preview aislado está preparado; falta bootstrap, verificar destino y token por Worker. Acceso persistente aprobado solo para ese nuevo preview, no Admin general ni producción.
- no-mistakes: binario verificado y diagnóstico, **no puerta activa**; GitHub CLI no autenticado. Esto no bloquea construir V1 con el flujo actual de revisión/CI.
- No existe todavía backend .NET, base SQL de producción, afiliación de pagos comprobada ni fecha de lanzamiento validada.

## Material primario y pruebas que pueden refutar el diseño

Partir de código y migraciones del SHA entregado, logs completos de CI, trazas del navegador, datos comerciales aprobados y flujo observado de venta física. Para pagos: contrato/cotización/documentación y respuestas del sandbox del comercio, no la presencia de un SDK en otra tienda. Datos de clientes se anonimizan y el maestro real permanece privado; el repositorio público recibe fixtures, contratos y evidencia depurada, nunca credenciales ni exportaciones de clientes.

| Invariante / fallo prioritario | Experimento que debe poder fallar si el diseño es incorrecto | Tareas |
|---|---|---|
| No sobreventa | 20 clientes, una unidad; SQL real; exactamente una reserva y balances consistentes | R07, R13 |
| Un pedido por intento lógico | Repetir clave/solicitud y repetirla con payload distinto; verificar identidad estable o rechazo | R07, R10 |
| No confiar en navegador | Alterar precio, referencia, importe y retorno de checkout; pedido nunca se marca pagado por URL | R05, R08, R11 |
| Recuperar pagos ambiguos | Proveedor aprueba y SQL falla; evento duplicado o nunca llega; consulta/reconciliación restablece un único efecto | R10, R11, R15 |
| Pago tardío no consume stock ajeno | Expirar reserva, reasignar unidad y luego confirmar pago; excepción recuperable, nunca stock negativo | R07, R10, R16 |
| Dinero devuelto y stock son hechos distintos | Reembolso parcial/duplicado/reintentado, devolución física pendiente; importes y reposición no se duplican | R09–R11, R16 |
| Restauración útil, no solo archivo existente | Restaurar base aislada y reconciliar operaciones posteriores contra proveedor, midiendo pérdida/tiempo | R15 |

Herramientas solo cuando sean necesarias: pruebas .NET con SQL Server real (Testcontainers si el entorno lo permite, o instancia de prueba aislada); Playwright con trazas para E2E; carga acotada como k6; Git/worktrees y Actions. No sustituir SQL Server por un simulador para probar sus transacciones. Los escaneos no reemplazan pruebas de autorización/lógica. Evidencia externa: registros del proveedor, estado persistido SQL, resultados de runners limpios, restauración medida y aceptación de negocio; acuerdo entre agentes no basta.

## Reglas para acelerar sin degradar calidad

1. Resolver afiliación de tarjeta y datos comerciales en paralelo con desarrollo, desde el inicio.
2. Construir primero una operación real frontend → API → SQL. Un mock es herramienta de desarrollo, no evidencia de sandbox bancario.
3. Contrato API y esquema bajo un integrador; cada agente trabaja en su rama/worktree. No dos agentes editando la misma migración.
4. Tests desde cada tarea, no una fase de pruebas al final. Revisiones por riesgo: crítico en decisiones importantes; juez al cerrar cada lote, independiente del implementador.
5. Mantener una sola autoridad para precios/stock/pedidos. No fallback de producción a localStorage ante fallos del API.
6. No ampliar permisos ni pagar servicios por comodidad. Credenciales por canal seguro, jamás repo/chat; costos y accesos nuevos requieren aprobación correspondiente.

## Tareas priorizadas

P0 = bloquea venta real; P1 = mejora posterior. R01/R04 están **en curso**; las demás tareas siguen planificadas. Ninguna se declara terminada por aprobación del plan. Las dependencias indican cierre; contratos y pruebas pueden prepararse antes con fixtures sintéticas identificadas.

| ID | Prioridad / ola | Tarea y responsable | Depende de | Evidencia de terminado |
|---|---|---|---|---|
| R01 | P0 / 0 | Congelar V1, stack, contrato API, estados y autoridad de stock. Integrador + responsable técnico + negocio. | Aprobación del plan | ADR y contrato versionados; piloto/canal, estados y autoridad de datos definidos. Supuestos configurables de moneda, impuestos/redondeo, envío, reserva/cancelación y RPO/RTO separados de decisiones confirmadas, con dueño y gate de cierre. Las confirmaciones comerciales bloquean ventas reales, no fixtures ni base técnica. |
| R02 | P0 / 0, externa | Elegir y tramitar pasarela. Negocio decide/contrata; agente compara evidencia; técnico valida API. | Puede iniciar ya | País/entidad/cuenta y afiliación confirmados; cotización total y liquidación; documentación de integración; sandbox disponible. Contratos bancarios y credenciales productivas los gestiona el titular. No asumir Stripe ni plugin BAC de otro país. |
| R03 | P0 / 0, externa | Aprobar catálogo piloto y condiciones comerciales. Negocio + agente de catálogo. | Alcance R01 | Maestro privado CSV/JSON con SKU/variante, precio/moneda, foto del mismo producto, cupo disponible y ubicación; fuente/fecha y aprobación. Envío, contacto, privacidad y devoluciones revisados por negocio; no inventar tasas ni existencias. |
| R04 | P0 / 1 | Levantar API .NET + SQL de prueba reproducibles y ampliar CI. Agente backend; técnico revisa. | R01 | Checkout limpio arranca API y SQL con datos sintéticos; migraciones desde cero, health/readiness, configuración separada y tests .NET/SQL en CI. Licencia de desarrollo solo para entorno no productivo. |
| R05 | P0 / 1 | Catálogo y precios autoritativos en SQL. Agente backend/catalog. | R04; R03 para carga real | API devuelve variantes y disponibilidad desde SQL; validación decimal/moneda; precio manipulado por cliente se ignora; importación repetida no duplica SKU. Fixtures separadas de datos reales. |
| R06 | P0 / 1 | Identidad, sesiones y permisos reales. Agente seguridad/backend. | R01, R04 | Admin/operador con permisos mínimos; login/logout y expiración; cookies/CSRF según arquitectura; usuario no autorizado no lee/modifica pedidos ajenos ni stock; nada de autenticación simulada en modo real. |
| R07 | P0 / 2 | Corte pedido + reserva atómica + idempotencia. Agente inventario/pedidos. | R05, R06 | Una transacción crea pedido/reserva/clave; con 20 solicitudes por la última unidad solo una reserva válida y nunca saldo negativo; misma clave devuelve mismo pedido, payload distinto se rechaza; fallo SQL no deja estado parcial. Expirar/cancelar libera solo una vez; cantidades cero, negativas, fraccionarias no admitidas o superiores al límite se rechazan sin mutación. |
| R08 | P0 / 2 | Conectar frontend existente a HTTP real, incluidos precios estáticos/build. Agente frontend. | Contrato R01; cierre con R05–R07 | Catálogo, carrito y pedido consumen servidor; precio/stock no vienen de HTML antiguo ni localStorage; errores, reintentos, doble clic, Back/Forward y recarga preservan estado correcto; no fallback silencioso a demo. Confirmación persistente del pedido consultable por su comprador autorizado y número de referencia; canal externo solo si se acuerda y añade explícitamente su integración. |
| R09 | P0 / 2 | Panel mínimo de operación. Agente admin. | R06, R07 | Operador consulta y procesa transiciones autorizadas (preparación, despacho/cierre) con referencia de seguimiento si aplica; ve pedidos/excepciones nuevos en panel. Administrador ajusta stock con motivo/auditoría y registra resultado real de reembolso/conciliación del portal. Reposición física es una acción separada. Persistencia entre equipos/sesiones y pruebas negativas de roles. Sin ERP completo. |
| R10 | P0 / 2 | Núcleo de pagos y excepciones independiente del proveedor. Agente pagos. | R07 | Máquina de estados y adaptador; tests de callback duplicado/desordenado, timeout ambiguo, importe/moneda incorrectos y cancelación. Pago tardío tras expirar stock entra en excepción/conciliación, no vende stock negativo. También probar fallo entre aprobación del proveedor y commit SQL, reembolso duplicado/parcial/reintentado y tope de importe; ninguna doble reposición. Recuperación por consulta/reconciliación, no repetir cargos a ciegas. Mock claramente identificado. |
| R11 | P0 / 3 | Integrar proveedor real en sandbox. Agente pagos + técnico. | R02, R10; cierre requiere HTTPS/webhook de R12 si el proveedor lo exige | Checkout alojado/tokenizado conforme al proveedor; servidor verifica autenticidad, comercio, pedido, moneda e importe; retorno del navegador nunca confirma pago. Firma inválida y replay según protocolo se rechazan; aprobado/rechazado/cancelado/duplicado y reconciliación coinciden con registros del sandbox. PAN/CVV ausentes de aplicación/logs. |
| R12 | P0 / 1–3, externa | Hosting y staging reales para frontend/API/SQL; CD verificable. Técnico/DevOps; dueño aprueba costo/acceso. | R01; cierre con R04 y accesos | Destino independiente, TLS, SQL privado, secretos seguros y release por SHA; pruebas pasan antes de desplegar; smoke externo confirma esa versión; original intacto. Cloudflare preview es opcional, no reemplaza hosting .NET/SQL. |
| R13 | P0 / 3 | QA real de compra y rendimiento móvil/escritorio. Agente QA/UX. | R08, R09, R11, R12 | E2E en navegador real y tamaños móvil/escritorio; pérdida de red, doble clic, recarga, stock agotado y pago cancelado; cero errores bloqueantes. Hero foto, teclado/foco/contraste y sin overflow. Protocolo móvil fijado: 3 corridas, mediana LCP de laboratorio ≤2.5 s y CLS ≤0.1 como objetivos; verificar scroll en dispositivo y registrar límites. No llamar a un test DOM prueba de iPhone. |
| R14 | P0 / continua, cierre 3 | Seguridad y revisión de reglas de negocio. Agente seguridad + juez independiente. | R06–R11; cierre en R12 | Pruebas negativas de autorización/objetos, inyección/validación, CSRF según flujo, abuso/rate limits, secretos/dependencias; revisión del código de pagos/inventario y permisos de despliegue. Hallazgos críticos/altos de lanzamiento resueltos o lanzamiento bloqueado. |
| R15 | P0 / 3 | Respaldo, restauración, alertas y rollback. Técnico/DevOps. | R04, R12; modelo final R07–R11 | Restaurar backup en base aislada y medir contra RPO/RTO de R01; reconciliar pagos posteriores al punto restaurado; alerta ensayada y responsable asignado; rollback/cierre de ventas probado, sin asumir que rollback de código deshace migraciones. |
| R16 | P0 / 4 | Ensayo operativo y aceptación de negocio. Negocio + técnico; juez verifica evidencia. | R03, R09, R11, R13–R15 | Negocio procesa pedido, excepción, preparación/despacho, devolución por flujo aprobado y conciliación; políticas/moneda/envío correctos; ningún bloqueante abierto y aprobación escrita del candidato exacto. Puede usar portal del proveedor para reembolsos, con registro real y reposición separada. |
| R17 | P0 / 4, externa | Paso a producción y piloto controlado. Titular del comercio + técnico. | R16, habilitación productiva de R02 | Credenciales/dominio productivos autorizados; cargo de bajo importe y devolución cuando corresponda, autorizados específicamente; pedido/stock/confirmación consultable de R08 y aviso en panel de R09/conciliación verificados, liquidación seguida hasta evidencia real. Go/no-go y fecha aprobados; sin declarar éxito financiero mientras esté pendiente. Al aceptar formalmente la V1, verificar con el dueño el cierre del alcance y cambiar el repo a privado según su instrucción; no esperar mejoras futuras ni prometer eliminar forks/copias. |
| R18 | P1 / posterior | Expandir catálogo/ERP y mantenimiento con agentes. Integrador + técnico. | V1 aceptada R17 | Backlog separado: resto de productos, sucursales/ERP según contrato, no-mistakes y agentes por eventos con límites. CI/alertas/backups no dependen de un agente siempre vivo. |

## Orden y paralelismo

- **Ola 0 — decisiones que evitan rehacer:** R01, R02 y R03. R02 es una pista externa que no debe frenar los fixtures ni los contratos.
- **Ola 1 — base real:** R04; luego R05/R06 en ramas separadas. Preparar R08 contra contrato; empezar selección/accesos de R12 sin contratar servicios no aprobados.
- **Ola 2 — primer resultado útil:** R07 + R08 deben demostrar una compra de prueba que persiste pedido y reserva en SQL, visible en R09. R10 progresa en paralelo una vez estable el contrato de pedido. **Este es el siguiente hito, no otro despliegue de la demo local.**
- **Ola 3 — candidato integrado:** R11, R12 y cierres R13–R15. Un mock aprobado no equivale a sandbox del proveedor; un sandbox verde no equivale a producción.
- **Ola 4 — autorización comercial y piloto:** R16 → R17. Los contratos/afiliación, datos reales y accesos son dependencias humanas, no tareas que más agentes eliminan.

Ruta técnica: **R01 → R04 → R05/R06 → R07 → R08/R10 → R11 → R13–R16 → R17**. R02 y R03/R12 se conectan como dependencias externas; pueden dominar el calendario.

## Equipo y control de cambios

Hasta **6 subagentes**, no seis implementadores simultáneos sobre lo mismo: cuatro carriles de ejecución (backend/inventario; frontend/catálogo; pagos; QA/DevOps), un crítico y un juez. El integrador mantiene contratos, migraciones y main. Roles/propietarios humanos se asignan después de confirmar disponibilidad; no se inventan cuentas ni permisos.

Cada tarea: rama/worktree propio, objetivo corto, archivos bajo responsabilidad definida, prueba reproducible, commit y evidencia. El implementador no se aprueba a sí mismo; el juez revisa resultados y límites. Integrar por lotes pequeños y repetir CI del SHA entregado. Revisión humana en pagos, datos, seguridad, costos y producción. No-mistakes es opcional hasta tener host/autenticación verificados y no duplica otro publicador.

### Reparto de carriles y archivos

- **Integrador:** contrato `contracts/`, solución/proyectos compartidos, migraciones, lockfiles, `.github/workflows/`, composición de servicios y `main`. Las rutas nuevas son propuestas, no código ya existente.
- **Carril A, backend/inventario:** R04–R07, módulos propuestos `backend/Catalog`, `backend/Inventory`, `backend/Orders`, `backend/Identity` y sus tests. Solo el integrador aplica/ordena migraciones compartidas.
- **Carril B, frontend/catálogo:** R03/R08/R09 y parte de R13; `src/`, `build-inputs/static/`, tests UI. HTML/CSS no se editan a la vez por varios agentes; `dist/` se genera y no es fuente paralela.
- **Carril C, pagos:** R02 técnico/R10/R11, módulo propuesto `backend/Payments` y tests propios. No cambia tablas de Orders/Inventory sin contrato y merge del integrador.
- **Carril D, QA/DevOps:** R12–R15, pruebas E2E/carga/seguridad, `infra/` propuesto y runbooks; cambios CI/config compartidos pasan por integrador. Negocio cierra R01–R03/R16/R17, no un agente.
- **Crítico y juez:** no implementan el mismo lote que evalúan. Artefactos de revisión separados, resultado y límites ligados al SHA.

Cada ola parte del último `main` con CI verificada. Integrar contrato/base primero; luego módulos backend y auth; después consumo frontend/pagos; al final pruebas integradas y configuración. Actualizar ramas contra ese main y revisar conflictos antes de mezclar; no cherry-pick repetido de trabajos históricos. Los owners son roles, no asignaciones ficticias a cuentas humanas.

### Esfuerzo inicial y recalibración

Primer lote de planificación ejecutable R01 y preparación de R02/R03: **4–8 horas activas de ingeniería/revisión**, suponiendo que dueño y técnico pueden revisar el mismo día; no incluye esperar respuestas, contratos ni afiliación. Es una hipótesis para presupuestar, no promesa ni fecha de producción. El integrador y el responsable técnico recalibran al cerrar R01 y nuevamente tras comprobar un arranque limpio de R04, antes de comprometer el siguiente lote. Los datos/reuniones pendientes quedan separados en el registro de bloqueos; no dividir el calendario por seis agentes.

## Qué significa terminar

1. **Hito A — corte autoritativo:** R04–R09 funcionando con datos sintéticos en SQL; no vende ni confirma tarjeta real.
2. **Hito B — candidato en staging:** tarjeta de proveedor en sandbox, QA, seguridad y recuperación pasan; todavía no es lanzamiento comercial.
3. **Hito C — producción autorizada:** R16/R17 y evidencia operativa/financiera; responsable de incidentes, rollback y seguimiento. No prometer cero errores.

No se fija una fecha de producción ni un porcentaje de avance con los bloqueos actuales. Tras R01/R04 se estima el siguiente lote con evidencia; tiempos de banco, accesos y revisión del negocio van aparte y no se dividen por el número de agentes.

## Aprobación y primer lote

El propietario aprobó este alcance y la dirección .NET/SQL Server para iniciar el primer lote. El primer lote propuesto es **R01 + arranque R02/R03**, seguido de **R04 y contratos de R05–R08**. No se compran servicios, crean credenciales, envían trámites bancarios ni realizan cobros con la aprobación del plan solamente.
