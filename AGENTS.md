# Reglas del repositorio

## Registrar cada avance

Destino de esta sincronización: `Tony`. Jason autorizó publicar los avances del proyecto.
Trabajar en el checkout Git canónico; no dejar cambios finales solo en carpetas externas.
Antes de cada commit, actualizar el documento del área con resultado, comando, evidencia,
límites y siguiente acción. Añadir rutas explícitas después de revisar datos sensibles.
Los hooks locales agregan el recibo y sincronizan GitHub; comprobar `SYNCED` y SHA remoto.
Si falla, resolver la causa y ejecutar `python tools/progress.py publish`; no declarar entrega remota.
No saltarse hooks ni usar force-push. Un entorno nuevo debe instalar los hooks conscientemente.
Ver [AUTO-SYNC](docs/AUTO-SYNC.md). La autorización de GitHub no autoriza runtime ni despliegue.
Para cambios del registro, ejecutar `python tests/test_progress.py` y
`python tools/export_progress.py --verify`, además de las comprobaciones aplicables.

## Antes de cambiar

1. Leer `README.md`, `docs/PROJECT-STATUS.md` y las instrucciones del área afectada.
2. Trabajar en una rama y limitar los cambios a la tarea asignada. Coordinar rutas cuando haya trabajo paralelo; no sobrescribir cambios ajenos.
3. Distinguir demo actual, original recuperado e investigación. El sitio original de Cloudflare se mantiene intacto.

## Fuentes y datos

- `src/` contiene comportamiento; `build-inputs/static/`, entradas estáticas; `dist/`, salida reproducible. Ejecutar `python3 prepare.py` tras modificar entradas.
- Mantener archivos originales separados e inertes. No habilitar Worker, rutas, bindings ni credenciales históricas por defecto.
- Nunca incorporar secretos, `.env`, cookies, perfiles, bases de pedidos/clientes, tarjetas, notas personales o volcados completos del equipo.
- Importar medios solo por lista permitida, desde una fuente autorizada, con hashes y revisión visual. No sustituir fotos ausentes y llamarlo recuperación.
- Los datos locales y variantes de muestra no son inventario comercial. `localStorage` y el admin de demo no constituyen seguridad de producción.

## Verificación y entrega

- Ejecutar `python3 tests/check.py --install` la primera vez y `python3 tests/check.py` en posteriores cambios. Registrar commit, comando, resultado y límites.
- Para cambios de imágenes, ejecutar además la auditoría de assets documentada. Una auditoría sin `--require-complete` no prueba recuperación completa.
- jsdom no es un navegador: no afirmar QA visual, móvil, accesibilidad o rendimiento sin pruebas correspondientes.
- No declarar una integración de pagos por detectar un SDK. Tarjetas son requisito para producción; proveedor y backend siguen pendientes. No se ha encontrado un backend SISFAIN.
- Revisar diff, datos sensibles y estado Git antes de commit. Preservar historia; no hacer force-push, borrados o despliegues no autorizados.
- Informar primero resultado útil y evidencia; luego pendientes. Un bloqueo debe indicar acción, destino, motivo y estado. No inventar URLs públicas, pruebas realizadas o un push exitoso.
- Antes de declarar entrega remota, comprobar SHA en remoto y resultados de CI aplicables; indicar qué no se ejecutó. Un push no equivale a despliegue.
