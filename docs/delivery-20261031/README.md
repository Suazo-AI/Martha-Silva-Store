# Martha Silva: terminar una V1 verificable

> Corte histórico del 31 de octubre. Continuación al 2026-11-03: [AGENT-START](../AGENT-START.md),
> [validación reciente](../testing-20261103/README.md) y [estado vigente](../PROJECT-STATUS.md).
> Conservar el diagnóstico; no repetir pasos consumidos ni interpretar sus pendientes como hechos actuales.


**Siguiente incremento: Venta segura por cajero.** Demostrar permisos, sesión y aislamiento sobre la venta existente reduce cuatro brechas operativas. Añadir pantallas ahora no demuestra que el personal pueda operar correctamente.

Fecha: 31 de octubre de 2026, America/Managua. Inspección terminada durante el 1 de noviembre UTC. Modo DISCOVER. Host SUAZO-PC; orquestador Codex y revisión independiente con `gpt-6-astra`, razonamiento `high`.

[Informe visual](index.html) · [Incremento ejecutable](NEXT-INCREMENT.md) · [Playbook](PLAYBOOK.md) · [Toolkit](TOOLKIT.md) · [Fuentes](SOURCES.md) · [Verificación de esta entrega](VERIFICATION.md).

## Qué haría un profesional antes de ampliar el proyecto

1. Congelaría el alcance de una entrega útil y reconstruiría su camino crítico desde el trabajo de la persona que vende.
2. Partiría del código, peticiones/respuestas, movimientos persistidos, sesiones y fallos originales. Los resúmenes y las skills serían índices, no pruebas.
3. Aplicaría trazabilidad requisito → pantalla → API → regla → escritura → evidencia, pruebas adversarias de permisos y ciclos de reproducción → corrección mínima → regresión.
4. Exigiría resultados observables fuera de nuestra opinión: rechazos HTTP sin efectos, saldos reconciliados, recibos únicos, recuperación comprobada y una tarea completada por el operador.

No contamos con una sesión observada de Martha realizando su jornada completa. La venta sintética Owner demuestra una parte del sistema; no demuestra adopción, utilidad comercial ni aceptación de Martha.

## Diagnóstico actual

La base Git observada es `98c9014c79501977519b84f959049b62940b69a3`, rama `Tony`. El árbol contiene cambios previos sin commit. Los hashes de archivos inspeccionados quedan en [evidence.json](evidence.json); el SHA base solo no representa ese árbol.

La fuente actual registra **13/22 criterios PASS y 9 NOT RUN**, con **5/5 del subconjunto de interfaz crítica**. Son criterios, no un porcentaje de producto terminado. No ejecutamos nuevamente SAVIA para este diagnóstico.

La evidencia conservada incluye venta desde el formulario, precio del servidor, movimiento único, replay, abastecimiento, reversión, restauración y persistencia tras reiniciar solo el API. También incluye recuperación del cuerpo de respuesta retenido después del commit. Eso no simula una caída completa de red.

La matriz conserva 42/42 pruebas JavaScript con dobles y 512/512 casos internos, incluidos 46/46 SQL. Son resultados de sus candidatos y condiciones registrados. No recertifican los cambios locales posteriores ni equivalen a aceptación de producción.

### Alcance que gobierna esta recomendación

`docs/SAVIA-LATEST.md` fija una V1 interna, un negocio por instancia y una sucursal operativa: directorio, inventario, venta/reversión, compras/recepción, personal/permisos y operación/recuperación privadas. Tienda pública, tarjetas, facturación electrónica y operación multisucursal comercial quedan fuera de esta V1.

El roadmap público conserva otra entrega: tienda con comercio real. No se elimina ese proyecto ni se lo declara terminado al completar SAVIA. El alcance interno es el objetivo inmediato documentado.

Hay contradicciones que deben reconciliarse antes de aceptar una release:

| Documento | Diferencia observada | Tratamiento en este paquete |
| --- | --- | --- |
| `ACCEPTANCE.md` y `STAFF-WORKFLOWS.md` | Proponen seis roles y aislamiento entre negocios. | Se usan como propuestas históricas. El contrato implementado tiene Owner, Manager, Cashier e Inventory; un negocio por instancia. |
| `TEST-MATRIX.md` | Incluye reservas sin endpoint interno; conserva pruebas entre sucursales y decisiones de stock pendientes. | Mantener los 22 criterios y sus estados. Jason debe resolver qué pertenece a V1; no reducir el denominador para aparentar avance. |
| `SAVIA-INTERNAL.md` y roadmap público | Contienen límites anteriores al runtime reciente y requisitos de tienda pública. | Priorizar CURRENT, evidencia concreta y fuente actual para hechos; conservar los documentos históricos. |

Las sucursales sintéticas adicionales pueden probar denegación y reasignación. No implican lanzar un producto multisucursal ni prueban aislamiento entre negocios.

### Pantalla → comportamiento → evidencia

| Área | Frontend observado | Backend y persistencia | Brecha para cerrar el flujo |
| --- | --- | --- | --- |
| Acceso | Login y limpieza de vista privada implementados. | Sesión persistida, CSRF, validación de rol y versión. Login Owner conservado. | SESSION-01 y otros roles en navegador. |
| Clientes/directorio | Lista, búsqueda y paginación. Alta y formulario deshabilitados. | Directorio interno implementado; escrituras Owner en el command runner. | Alta/edición desde UI con duplicados, errores y permisos. |
| Inventario | Artículos y saldos consultables por ubicación. | Ledger y ajustes; movimiento de venta conservado. | Denegación de ajustes, aislamiento, estados vacíos y error en el alcance operativo. |
| Ventas | Formulario de una línea, recibo, comprobación y reintento del mismo intento. | Precio del servidor, transacción, idempotencia y ledger. Venta Owner conservada. | Venta por cajero, sesión, aislamiento y conservación de recuperación. |
| Devoluciones/cancelación | No hay flujo equivalente en la pantalla de ventas inspeccionada. | API y evidencia sintética conservada. | Interacción del operador, motivo y prevención de doble reposición desde UI. |
| Abastecimiento | Panel indica pendiente; Nueva compra deshabilitada. | Orden, recepción parcial y deduplicación con evidencia HTTP. | Completar compras/recepción desde UI cuando permisos estén probados. |
| Personal | API y mantenimiento existentes; no flujo completo en las cuatro secciones inspeccionadas. | Cuatro roles, revocación y asignación. | Operación y recuperación de acceso demostradas con operador autorizado. |
| Operación privada | No es una pantalla comercial. | Copia/restauración sintética conservada. | Entorno de entrega, soporte, recuperación de acceso y ensayo por operador. |

Fuentes directas: `dev/savia-staff-ui/{index.html,app.mjs,client.mjs}`, `InternalCommandRunner.cs`, endpoints Commerce/Supply/Security y evidencia local indicada en SOURCES.

## Qué significa 100% terminado

**100% significa que una versión de alcance cerrado cumple todos sus criterios y puede operarse en el entorno acordado.** No significa tener todas las funciones imaginables ni cero bugs futuros.

Una capacidad está terminada cuando la persona autorizada la completa desde la UI, el API valida la regla, el almacenamiento conserva el efecto correcto y los fallos tienen salida comprobada. Compilar o tener un botón no basta.

Una release V1 requiere:

1. Alcance y criterios reconciliados, con responsable y versión; ninguna obligación oculta como “pendiente”.
2. Cada flujo incluido demostrado con rol permitido, rol denegado y estados de carga, vacío, error y resultado incierto aplicables.
3. Integridad monetaria y de inventario, concurrencia, replay, permisos y sesiones comprobados sobre el candidato exacto.
4. Regresiones pertinentes aprobadas; ningún fallo crítico abierto; limitaciones restantes explícitas y aceptadas por su responsable.
5. Entorno privado autorizado, configuración, copia/restauración, recuperación de acceso, diagnóstico y reversión operables.
6. Presupuesto de rendimiento medido en dispositivo, red y volumen representativos; navegación por teclado y tarea móvil verificadas.
7. Un operador completa los escenarios incluidos sin ayuda del agente. Martha/Jason acepta utilidad y presentación. Esa aceptación no sustituye pruebas técnicas.

El estándar fijo de cada incremento está en PLAYBOOK. Los criterios particulares de la próxima entrega están en NEXT-INCREMENT. El cierre de ese incremento no cierra la release.

## Bloqueos y pendientes con dueño

No se intentaron correcciones de producto en este encargo de diagnóstico. No incluye autorización nueva de identidades, sesiones, SQL, Docker, certificados ni ejecución de un piloto.

| Brecha / evidencia | Causa o hipótesis | Próxima acción y dueño | Prueba para cerrarla |
| --- | --- | --- | --- |
| ROLE-01, SESSION-01, SCOPE-01 y parte de ADJ-01 sin prueba operativa | Evidencia conservada usa Owner; falta la matriz de personal. | Orquestador prepara el paquete NEXT; Jason confirma la ejecución y las identidades sintéticas que falten. | Todos los subcasos de NEXT con readback y candidato exacto. |
| Posible bloqueo después de reasignación | `app.mjs` convierte fallo al recuperar último recibo en `pending ||= {}`. Hipótesis estática. | Implementador reproduce el caso N5 antes de tocar código. | Repro rojo; corrección mínima; venta permitida sin mostrar recibo ajeno ni perder intento incierto. |
| STOCK-00 y CONC-LAST-01 | Política de venta con cero aún depende de Tony/Jason. | Jason decide rechazo o venta con déficit y consecuencias. | Regla escrita; prueba de cero y carrera de última unidad coherentes. |
| ROLL-01 | Moneda inválida se rechaza antes de descontar; no demuestra rollback parcial. | Implementador prepara primera línea válida y segunda insuficiente, respetando el orden por ItemId. | Evidencia de primera escritura alcanzada y ningún efecto parcial persistido tras el rechazo. |
| AUTHORITY-01 | Inspección no sustituye prueba de única autoridad. | Implementador verifica feature gates, destino de red y endpoints durante ejecución autorizada. | Solo Internal participa; ninguna comunicación o escritura en adaptador legado. |
| RES-01 | No hay endpoint interno de reservas en la fuente inspeccionada. | Jason resuelve pertenencia a V1. Orquestador conserva historial de decisión. | Exclusión explícita del alcance o flujo interno implementado y probado; nunca usar legado para pasar. |
| Pantallas de alta, reversión, compras y personal | Backend y UI tienen grados diferentes de cobertura. | Implementador conecta un flujo completo por incremento después del actual. | Operador completa cada flujo y sus errores; API/ledger concuerdan. |
| Watcher PREPARED_NOT_ACTIVE; entrega/resume NOT_PROVEN | Archivos preparados no acreditan activación. | Orquestador mantiene ejecución manual. Una futura activación debe probar evento → agente → resultado con autorización vigente. | Recibo real de evento, una sola ejecución, parada y prueba de repetición deduplicada. |
| Rendimiento, aceptación visual y operación real | No hay evidencia suficiente en este paquete. | Operador y orquestador ejecutan escenario representativo en candidato autorizado. | Mediciones, tarea observada y aceptación registrada; no se infiere de pruebas sintéticas. |

## Decisión

Cerrar primero **Venta segura por cajero** ataca una dependencia compartida por ventas, inventario, abastecimiento y personal. El resultado útil es un empleado autorizado operando y un empleado no autorizado rechazado sin efectos.

La revisión independiente llegó a la misma recomendación desde la fuente. El orquestador verificó sus políticas, el command runner, la hipótesis de recibo y los disparadores de CI. Coincidencia entre agentes no cuenta como prueba del producto.

Lección aplicada: una prueba de rechazo antes de escribir no acredita rollback. NEXT exige observaciones del efecto persistido y PLAYBOOK separa rechazo, efecto parcial y resultado desconocido.
