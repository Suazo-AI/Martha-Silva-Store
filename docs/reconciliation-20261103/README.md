# Reconciliación de código, decisiones y conocimiento

Fecha: 2026-11-03. Host: SUAZO-PC. Checkout `C:/Users/Jason/MARTHA-SILVA/github`, rama `Tony`.
Encargo: actualizar folder y GitHub para continuar con otros agentes. Jason eligió índice y documentación de SQL.

## Resultado y procedencia

Diez archivos de producto/pruebas que permanecían locales se integran con los mismos SHA-256 del
candidato validado el 3 de noviembre. [source-binding.json](source-binding.json) vincula cada archivo
con [la evidencia publicada](../testing-20261103/evidence/source-hashes.json) en `64b974aec7e5f9a9777cf68ab8a3b6ce573ad2f9`.
Incluye consola Owner, validación de longitud de contraseña, UI de comercio y pruebas asociadas.
Esta tarea no modifica esos bytes ni corrige el fallo N5. No repite SQL ni pruebas ya acreditadas para esos bytes.

Se actualizan README, PROJECT-STATUS, SAVIA-LATEST, SAVIA-INTERNAL, documentación de backend y staff,
DECISIONS y PLAYBOOK. Se crea una entrada común: [AGENT-START](../AGENT-START.md),
[CODE-MAP](../CODE-MAP.md) y [DATABASE](../DATABASE.md).
Los documentos anteriores de release, roadmap, backend y diseño conservan su contenido con una advertencia de fecha.
El contrato N1–N10 conserva su alcance y refleja la validación parcial y N5 fallido.

El folder padre `STATUS.md` apunta al checkout canónico. No se replican fuentes en `cloudflare-store`,
`Martha-Silva-Store`, `store` o prototipos: tener varias copias supuestamente vigentes crearía divergencia.
`validation/`, `outputs/`, originales, registros fechados y pruebas anteriores permanecen intactos.
La copia pública del avance está en este checkout; los archivos privados solo aportan resúmenes curados y hashes.

## Exportación pública permitida

[operational-history.json](operational-history.json) conserva 22 IDs/estados, el subconjunto UI de cinco criterios,
los nombres de las dos migraciones y hashes de nueve fuentes privadas. No contiene conexiones, credenciales,
sesiones, autorizaciones, datos de clientes, bases, capturas operativas ni logs privados.
Es historia del 31 de octubre / 1 de noviembre UTC, no una consulta actual de SQL.

| Material local excluido | Inventario al corte | Tratamiento |
| --- | --- | --- |
| `docs/savia-internal/sql-local-20261031/` | 61 archivos, 581016 bytes | Conservar local; publicar resumen y procedencia; excluir explícitamente de Git |
| `docs/savia-internal/design-exploration-20261031/` | 2 archivos, 14507 bytes | Conservar briefing/estado local; no publicar autorizaciones o asumir entrega visual |
| `test-runs/`, `validation/`, `outputs/` del folder padre | Evidencia de ejecuciones y artefactos históricos | No copiar en bloque; la validación del 3 de noviembre ya tiene exportación pública revisada |

El briefing CUTUFAY pedía cinco direcciones y veinte imágenes. La confirmación del briefing no demuestra
entrega de imágenes ni aprobación de Jason. No se volvió a consultar el proveedor en esta sincronización.
Los digest de inventario permiten detectar cambios locales; los originales privados no son un requisito
para leer el código y continuar con fixtures nuevos autorizados desde otro equipo.

## Bloqueos contabilizados

| Bloqueo / evidencia | Causa o límite | Corrección / siguiente acción y responsable | Cierre verificable |
| --- | --- | --- | --- |
| N5, navegador 31/32 | Recibo confirmado 404 se convierte en falsa operación pendiente | Agente de implementación: corregir recuperación; tarea actual preserva el fallo y su reproducción | Regresión N5 pasa; ventas pendientes y sesiones revocadas siguen protegidas |
| Recorrido combinado actual | Navegador simula API; SQL corre en fixtures independientes | Preparar N1–N10 y entorno aislado; Jason autoriza ese runtime antes de ejecutar | Una venta, un movimiento, recibo recuperable y denegaciones sin efectos |
| Dos casos release NOT RUN | Entorno compatible de migración/backup/restore y contenedor propio fuera del lote anterior | Agente prepara alcance y entorno; no se ejecuta como parte de documentación | Ambos IDs exactos pasan con evidencia de recuperación |
| 19 regresiones heredadas | Contrato/fixture frente a producto todavía no reconciliado | Agente reproduce cada familia antes de cambiar expectativas; ver reporte de pruebas | Casos pasan por corrección demostrada o cambio de contrato aprobado |
| Cinco errores symlink Windows | `WinError 1314` en assets/staging | Completar casos en Linux autorizado; no cambiar seguridad de Windows | Auditorías completas y rechazo de symlinks ejercido |
| Graphify no ejecuta | Application Control bloquea `graphify.exe` al pedir ayuda | Git/rg/CODE-MAP ya permiten navegar; Jason tramita revisión autorizada solo si necesita el binario | Ayuda ejecutable y grafo scoped ligado al SHA; no se elude la política |
| Aceptación visual / producción / proveedores | Sin nueva aceptación del negocio, entorno productivo ni proveedor confirmado en esta tarea | Jason decide cuando exista candidato revisable; conservar alcance interno actual | Evidencia de aceptación y criterios de release de ese candidato |

No se intentaron correcciones de producto o runtime porque esta reconciliación actualiza y publica el estado probado;
esas correcciones pertenecen al incremento documentado. La falta de ejecución queda explícita, sin inventar PASS.
El primer exportador local omitió el ID `CONC-LAST-01` por una expresión regular demasiado estrecha;
su aserción bloqueó la exportación. Se corrigió el parser y se comprobó 22 criterios, 13 PASS y 9 NOT RUN.
Lección aplicada: validar denominadores y bytes antes de actualizar etiquetas de estado.

## Verificación y continuidad

La comprobación local exige enlaces relativos válidos para los documentos modificados, hash exacto de los diez
archivos, 22 criterios exportados y exclusiones privadas efectivas. Las guardas del registro y exportación
se verifican antes del commit. Los resultados frescos quedan en [verification.json](verification.json).
Los hooks producen el recibo y sincronizan Tony; el estado de GitHub se informa para el SHA publicado.
No editar un recibo generado ni atribuir a esta tarea un despliegue, un grafo generado o una base configurada nuevamente.
