# C8: verificacion local completa; cierre pendiente de CI

## Port local sobre 260b759 — lote de agentes reutilizados

[Entrega y aceptación actual](current-head-20261104/primary-acceptance.json) · [patch combinado](current-head-20261104/candidate.patch) · [revisión y Trello](../technical-ready-review-20261104/primary-review.md).
Seis archivos y71 dependencias verificados. Evidencia anterior reutilizada; cero suites repetidas.
C8 sigue4/5, CI del candidato pendiente. Worktree actual: `test-runs/c8-current-head-20261104`, base `260b75951729189d987ffe423218ab1643bcfa3c`.
Los documentos siguientes conservan el resultado histórico sobre775f301.

Base `775f301bc195c43baedc68c86f4e71affe92ef95`.
[Resultado actual y limites](api-expiry-completion-20261103/completion.md).
[Comandos del lote API](api-expiry-completion-20261103/command-results.json).
[Aceptacion del primary](api-expiry-completion-20261103/primary-acceptance.json).

- SDK exacto `10.0.402` instalado portable, hash oficial verificado; SDK del sistema `8.0.422` conservado.
- Expiracion API con TimeProvider falso: `1/1 PASS`, dos `401`, resoluciones DB `0`.
- Control no expirado alcanza guarda DB antes de configurar SQL; ninguna conexion SQL.
- Regresiones `InternalSecurityTests`: `49/49 PASS`, incluye test nuevo; cero fallos u omitidos.
- Interfaz previa: enfocado `9/9`, navegador `45/45`, staff JS `45/45`. No se repitieron.
- Rojo-verde previo: solo app `7 PASS / 2 FAIL`; solo login `6 PASS / 3 FAIL`. Producto restaurado.
- [Revision independiente UI](independent-review.md): APTO CON REPAROS, sin defecto nuevo accionable confirmado.
- [Trello C8](https://trello.com/c/61IxxolB): En curso, `4/5`; API completada, CI pendiente. [Readback actual](api-expiry-completion-20261103/trello-readback.json).

## Evidencia y copias

[Reporte UI historico](report.md), [verificacion UI](verification.json), [patch UI](ui.patch).
[Patch del nuevo test backend](api-expiry-completion-20261103/backend-test.patch).
[Inventario inicial](c8-preflight.json), [cleanup previo](cleanup.json).
El [fallo historico del SDK](api-prerequisite.json) y el [handoff anterior](api-expiry-handoff.md) se conservan como evidencia previa; su bloqueo queda resuelto.

Nueva copia aislada: `C:/Users/Jason/MARTHA-SILVA/test-runs/c8-api-expiry-20261103`, rama `task/c8-api-expiry-20261103`.
Recursos propios liberados. Copia modificada intencionalmente: cinco archivos UI, un archivo de pruebas backend y documentacion.
Los worktrees previos se conservan; no se borraron cambios.
Tony conserva su codigo. Este directorio contiene evidencia y parches revisables, sin commit ni publicacion.

## Pendiente de cierre

CI debe cubrir el candidato que contiene ambos parches; no basta el verde de otra revision.
No existe SHA nuevo de este lote porque no se hizo commit/push.
Responsable primary/Jason: cuando autorice publicar el candidato, comprobar CI de ese SHA y completar `5/5`.
C11 conserva dependencia C8.
No hubo push, merge, despliegue ni cambios de configuracion de seguridad.
