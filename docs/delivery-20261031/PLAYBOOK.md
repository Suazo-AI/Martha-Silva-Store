# Playbook de entrega y corrección

Aplicar un ciclo a una capacidad observable. Las instrucciones activas del proyecto prevalecen sobre este documento y las skills externas.

## Responsabilidades

| Actor | Responsabilidad | No puede declarar por sí solo |
| --- | --- | --- |
| Jason / responsable de producto | Alcance, política de stock, compromisos y aceptación de uso. | Corrección transaccional sin evidencia. |
| Orquestador | Candidato, contrato, permisos, fuentes, dueño por archivo y verificación final. | Que un worker devuelto equivale a trabajo aprobado. |
| Implementador | Repro, cambio mínimo, regresión y registro del intento. | Éxito sin ejecutar la ruta afectada. |
| Revisor independiente | Revisar diff y contrastar criterios/evidencia; solo lectura. | Cambiar alcance o aceptar en lugar del operador. |
| Operador | Ejecutar la tarea real autorizada y el procedimiento de recuperación. | Que pruebas de muestra demuestran producción. |

Usar un implementador y un revisor solo cuando ahorre trabajo. Antes de lanzar cada lote de subagentes, Jason elige modelo exacto y razonamiento. La selección `gpt-6-astra/high` de esta entrega corresponde a su revisión acotada; no habilita lotes futuros.

## Ciclo de un incremento

1. **Recuperar:** leer AGENTS, estado del área y fuente de la capacidad; identificar diferencias locales y dependencias.
2. **Definir:** escribir resultado, límites, usuario, criterios congelados y observaciones que podrían refutar la solución.
3. **Preparar:** establecer candidato, datos sintéticos, comandos, autorización aplicable, estado inicial y recuperación.
4. **Reproducir:** comprobar el problema real antes de corregir. Distinguir defecto de producto, entorno o herramienta de validación.
5. **Cambiar:** una conducta y una corrección por ciclo; conservar trabajo ajeno y la identidad de operaciones inciertas.
6. **Probar:** regresión focalizada y flujo real afectado; contrastar efecto independiente, no solo etiquetas de éxito.
7. **Revisar:** comparar diff, contratos y datos sensibles; medir regresiones pertinentes. Registrar desacuerdos.
8. **Entregar:** actualizar documento del área, commit explícito, recibo, SHA remoto y CI pertinente. Operación y despliegue conservan sus gates.

Después de dos hipótesis fallidas, cambiar la explicación o la ruta de prueba. No repetir comandos a ciegas. Conservar fallos y operaciones consumidas.

## Estándar fijo por incremento

- Criterios particulares completos y evidencia del candidato exacto.
- Código revela intención, validación en límites, reglas de negocio en una autoridad y errores explícitos.
- Dinero conserva unidades menores y reglas del servidor; permisos, saldos y precios nunca dependen solo de UI.
- Transacción y replay cubren efectos de negocio. Un timeout no significa rollback ni autoriza una key nueva.
- Sin dependencias, abstracciones o refactors ajenos al problema demostrado.
- Tests de comportamiento en interfaces estables. No probar que un mock devuelve lo que se le indicó.
- Build, pruebas pertinentes y ruta crítica afectados pasan. Documentación sola recibe revisión y prueba del artefacto, sin ejecutar el producto por ritual.
- Estados vacíos, carga, error, accesibilidad y recuperación aplicables comprobados. Evidencia visual no sustituye ledger ni permisos.
- Registro con comandos, resultados, límites, siguiente acción, dueño y recuperación. Publicación revisada sin secretos ni datos reales.

Para bugs, el test debe fallar antes y pasar después por la misma razón observable. Para cambios menores reversibles, no crear tests que solo repitan la implementación.

## Bug: de señal a cierre

Flujo: `NEW → TRIAGED → REPRODUCED → FIXED → VERIFIED → CLOSED`. Usar `NEEDS_INPUT` para un bloqueo explícito y `NOT_REPRODUCED` si la señal no pudo demostrarse. Ninguno equivale a CLOSED.

| Estado | Evidencia mínima para avanzar |
| --- | --- |
| NEW | Señal y hora, ruta, resultado esperado/observado, candidato y origen. |
| TRIAGED | Severidad, producto/entorno/verificador, dueño y fingerprint sin datos sensibles. |
| REPRODUCED | Precondición, pasos deterministas, fallo exacto y estado final. |
| FIXED | Causa sostenida por evidencia, diff mínimo y regresión rojo→verde. |
| VERIFIED | Mismo repro pasa, controles afectados pasan, resultados independientes concuerdan. |
| CLOSED | Registro revisado, recuperación necesaria completada y evidencia publicada apta; aceptación del responsable cuando corresponda. |

Un incidente de resultado desconocido conserva key, actor y payload de negocio en almacenamiento privado autorizado. Se consulta el intento original antes de reenviar. El registro público usa aliases y hashes sanitizados, nunca cookies o datos de clientes.

La severidad depende del efecto: P0 pérdida/corrupción o exposición activa; P1 bloquea tarea crítica o permiso; P2 degrada con salida; P3 detalle. Este diagnóstico no descubrió un P0 confirmado.

## Hooks y agentes: contrato mínimo

**Actualmente:** `.githooks/pre-commit` revisa bytes staged y crea recibo; `post-commit` publica Tony y compara SHA. No ejecutan tests del producto ni activan un reparador de bugs. El watcher local permanece preparado sin activación y entrega probadas.

No hace falta otro daemon para ejecutar el siguiente incremento. El orquestador puede abrir el caso manualmente usando la plantilla y las herramientas existentes.

Para una futura activación automática, el contrato sería:

| Paso | Regla verificable |
| --- | --- |
| Trigger | Un fallo real de check o señal autorizada genera `event_id`, `candidate`, `check_id`, `fingerprint` y ubicación privada de evidencia. |
| Deduplicar | Mismo check/candidato/huella comparte caso. Un bloqueo por caso permite un solo worker. Repetición queda registrada, no dispara otro agente. |
| Admitir | Sin fuente, repro seguro, modelo aprobado, límites o permiso vigente: NEEDS_INPUT. El hook no otorga permisos. |
| Ejecutar | Repro→corrección→regresión en alcance asignado. Dos hipótesis fallidas obligan a cambiar diagnóstico. Tiempo y gasto tienen tope explícito. |
| Recuperar | Un worker caído deja el intento y lease registrados. Revisión manual antes de liberar o reanudar; nunca reenvío ciego de mutaciones. |
| Cerrar | Revisor verifica resultado y efectos; registra causa, solución, pruebas y evidencia. No auto merge/deploy por resultado del agente. |
| Probar activación | Inyectar un fallo sintético seguro, observar un solo worker y su recibo; repetir evento, verificar deduplicación; detener y comprobar que no inicia otro. |

Esto es especificación, no infraestructura instalada. No se promete trabajo continuo si la máquina duerme, falta sesión o no existe consumidor del evento.

## Plantilla de tarea

```yaml
task_id: SAVIA-<id>
mode: BUILD
candidate: <commit y hashes locales>
objective: <una capacidad observable>
owner: <implementador>
reviewer: <orquestador o revisor>
revenue_link: <tarea operativa útil que deja disponible>
source_of_truth: <archivos y evidencia concreta>
owned_scope: <rutas explícitas>
acceptance: <IDs congelados y oráculo independiente>
constraints: <alcance, datos, permisos, compatibilidad>
authorization: <referencia privada vigente; no copiar secretos>
limits: <tiempo, hipótesis, gasto autorizado>
validation: <comandos del TOOLKIT y flujo real>
rollback: <reversión o recuperación sin borrar historia>
stop_condition: <criterios completos o bloqueo exacto>
output: <documento del área + evidencia sanitizada>
output_contract: C:/Users/Jason/AI-OS/OUTPUT.md
```

Para un worker, incluir también el contexto mínimo de PROTOCOL y el texto relevante de OUTPUT. No enviar toda la conversación.

## Plantilla de bug

```yaml
bug_id: SAVIA-BUG-<id>
state: NEW
candidate: <commit + hashes>
signal: <check o acción que falló>
severity: <P0-P3 con efecto>
classification: <producto|entorno|verificador>
expected: <regla externa al cambio>
observed: <error exacto sanitizado>
repro: <precondición + pasos + resultado>
initial_state: <fixture y saldos de referencia>
attempts: [] # hipótesis, prueba discriminante, resultado; conservar fallos
cause: <probada o hipótesis explícita>
fix: <diff y por qué resuelve la causa>
regression: <rojo antes / verde después>
independent_readback: <HTTP + efecto persistido o tarea observada>
unverified: <gaps concretos>
next_action: <una acción, dueño y check de cierre>
recovery: <acción y resultado>
evidence: <rutas sanitizadas y hashes>
```
