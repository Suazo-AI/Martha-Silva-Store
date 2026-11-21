# Dictamen independiente C6

VEREDICTO: **NO APTO para cerrar C6 en este snapshot**.

La venta y la recuperación tienen evidencia real satisfactoria. El logout falló y la retirada de Chrome carece de readback de ausencia.
El binding de CI y los hashes vinculan los archivos recibidos con el contenido del candidato revisado.
Este dictamen es insumo para el primario, no aceptación funcional de Jason.

## Identidad, alcance y método

- Tarea: `savia-c6-judge-20261104`.
- Host comprobado: `SUAZO-PC`; PowerShell; revisión fechada `2026-11-04` UTC.
- Modelo/razonamiento del encargo autorizado: `gpt-6.1-sol` / `xhigh`.
- Snapshot: `C:/Users/Jason/MARTHA-SILVA/test-runs/c6-independent-review-20261104`.
- HEAD comprobado: `6aeb9a35f45331ace85ac48dc19bfd9264b0f722`; worktree limpio al iniciar.
- Base del diff: `9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3`.
- Contrato: `docs/c6-e2e-20261103/ACCEPTANCE.md:7-23`; sus 17 puntos permanecen sin cambios.
- Se revisaron los cinco archivos asignados. Son 824 inserciones y 15 eliminaciones.
- Las fuentes compartidas solo se consultaron para explicar oráculos, saneamiento, publicación y retirada.
- No ejecuté pruebas, builds, SQL, API, Docker ni navegador. No instalé herramientas ni modifiqué código.
- Solo escribí este informe fuera del checkout canónico. No hice commits, pushes ni delegaciones.

La evidencia recibida es `C:/Users/Jason/MARTHA-SILVA/coordination/c6-ci-41757409404/{evidence.json,oracles.md}`.
El directorio contiene únicamente esos dos archivos.
El run referenciado es https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41757409404.

Se aplicaron `juez-de-rama`, el playbook canónico de evidencia y los AGENTS aplicables.
El alcance vigente permite solo lectura del candidato y escritura del informe propio.

## Hallazgos por gravedad

### H1 — Alta: la corrida real no completa logout

Referencia: `tests/golden-path/browser_path.mjs:258-262`; `evidence.json:1296-1298`; `oracles.md:22`.

El checkpoint `browser.logout` está `FAIL`, tras `20126 ms`.
El resultado general es `FAIL`, con error saneado `c6_browser_failed`.
No hay oráculos SQL del checkpoint final ni prueba allí de revocación de la sesión.

Caso que lo rompe: la corrida real `41757409404`, tras las dos ventas y la recuperación satisfactorias.
Esto impide cumplir el punto 2 y cerrar C6.

No atribuyo una causa al producto ni al selector del arnés.
El diagnóstico pertenece al ejecutor asignado y no se repitió aquí.

Siguiente acción: el ejecutor corrige la causa reproducida; después, CI del nuevo SHA debe confirmar logout, HTTP 401 y cero sesiones.
Responsable: ejecutor C6; validación final: primario.
No intenté corrección porque el encargo prohíbe implementar y ejecutar runtime.

### H2 — Media: la retirada no verifica ausencia del proceso Chrome

Referencia: `tests/golden-path/golden_path.py:838-862`, `:994-1029`, `:1085-1088`.
Prueba asociada: `tests/test_golden_path_browser_safety.py:148-163`.

`stop_browser` envía TERM/KILL al grupo de Node y espera su proceso padre.
Después borra su referencia sin consultar si quedan procesos Chrome propios.
El PASS de retirada exige base borrada, directorio privado ausente y ausencia de errores críticos del log.
No incluye una comprobación de ausencia del navegador.
La prueba unitaria verifica llamadas simuladas; no demuestra ausencia de procesos reales.

Caso límite: Node termina mientras un descendiente Chrome permanece fuera del grupo señalado.
El código no detectaría ese descendiente y puede producir PASS para la retirada.
Es una brecha de verificación y aislamiento ante fallos, no evidencia de una fuga ocurrida en el run recibido.

La ausencia del perfil sí queda cubierta por `private_dir_removed=true`, porque vive dentro del directorio privado.
API y base tienen readback. El contenedor tiene una guarda de ausencia en el workflow.
La afirmación general de retirada del navegador necesita una comprobación adicional para cerrar el punto 14.

Siguiente acción: el ejecutor registra identidad propia del navegador/grupo, termina solo esos procesos y verifica su ausencia.
Debe fallar de forma explícita si no puede demostrarla.
Responsable: ejecutor C6; validación final: primario.
No intenté corrección porque el encargo prohíbe implementar o ejecutar procesos.

## Lo que cumple

Chrome usa UI/API reales, SQL valida cada avance, la respuesta perdida conserva la clave y la recuperación no repite la venta.

## Matriz de las 17 afirmaciones

`Cumplida` identifica evidencia o implementación verificadas dentro de esta revisión. No convierte la corrida completa en PASS.

| Punto | Estado | Evidencia y límite |
|---|---|---|
| 1 | Cumplida | `browser_path.mjs:170-187` compara los seis recursos servidos con hashes locales. Los seis hashes del artefacto coinciden con blobs Git HEAD. |
| 2 | Fallida | `oracles.md:12-21` confirma login/inventario/ventas/recibos/recargas; `oracles.md:22` registra logout FAIL. No se cierra el recorrido completo. |
| 3 | Cumplida | `browser_path.mjs:57-64`, `:190-245` continúa tráfico real y descarta una respuesta real. No fabrica respuestas ni inserta ventas desde el arnés. |
| 4 | Cumplida | `golden_path.py:409-437`, `:984-985` evalúa SQL antes de enviar el ACK. Un fallo impide el siguiente checkpoint. |
| 5 | Cumplida | `oracles.md:15-17`: 1 venta/operación/movimiento de venta y stock 28. La recarga conserva contadores; `browser_path.mjs:205-207`. |
| 6 | Cumplida | `browser_path.mjs:215-245` exige HTTP 200 y recibo real antes de `Fetch.failRequest`. `oracles.md:18` confirma después 2 ventas y stock 27. |
| 7 | Cumplida | `golden_path.py:961-985` valida clave nueva y SQL antes del ACK. La recuperación conserva la segunda clave; `browser_path.mjs:243-253`. |
| 8 | Cumplida | `browser_path.mjs:152-168`, `:247-255`; `oracles.md:52-53`. GET operations recupera el recibo original y POST acumulados permanecen en 2. |
| 9 | Cumplida | `evidence.json:1097-1103`, `:1218-1224`, `:1283-1289`: 2 ventas, líneas, movimientos de venta y operaciones de venta; stock 27. |
| 10 | Cumplida | Todos los checkpoints SQL satisfactorios tienen `oracle_failures=[]`; `golden_path.py:423-435` exige los invariantes existentes en cero. Logout no produjo oráculo final. |
| 11 | Cumplida con límite | `golden_path.py:72-123`, `:458-473`, `:508-523` limita campos y escanea secretos conocidos. No prueba imposibilidad de secretos desconocidos. |
| 12 | Cumplida por diseño y paquete | `.github/workflows/golden-path.yml:129-152`; `verify_evidence.py:16-46`. Solo publica los dos archivos verificados. El manifiesto original no viaja en el paquete público. |
| 13 | Cumplida | Upload enumera dos archivos exactos; `browser_path.mjs:31-35` no habilita HAR/trace/capturas. `evidence.json:1339` declara `raw_trace_or_har_recorded=false`. |
| 14 | Pendiente parcial | `evidence.json:1301-1310` prueba salida API, base borrada y directorio privado retirado. Workflow verifica contenedor. Falta readback de Chrome: H2. |
| 15 | Cumplida estáticamente | `golden_path.py:1046-1077` conserva smoke predeterminado y serve; dependencia ausente produce error y navegador fallido produce FAIL. Serve no se reejecutó. |
| 16 | Cumplida | Workflow `:13-14`, `:30-36` conserva `contents: read`, digest SQL y checkout sin credenciales persistidas. No añade despliegue ni mutaciones de main. |
| 17 | Cumplida en procedencia | El binding conserva run/head/merge sin archivos distintos. Los ocho hashes de fuentes y los dos hashes del paquete coinciden. La corrida fallida no acepta C6. |

Resultado de la matriz: **15 cumplidas, 1 fallida y 1 pendiente parcial**.

`browser_path.mjs` y `golden_path.py` en la tabla pertenecen a `tests/golden-path/`.
`evidence.json` y `oracles.md` pertenecen al directorio de evidencia recibido.

## Evidencia comprobada y procedencia

Los checkpoints `browser.start` hasta `browser.stock_after_recovery` están PASS.
Cada uno tiene oráculos SQL y cero fallos de invariantes.
La primera venta produce stock 28; las recargas lo conservan.
La segunda venta y su recuperación conservan stock 27 y exactamente dos POST acumulados.

Las dos operaciones del contrato son operaciones de venta (`sale_operations=2`).
Las operaciones totales son 9, porque incluyen preparación sintética previa.
Los movimientos totales son 5: tres ajustes de preparación y dos movimientos de venta.
No se confunden esos acumulados con duplicación de venta.

Los ocho hashes de fuentes del artefacto coinciden con `git cat-file blob HEAD:<ruta>`.
Incluyen los seis recursos UI, el arnés Python y el driver MJS.
La comparación de archivos físicos difiere por CRLF del worktree Windows; no es un cambio del candidato.
El DLL Release no pertenece al snapshot Git; su hash está en el artefacto, sin reconstrucción independiente aquí.

Leí el binding seguro `C:/Users/Jason/MARTHA-SILVA/github/docs/c6-e2e-20261103/ci-41757409404/run-binding.json`.
Este readback del primario conserva `run=41757409404`, `attempt=1`, evento `pull_request` y `conclusion=failure`.
Conserva `head_sha=6aeb9a35f45331ace85ac48dc19bfd9264b0f722` y merge `9ce7000a86c7bf14fda53b43cb98e036ad46184a`.
La comparación tiene `head_merge_changed_files=[]`, `ahead_by=1` y `behind_by=0`.
El contenido de archivos del merge coincide con HEAD, aunque sus identificadores de commit sean distintos.
Conserva C5, verificación de evidencia, upload y comprobación de ausencia del contenedor en `success`.
No consulté GitHub ni descargué logs dentro de este encargo.

Comprobé directamente SHA-256 de los dos archivos recibidos contra el binding:

- `evidence.json`: `d8c60c9ddd9194fa50c940ba46e23bbf24b89eaa4169e5f14d24c720035018ef`.
- `oracles.md`: `2654de7062945e4d993a805bf48a1a82bf7fae3da0e418178125b48f67bd7423`.

El workflow usa checkout sin `ref` explícito (`golden-path.yml:34-36`).
La comparación sin diferencias y los hashes exactos cierran aquí la vinculación de contenido del punto 17.
No convierten el resultado `failure` del CI en aceptación.

## Permisos y ámbito por parámetros cliente

El diff asignado no modifica endpoints, RPC, SQL de negocio ni autorización del servidor.
No introduce PostgREST ni un canal nuevo de escritura en el producto.
El arnés controla ubicación/artículo sintéticos y exige un cuerpo de venta sin precio o total (`browser_path.mjs:74-84`).
La URL se limita a HTTPS loopback; el navegador bloquea otro origen (`:21-23`, `:57-64`).
No encontré un bypass nuevo de permisos o sucursal introducido por este diff.
Esto no revalida toda la autorización de la base compartida, excluida por el encargo.

## Límites y siguiente aceptación

- No diagnostiqué logout ni revisé de nuevo toda la base compartida.
- No probé caída real del proceso, caída real de red, Windows funcional, teléfonos, producción, pagos o concurrencia.
- La falla inyectada descarta una respuesta HTTP 200 ya recibida; SQL valida después el commit antes de permitir recuperación.
- La prueba unitaria adversarial usa dobles. Su código protege el ACK, pero no reemplaza los oráculos SQL recibidos.
- No hay prueba de revocación de sesión del logout fallido.
- No hay readback de ausencia del proceso Chrome propio.
- La procedencia se apoya en el readback GitHub del primario y hashes comprobados aquí; no inspeccioné el log privado del checkout.

El camino mínimo es corregir logout y H2, conservar el binding y ejecutar CI autorizado del nuevo SHA.
El primario debe verificar las 17 afirmaciones contra esa evidencia antes de cerrar C6.
Reevaluaré solo el delta mínimo que entregue el primario dentro del mismo lote autorizado.

Uso disponible: el entorno del agente no expone tokens consumidos ni presupuesto restante por API.
