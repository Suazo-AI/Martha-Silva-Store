# Candidato devuelto; aceptación independiente pendiente

El índice degradado completó en **33,110 ms**. Antes excedió **40,000 ms**.
Catálogo: 39,842 → 32,535 ms. Amarillo: 37,415 → 30,682 ms.
Una muestra por condición. Mismo Chrome, DPR1, 360×800, 50,000 B/s por dirección,
400 ms, CPU6x, límite40s, loopback sin compresión y contextos nuevos.
No se alteraron caché, ventanas de grabación ni imágenes entre fases de fuentes.

Se importaron 1,093 archivos permitidos tras verificar 3,105 hashes.
La evidencia histórica importada conserva sus bytes.
No se regeneraron WebP. Los 156 PNG y sus enlaces/fallbacks siguen intactos.
Ocho WOFF2 completas: 1,544,216 → 458,104 bytes; TTF originales conservadas.
Familia, estilo, peso, display y CSS conservados al retirar solo las nuevas fuentes src.
Metadatos de licencia observados: copyright Cormorant/Manrope y URLs OFL incorporadas.
No se afirma una nueva licencia ni se descargaron fuentes.

Base y HEAD final: `6f304a7571a554bb8968e081a14985829aee3dfb`.
Host SUAZO-PC; Codex gpt-6.1-sol; high solicitado y efectivo; worktree T3 aislado.
Sin staging, commit, push, PR o deploy.

## Pruebas y contrato

La base intacta reprodujo cuatro fallos luxury-editorial/8.
Tras importar persistieron los mismos cuatro: original-catalog9/9 y editorial4/8.
El contrato vigente procede de `evidence/releases/20261030/current-runtime-sha256.json`,
`luxury-selected-assets.json` y `tests/fixtures/published-catalog-contract.json`.
El hash independiente del HTML publicado fija las nueve identidades y sus posts.
El contrato histórico `/editorial` y sus44 derivados sigue probado por separado.
Las ilustraciones actuales se identifican como generadas; no se llaman fotos históricas.

Final: editorial/original18/18; imágenes PASS; fuentes2/2.
Controles negativos rechazan etiqueta IA ausente, identidad equivocada,
source WebP ausente y pérdida de un carácter de fuente.
Staff DOM5/5 con NODE_PATH solo para el proceso, a las dependencias bloqueadas locales.
La interacción de Amarillo abre la mini-bolsa en las muestras antes/después.
La compra demo completa se reutiliza exclusivamente desde la evidencia importada.

`python tests/check.py` exit1: único intento. Build1559 y primeras suites pasan.
El fallo real es WinError1314 en tres fixtures symlink de asset-audit.
No se cambiaron privilegios ni pruebas para eludirlo.
Las etapas posteriores se ejecutaron separadas: todas exit0 salvo
catalog-staging, que reproduce dos WinError1314. Ver comandos y etapas.
Owner primary/Jason: ejecutar el check completo en host autorizado con symlinks.
Cierre: salida0 de todas las etapas ligada a estos bytes; CI anterior no sirve.

La codificación WOFF2 cambia head.checkSumAdjustment y activa bit11.
Se verificaron todos los demás bytes de tablas, cmap y orden completo de glifos.
La primera comparación CSS falló porque read_text normalizó CRLF;
se corrigió contra hashes RAW y LF de la fuente previa verificada.
Lección aplicada: diferencias de contenedor y finales de línea se comprueban
explícitamente; no justifican relajar identidad de fuentes.

## Evidencia

- [RESULT.json](RESULT.json): resultado, límites, blockers, owners y NOT RUN.
- [IMPORT.json](IMPORT.json): allowlist exacta, hashes importados y readback.
- [commands.json](commands.json): comandos/exits; [etapas restantes](remaining-stages.json).
- [source-manifest.json](source-manifest.json): fuentes finales RAW/LF; [paths](changed-paths.json).
- [measurement.json](measurement.json): bytes completados, cargas incompletas y condiciones.
- [fonts.json](fonts.json): procedencia, tamaños, tablas y hashes.
- [recordings.json](recordings.json): doce grabaciones normales validadas con ffprobe.
- [Antes móvil índice](before/recordings/normal-mobile-index.html.webm) / [después](after/recordings/normal-mobile-index.html.webm).
- [Antes degradado índice](before/recordings/degraded-mobile-index.html.webm) / [después](after/recordings/degraded-mobile-index.html.webm).
- [Logs privados y hashes](private-files.json): fuera de Git.

18 navegaciones reales; preview about:blank rechazado por unsupported-protocol.
Se usó Playwright/Chrome local del candidato; sin nuevos proveedores o uploads.
Las respuestas servidas coinciden con ambos manifiestos; cero mismatch.
Los bytes completados antes del timeout NO son peso total.
Los bytes transferidos de respuestas pendientes son desconocidos; se registra
por separado su tamaño fuente y estado inacabado.
Se inspeccionaron directamente seis pares de frames a4s.
La composición coincide en esas muestras; resto temporal y audio no revisados.
Jason conserva aceptación visual; primary conserva integración y aceptación.
El bloqueo previo del critic sigue abierto para primary; no se reintentó.

NOT RUN: segundo check completo, nueva compra completa, nuevos re-encodes WebP,
dispositivos físicos, Safari/Firefox, métricas de campo, critic/judge,
SQL/TLS/security, producción, pagos reales, subida o publicación.
