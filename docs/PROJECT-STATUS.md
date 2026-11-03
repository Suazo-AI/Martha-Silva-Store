# Estado vigente de Martha Silva / SAVIA

Corte: 2026-11-03. Host de la validación: SUAZO-PC. Checkout canónico `github`, rama `Tony`.
**No listo para producción. Siguiente incremento: venta segura por cajero, empezando por N5.**
Para continuar: [AGENT-START](AGENT-START.md), [mapa de fuentes](CODE-MAP.md), [decisiones](DECISIONS.md).

| Área | Evidencia verificada | Pendiente / límite |
| --- | --- | --- |
| Código del candidato | Diez archivos locales de producto/pruebas coinciden byte por byte con el candidato probado; [vinculación](reconciliation-20261103/source-binding.json) | Publicar código no corrige N5 ni cambia aceptación |
| Backend | 590 casos únicos PASS, 0 FAIL, 2 NOT RUN: 523 offline + 67 SQL reales | Dos casos de release/recuperación sin ejecutar |
| Staff JS | 42/42 PASS | Dobles de transporte/DOM |
| Navegador Chrome | 31/32 escenarios PASS; 47 páginas públicas montan sin errores JS no capturados | N5 FAIL; no Safari/iPhone físico ni auditoría completa de accesibilidad/rendimiento |
| HTTP real | 4/4 guardas PASS con API propia y SQL deliberadamente inaccesible | No es browser → API → SQL completo |
| SQL del lote reciente | 21 casos Store migrados + 46 internos EnsureCreated; 52 bases antes/después, cero nuevas restantes | No valida migración Internal de release; no se modifica SQL en esta sincronización |
| Operación histórica, 31 octubre | 13/22 criterios PASS, 9 NOT RUN; UI crítica 5/5; venta Owner, recuperación y persistencia | Corte histórico; no acepta automáticamente el código actual ni prueba uptime presente |
| Tienda pública | Snapshot histórico `601268a3`, 1081 archivos públicos, 47 páginas, 40 productos, 120 variantes | Demo; precios/stock/pedidos no son autoridad comercial; tarjetas pendientes |
| Regresiones heredadas | Desktop 1/14, Green 4/6, luxury 4/8 en el lote reciente | 19 casos fallidos necesitan reproducir y resolver contrato frente a producto |
| Auditorías Windows | Assets: 3 errores symlink; staging: 2 errores symlink; deployment: 13 PASS y 1 SKIP | `WinError 1314`; completar casos en Linux autorizado, sin relajar guardas |
| Medios y diseño | Recuperación 777/778; 156 PNG generados en 158 ubicaciones, según entrega histórica | No Full HD; referencias incompletas; no aceptación visual de Jason ni entrega CUTUFAY verificada |
| Navegación para agentes | AGENT-START, CODE-MAP, DATABASE y decisiones reconciliados | Graphify bloqueado por Application Control; no existe grafo canónico vigente |

Fuente de resultados: [validación 2026-11-03](testing-20261103/README.md).
La [reconciliación](reconciliation-20261103/README.md) conserva procedencia y exclusiones públicas.
Los porcentajes de matrices históricas no se suman con pruebas unitarias o escenarios de navegador.
La vinculación registra hashes locales y blobs publicados: Git solo normaliza saltos de línea en los diez archivos.

## Siguiente acción y aceptación

Corregir la recuperación de un recibo confirmado inexistente sin fabricar una venta pendiente.
Reproducir `Stale confirmed receipt`; conservar bloqueos de operaciones realmente pendientes y sesiones revocadas.
Después preparar el [incremento N1–N10](delivery-20261031/NEXT-INCREMENT.md) en entorno SQL aislado autorizado:
una venta, precio del servidor, un movimiento de stock, recibo tras recargar y recuperación sin duplicados.

Producción requiere además resolver pruebas heredadas, migraciones/recuperación, permisos/sesiones/sucursal,
dispositivos y aceptación del negocio. La tienda pública requiere su integración de pagos y autoridad comercial.
No ampliar pantallas ni infraestructura de agentes para evitar este camino crítico.

## Publicación y antecedentes

El commit que contiene esta reconciliación y su recibo en [progress](progress/) identifica los bytes publicados.
Comprobar SHA remoto y CI de ese SHA mediante [AUTO-SYNC](AUTO-SYNC.md); un resultado anterior no cubre el nuevo commit.
No se despliega, ejecuta SQL, inicia Docker, cambia certificados ni reinicia servicios en esta tarea.
[SAVIA-LATEST](SAVIA-LATEST.md), [cronología](UPDATE-HISTORY.md) y los documentos fechados conservan antecedentes.
La URL de producción para SEO sigue sin confirmarse; la observación anterior de `noindex,nofollow`
en la demo alternativa no se volvió a consultar aquí ni autoriza cambiar la indexación.
