Source: <t3-thread://v2/f8cf991c-9b66-41e9-8378-e40c6d6e0314/thread:delegated-task:command%3Amcp%3A6cd109c8-84ea-4ee7-ac19-4576e9d28876%3Adelegate-task%3A49a372c4-2355-4291-82e9-641708bd3ac4>

**APTO CON REPAROS — evidencia suficiente para los tres huecos acotados de N5-COV.** No encontré un bloqueo material ni un defecto de producto demostrado. La aceptación final sigue a cargo del orquestador.

**Hallazgos menores**

1. **Precisar qué protección demuestra el 404 tardío.**
   [README.md:24](C:/Users/Jason/.t3/worktrees/github/t3-6b804833/docs/n5-browser-20261105/README.md:24) atribuye la protección a `app.mjs:514-516`. Sin embargo, logout incrementa también el epoch del cliente en `login.mjs:117`. Cuando llega la respuesta antigua, `login.mjs:56` rechaza ese epoch mediante un error 401 antes de procesar el 404. `restoreReceipt` vuelve a lanzar ese error en `app.mjs:511`.

   Impacto: el navegador demuestra protección conjunta durante logout. No demuestra aisladamente la rama `gone` ni la guarda de `restoreReceipt:514`. Esto satisface el límite de invalidación congelado; conviene corregir esa atribución documental.

2. **La comprobación inicial de inventario es poco precisa.**
   [browser-mock-validation.mjs:315](C:/Users/Jason/.t3/worktrees/github/t3-6b804833/tests/browser-mock-validation.mjs:315) busca `'10'` en el texto completo de cada fila. No compara las tres celdas iniciales exactamente.

   Impacto: podría aceptar otra representación que contenga ese texto. No bloquea este resultado: el fixture inicial entrega 10 y la comprobación posterior exige exactamente `8/0/8` y `7/0/7`, junto con una nueva consulta de inventario.

**Disposición de los cinco criterios**

| Criterio | Disposición y evidencia |
|---|---|
| 1. Recuperación retenida | **PASS.** Líneas 271–298 retienen el GET real. Comprueban botón deshabilitado, envío sintético sin POST adicional, bytes pendientes idénticos y GET con la clave original. Tras liberar: recibo original, pendiente eliminado y un único POST total. |
| 2. Venta completa tras 404 | **PASS.** Líneas 299–334 descartan la referencia anterior y completan dos artículos, cantidades 2 y 3. Comparan cuerpo exacto, un POST con clave generada, recibo nuevo, inventario actualizado y restauración tras reload sin repost. No existe una operación pendiente anterior para comparar claves. |
| 3. 404 tardío e invalidación | **PASS con la precisión anterior.** Líneas 335–359 retienen ambos requests, usan logout real y mantienen el documento vivo hasta recibir el 404. Verifican referencia conservada y datos privados vacíos. Login posterior permite descartar la referencia y habilitar ventas. No hay eliminación manual de storage. |
| 4. Regresiones y producto | **PASS.** Diff: un archivo, **94 inserciones, cero eliminaciones**. Los controles existentes de pendientes, 401, versión/scope, CSRF y respuestas tardías permanecen y figuran PASS en el resultado completo. No hay cambio de producto. |
| 5. Evidencia y límites | **PASS acotado.** Hashes, resultados y logs concuerdan. Todo verde acredita ausencia de defecto reproducido en estos escenarios; no existe evidencia red/green de una corrección. |

La carrera con una venta pendiente nueva dentro de la misma generación queda **razonadamente descartada**. `start` mantiene `busy` mientras espera `restoreReceipt`; el formulario queda bloqueado y el handler rechaza envíos. La navegación no crea otra instancia de comercio.

Revisé también el orden asíncrono. La prueba instala `waitForResponse` antes de liberar el 404, espera `finished()` y dos frames antes de inspeccionar el estado. Esto aporta una observación posterior a la respuesta; no constituye instrumentación de finalización de cada callback. La fuente inspeccionada no contiene una espera adicional en esa ruta de rechazo que justifique exigir otra ejecución.

**Evidencia verificada**

- **22/22 hashes coincidentes:** 16 artefactos y seis fuentes.
- Los manifiestos de fuentes de ambas ejecuciones coinciden con los seis archivos actuales.
- Las seis fuentes coinciden byte por byte con el checkout canónico. Frente a los blobs Git, solo difieren por CRLF/LF con `core.autocrlf=true`.
- `git diff --check`: sin incidencias.
- Logs UTF-16 decodificados: **N5 8/8**, navegador completo **50/50**, staff **102/102**, cero fallos; staff cero omitidos.
- Chrome **156.0.8078.80**, Node **v24.18.0**, host registrado **SUAZO-PC**.
- Ambos resultados: cero excepciones de página y cero solicitudes externas registradas.
- Abortos: focused **1 venta `ERR_FAILED` + 1 logout `ERR_ABORTED`**; full **10 + 3**. Concuerdan con las pérdidas deliberadas y cancelaciones de navegación.

SHA256 inspeccionados:

```text
tests/browser-mock-validation.mjs
020b29f19d8820489ccdb4317141ec3ca2fd83d4733a8244a277bc5ab982862c

focused/browser-results.json
32f51bc6ecec0fb53cda49b2258ac58bbe81999c2909e99e348c1a20096f5a9d

full/browser-results.json
d024a32cef75749e7540d8d11a10572188297bd8303c0fb21c258ac83ceb28c0
```

Los exits 0 y la primera ejecución verde están registrados por el worker. No observé esos procesos personalmente ni repetí las suites.

**Roles y límites**

Juez actual: **T3 Code / Codex, gpt-6-astra, reasoningEffort high**, confirmado por metadata del runtime y agent-awareness. Host: **SUAZO-PC**.

Worktree del juez: `C:/Users/Jason/.t3/worktrees/github/t3-72dd2c93`.
Worker inspeccionado: `C:/Users/Jason/.t3/worktrees/github/t3-6b804833`.
HEAD de ambos y base: `1e353d45cd0eb2ad8e79589f410ac191c1368b06`.
Uso de tokens/coste: **desconocido**.

**Opus no revisó este lote.** Su disponibilidad actual sigue desconocida; el bloqueo previo y los datos de cuota antiguos no acreditan disponibilidad ni aceptación.

**NOT RUN:** suites por este juez, API real, SQL, dispositivos físicos, CI, producción o aceptación operativa. No realicé ediciones, integración ni publicación.

**Siguiente acción:** el primario debe resolver los dos reparos documentales/de precisión y registrar este dictamen, manteniendo explícitamente pendiente al crítico antes de declarar cerrado el proceso de revisión.
