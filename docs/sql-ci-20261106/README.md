# SQL real: aceptación técnica acotada

El primary acepta la corrida aislada [42163110947](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42163110947), intento 1.
Fuente probada: `708bdbbf2eff568d571b7593ed40d2422414c671`. No se ejecutó una segunda corrida.

Backend: **602/602 PASS, cero fallos y cero outcomes omitidos/NotExecuted**.
Incluye backup con checksum, verificación y restauración real, y persistencia tras detener/iniciar el contenedor.
Los tres métodos obligatorios —recurso protegido, backup/restore y reinicio— tienen 1/1 PASS cada uno.
El worker mapea 76 casos SQL dentro de los 602; no son casos adicionales.
Staff124/124, Chrome existente50/50 y abastecimiento8/8 pertenecen a capas separadas, con HTTP simulado.

## Verificación independiente del primary

- Leyó de nuevo el run y ambos jobs mediante la API de GitHub. SHA, workflow, evento, intento y conclusiones coinciden.
- Descargó otra copia del artefacto `savia-backend-outcomes-42163110947-1` directamente de GitHub.
- Comprobó su SHA256 `034d470778306acbb63ec14ce1b862b36bc04d0ca074f98c2c4dac1449c23e7e` y sus 602 resultados.
- Contrastó 16 bindings de fuente contra los blobs Git del SHA probado.
- Verificó el hash del log privado y la salida real de cleanup, separada del comando echo:
  `2026-11-06T04:34:35.8745839Z PASS: disposable SQL container absence verified.`
- Importó exactamente tres archivos públicos del worker. No importó logs, TRX, ZIP, credenciales ni entorno.

Las lecturas, descarga y verificador del primary terminaron con exit 0.
[Recibo de aceptación](ACCEPTANCE.json) · [Detalle del worker](worker/README.md) · [Outcomes saneados](worker/outcomes.json).

## Límites

Esto acredita el backend contra SQL desechable de Actions y su recuperación probada.
No une todavía la recepción de la pantalla con API y SQL reales en un solo recorrido.
No acredita TLS ni RTO/RPO locales, C2/C9/C10, aceptación del negocio ni producción.
No hubo merge ni despliegue. La autorización de esta única corrida quedó consumida.

Al crear este recibo, la publicación documental todavía estaba pendiente; su SHA remoto y CI se verifican por separado.
La próxima tarea independiente es preparar el recorrido real de recepción en el arnés existente, sin reutilizar esta autorización SQL.
