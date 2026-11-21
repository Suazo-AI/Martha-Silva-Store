# Reconciliación documental local de C8

C8 conserva `doing` y Trello conserva `4/5`, `En curso`.
Se sustituyó la preparación obsoleta `NOT RUN` por evidencia local ya aceptada.
No se ejecutaron tests, builds ni instalaciones nuevas.

La base probada es `775f301bc195c43baedc68c86f4e71affe92ef95`.
El port local está sobre `260b75951729189d987ffe423218ab1643bcfa3c`.
El patch producto conserva SHA256 `a0762dc021260f4c8c88b849552c4775c6bef17af06c5338e68e95cd7a221df0`.
La evidencia es **REUTILIZADA**, no una ejecución nueva sobre el port.
Seis archivos coinciden byte por byte con los probados.
La comprobación documental confirmó que los 71 blobs de dependencias no cambiaron entre ambas bases.

| Evidencia reutilizada | Resultado |
| --- | --- |
| UI/browser enfocada | 9/9 PASS |
| Browser completo | 45/45 PASS |
| Staff | 45/45 PASS |
| API expiración | 1/1 PASS |
| InternalSecurityTests | 49/49 PASS; incluye API expiración |

Las fuentes son `report.md`, `binding.json` y `verification.json` del worker UI en esta misma carpeta.
La aceptación API está en `docs/c8-ui-20261103/api-expiry-completion-20261103/primary-acceptance.json` del checkout canónico.
Los documentos nuevos se destinan a `C:/Users/Jason/MARTHA-SILVA/github/docs/c8-ui-20261103/current-head-20261104/`.
Primary debe revisarlos y exportarlos; este worker no escribió en el checkout canónico.

Solo cambiaron `C8.prep` y `C8.evidence` en `docs/pipeline/ledger.json`.
Los demás campos, items, personas, targets, orden y formato permanecen iguales.
`ledger-proposal.patch` contiene únicamente el cambio documental del ledger.
`candidate.patch` conserva únicamente los seis archivos de producto/pruebas anteriores.
`trello-proposal.json` contiene IDs exactos y el texto propuesto; ejecutó cero mutaciones externas.
`acceptance-checks.json` registra la comprobación estructural y de hashes.

## Pendiente y responsable

CI del candidato C8 sigue pendiente.
La CI verde de `260b759` no cubre estos seis archivos nuevos.
No se marcó CI ni C11 como terminado.
No se intentó ejecutar CI porque este lote solo autoriza documentación local.
Primary/Jason debe revisar el patch y autorizar/publicar el candidato cuando corresponda.
El cierre exige CI verde vinculada a estos mismos bytes.

Primary debe revisar y exportar el ledger y los documentos cuando sus rutas estén libres.
Después podrá aplicar el texto propuesto a Trello y verificar el readback de `4/5`, `En curso`, CI incompleta.
Este lote no hizo commit, push, PR, merge, despliegue, SQL ni cambios de seguridad.
La copia queda dirty intencionalmente: seis archivos producto/pruebas, ledger y documentación.
No se crearon procesos persistentes ni recursos que limpiar.

## C4, C5 y C7: propuesta documental pendiente de juez

No se modificaron esos items del ledger ni sus criterios de cierre.
El veredicto del juez no estaba disponible al preparar este documento.
Primary incorporará el veredicto antes de proponer cambios de checklist.

| Tarjeta | ID exacto | Propuesta limitada |
| --- | --- | --- |
| C4 | `6aea5db529d01970fc29d79a` | Mantener parcial hasta comparar los oráculos privados; no inventar el cierre. |
| C5 | `6aea5de589984656dfca2dfc` | Candidato técnico 4/4 según el encargo; esperar confirmación del juez antes de proponer completos. |
| C7 | `6aea5de62bcaaced705f1942` | Mantener parcial: el 409 agrega `durableOperations +1`; esto no cumple cero escrituras literal. |

En C7, el criterio `6aea5e57d64fe07fd3f98734` conserva su alcance literal.
Jason debe resolver expresamente la diferencia; no se recortan criterios para aprobar.

Lección aplicada: el ledger debe distinguir evidencia reutilizada de una ejecución nueva y de una CI pendiente.
