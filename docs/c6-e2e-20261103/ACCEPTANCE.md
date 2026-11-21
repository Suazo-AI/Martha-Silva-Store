# C6: contrato de aceptación congelado

Base revisada: `260b75951729189d987ffe423218ab1643bcfa3c`.
Destino: PR #2 de `Suazo-AI/Martha-Silva-Store`, conservando `Tony`.
Solo identidades, artículos, ventas y existencias sintéticos.

1. Chrome carga los archivos reales de staff UI desde el mismo proceso HTTPS de la API.
2. Login, consulta de inventario, venta, recibo, recarga y logout usan la API real y SQL Server real.
3. No se sustituyen respuestas de negocio por fixtures ni se inserta una venta desde el arnés.
4. Cada checkpoint del navegador se confirma con los oráculos SQL existentes antes de permitir el siguiente paso.
5. La primera venta descuenta dos unidades una vez y la recarga conserva el recibo sin escrituras adicionales.
6. La segunda venta recibe un HTTP 200 real, después del commit; solo entonces se descarta su respuesta al navegador.
7. SQL prueba la segunda venta antes de permitir su recuperación; se conserva la misma clave de idempotencia.
8. La recuperación usa GET, muestra el recibo original y las recargas posteriores no envían otro POST de venta.
9. Los contadores acumulados tras recuperar son dos ventas, dos líneas, dos movimientos de venta y dos operaciones; stock total 27 desde 30.
10. No hay stock negativo, claves repetidas, movimientos o saldos incoherentes según los oráculos existentes.
11. Los eventos publicados solo contienen campos permitidos y sintéticos; cookies, contraseñas, CSRF, conexión SQL y certificados privados no salen del directorio privado.
12. El artefacto publica únicamente `evidence.json` y `oracles.md`, tras verificar manifiesto, hashes y saneamiento.
13. No se suben HAR, trazas nativas, logs privados, sesiones, bases ni capturas con credenciales.
14. Se retiran API, perfil efímero, directorios privados, base propia y contenedor de CI; se verifica su ausencia.
15. C5 smoke y modo serve conservan sus contratos; una dependencia ausente o una falla del navegador hace fallar C6, sin SKIP silencioso.
16. El workflow conserva permisos y digest de imagen SQL; no cambia seguridad, certificados de máquina, servicios locales, despliegue ni main.
17. El CI y los artefactos corresponden al SHA publicado; la revisión del código sola no cierra C6.

## Límites y bloqueos

El ejecutor local hace comprobaciones ligeras; el recorrido real requiere el runner Linux del CI ya autorizado.
Un pase de mocks no sustituye esa evidencia.
La recuperación simulada representa pérdida de respuesta después del commit, no una caída real de proceso o de red.
El informe debe distinguir esas tres cosas.
