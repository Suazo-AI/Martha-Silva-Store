# SAVIA: evidencia local preservada

Última medición incluida: `2026-10-31T04:59:45.055602+00:00`.
En Nicaragua: 30 de octubre, 22:59:45.

`manifest.json` conserva SHA-256 de cada archivo exportado y su fuente local.
`historical-backend.json` contiene contadores; no incluye el TRX ni conexiones.
Los otros archivos son copias exactas de una lista explícita de fuentes.

- `source-deltas/`: cinco archivos de pruebas más recientes que el anterior Tony.
- `diagnostic/`: candidato, baseline, política de errores, diff y pruebas históricas.
- `package-acceptance.json`: preparación offline; revisión independiente pendiente.
- `package-vm.json`: cuatro casos con dobles, sin navegador real.
- `diagnostic-offline.json`: 21 casos sintéticos históricos, no repetidos en este push.
- `anonymous-failure.json`: fallo real anterior en etapa `anonymous`; cero controles aprobados.

Los scripts de diagnóstico son archivo histórico. Conservan rutas del host original.
No ejecutarlos como autorización de runtime. Faltan las copias masivas congeladas
del paquete; no se afirma que esta carpeta sea el paquete ejecutable completo.
Los cinco deltas también se incorporaron a `backend/tests/Martha.Store.Api.Tests/`.

Se excluyen secretos, certificados, autorizaciones de ejecución, datos de clientes,
bases, sesiones, logs y TRX completos. El repositorio es público.
La lista de exclusiones está en el manifiesto. Los originales permanecen locales.

Comprobación portable, sin ejecutar el producto:

```sh
python tools/export_progress.py --verify
```

La integridad del archivo no prueba funcionamiento ni acepta el piloto.
Estado y siguiente acción: [SAVIA-LATEST](../../../docs/SAVIA-LATEST.md).
