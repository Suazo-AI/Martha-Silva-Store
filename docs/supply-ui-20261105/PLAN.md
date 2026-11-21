# SAVIA: recepción de mercancía desde la pantalla de personal

2026-11-05, SUAZO-PC. Primary: T3 Code / Codex / gpt-6.1-sol, xhigh.
Base de producto: `14c1fbcce0e78bfe7260fd31539ff8f6d56f9fc3`, Tony.
Estado: especificación congelada; implementación y aceptación pendientes.

## Resultado y límite

Jason pidió continuar SAVIA y acercarlo a un sistema de tienda completo.
El siguiente incremento permite recibir mercancía de una compra existente desde SAVIA.
La venta multiartículo ya tiene evidencia histórica; no se vuelve a construir.

Fuente directa: `dev/savia-staff-ui/index.html:97-100` muestra abastecimiento no disponible.
`backend/src/Martha.Store.Api/Internal/Supply/` ya define compras, entregas y sus contratos.
La referencia SISFAIN es promocional y muestreada, no una especificación completa ni prueba de paridad.
Este incremento implementa el contrato existente de SAVIA; no copia ni inventa reglas fiscales.

La creación de compras y el directorio editable quedan para el siguiente incremento.
La recepción usa compras previamente registradas y datos ficticios durante su verificación.
No se modifica la política Owner del directorio de proveedores para facilitar esta pantalla.
El storefront y sus candidatos de frontend/hardening permanecen en seguimiento separado.

## Comprobaciones congeladas

1. Owner, Manager e Inventory pueden consultar compras paginadas, detalle y entregas de su ámbito. Cashier no puede operar esta pantalla. El servidor conserva la autoridad.
2. Mostrar proveedor, sucursal, moneda y cantidades pedidas, recibidas y pendientes desde respuestas validadas. Usar IDs de línea estables; no adivinar precios, unidades ni sucursales.
3. Registrar una entrega parcial o completa con `{receiptId,lines:[{purchaseOrderLineId,quantity}]}`. No enviar actor, costo, moneda o existencias calculadas por el cliente.
4. Guardar antes del POST la identidad de entrega física, clave de comando, cuerpo, actor y versión. Ante respuesta perdida, recargar o doble envío, conservar ese intento hasta comprobarlo. No fabricar éxito ni crear una entrega equivalente con otra identidad.
5. Comprobar operaciones mediante `supply.receipt.create` y el mecanismo existente del servidor. Un resultado incierto bloquea otra recepción incompatible; una respuesta rechazada no autoriza borrar una operación no resuelta.
6. Conservar CSRF, sesión, roles, ámbito y guards de generación. Un logout, 401, cambio de actor/versión o respuesta tardía no puede mostrar datos privados ni enviar una recepción nueva. Fallos de almacenamiento local se muestran y bloquean un envío sin referencia durable.
7. Rechazar cantidades inválidas, exceso de recepción, compras completas/canceladas y respuestas inconsistentes. Nunca corregir stock automáticamente ni debilitar reglas del backend.
8. Verificar en Chrome real con HTTP explícitamente simulado: recepción parcial/completa, recuperación tras respuesta perdida y reload, doble envío, error de contrato y sesión invalidada. Registrar antes/después del flujo en video local desktop/mobile, consola, requests y bytes servidos. Separar apariencia, comportamiento y persistencia real.
9. Añadir controles negativos acotados que demuestren sensibilidad a identidad/cuerpo cambiados o envío duplicado. Restaurar los bytes de producto y comprobar verde. Ejecutar staff completo y regresiones de navegador existentes cuando corresponda.
10. Mantener fuentes internas fuera de `dist/` y del Worker público. Si se añade un módulo, registrarlo como recurso protegido explícito en .NET. No ampliar un allowlist a rutas arbitrarias. Verificar publicación de recursos y checks portables; CI Linux posterior debe cubrir el candidato integrado.

## Propiedad y entrega

Un executor `gpt-6.1-sol/high` en worktree administrado implementa el incremento.
Primary integra en serie y mantiene el ledger; el worker no toca el checkout canónico.
El crítico Gemini 4 Argon/high y el juez GPT-6 Astra/high revisan el candidato congelado cuando exista.
Se reutilizan revisiones anteriores solo para sus fuentes y alcances originales.

Permisos: fuentes locales, pruebas sin base y navegador loopback con mocks.
Sin SQL, migraciones, Docker, certificados, credenciales, pagos reales, deploy o merge.
No hay autorización nueva por instalar o ejecutar una prueba histórica.
No afirmar persistencia real por un PASS de mock, ni producción por CI verde.

## Bloqueos y condición de cierre

| Hecho / límite | Acción y responsable | Cierre verificable |
| --- | --- | --- |
| La pantalla de abastecimiento está vacía; el contrato de recepción ya existe. | Executor conecta listado, detalle y recepción. | UI y recuperación ejercitadas, revisión primaria y CI del SHA integrado. |
| SQL nuevo no autorizado; C9 conserva su preflight consumido y problema de confianza TLS. | Primary prepara un procedimiento separado, sin conexión ni cambio de seguridad. Jason/administrador autoriza el runtime exacto. | Navegador→API→SQL autorizado, balances y unicidad leídos independientemente; restauración medida por separado. |
| Windows tiene `WinError 1314` en fixtures de symlink. | No repetir el fallo ni elevar privilegios. Usar CI Linux aplicable después de publicar el candidato. | Resultado del SHA exacto y alcance de sus jobs. |
| Compras nuevas, devoluciones, cobros/cierre, excepciones, hosting y aceptación operativa no se resuelven con recepción. | Primary conserva esos pendientes en sus gates actuales y toma el siguiente flujo después de aceptar este. | Pruebas propias de cada flujo; C2/C9/C10 y P-GO no se cierran por este incremento. |

La entrega del worker es RETURNED, no aceptación. El estado sigue NO-GO para producción.

## Verificación de esta planificación

- `python -X utf8 tools/delivery_status.py --check`: exit 0; 36 items válidos. SUPPLY-UI está `doing`.
- `python -X utf8 tests/test_progress.py`: 23/23, exit 0.
- `python -X utf8 tools/export_progress.py --verify`: 15 hashes preservados, exit 0.
- Backlog: 12 tarjetas preservadas; L01 sigue In progress / Sin evaluar, sin evidencia inventada. Se registró el traslado al thread gratuito.
- `git diff --check` sobre ledger/backlog: exit 0. No cambió producto en esta planificación.
- El primer `tools/delivery_status.py` falló por CP1252 al imprimir una flecha. `python -X utf8` resolvió el diagnóstico sin editar el script.
- La nota transferida usó una tubería PowerShell con codificación incorrecta. Se corrigió únicamente la nota con UTF-8 explícito y lectura JSON; el historial previo y los resultados permanecen.

Publicación, implementación, revisiones y CI de producto no se infieren de estas comprobaciones.
