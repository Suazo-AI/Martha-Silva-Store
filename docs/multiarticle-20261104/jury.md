# Jurado: multiartículo recuperable

Dictamen: APTO para continuar validación CI. No aceptado todavía como flujo real SQL ni producción.

Jurado seleccionado: gpt-6-astra, razonamiento high. Fuentes locales: SUAZO-PC. Revisión read-only del diff sobre b17437a8e1522898a0f304f1ac87ad81f1364456. No merge, deploy, SQL, Docker ni certificados.

## Hallazgos y cierre

Encontré un defecto material inicial en app.mjs:530: confirmar desbloqueaba el carrito anterior sin vaciarlo. Otro submit podía emitir la misma selección con clave nueva. También conservaba el artículo retirado del catálogo después de recuperarlo.

Primary corrigió ambos casos. app.mjs:515 y :531 restablecen una fila sin artículo después de confirmación o restauración sin pendiente. El select required contiene un placeholder vacío. Revisé el diff corregido y ejecuté nuevamente 52 pruebas. La prueba multiarticle double submit demuestra un solo POST tras confirmar y volver a enviar sin elegir artículo. Hallazgo cerrado. No encontré otro defecto accionable en el candidato final revisado.

## Respuesta al crítico

1. Identidad y recibo: client.mjs normaliza UUID para duplicados y pertenencia. Exige 1..100 líneas, cardinalidad exacta, cantidades exactas, saleLineId únicos y aritmética. Acepta recibos permutados sin modificar el cuerpo original. Los tests rechazan omisiones, extras, duplicados, cantidades incorrectas y límites inválidos.

2. Recuperación y catálogo: app.mjs reconstruye filas desde pending.body. Añade una opción identificada si un artículo desapareció. El test inspecciona el segundo itemId y cantidad dentro de recoverSale antes de confirmar. La operación conserva cuerpo y clave. Un fallo completo del catálogo mantiene bloqueo y almacenamiento; no acredita recuperación disponible mientras falla ese catálogo.

3. Una operación: cart() produce objetos nuevos. setItem antecede resolve y POST. pending/busy bloquean controles, handlers y doble envío. El reintento utiliza operation.body, incluso si el DOM cambia programáticamente. El reset posterior ya queda cerrado arriba.

4. Atomicidad real: no ejecutada por este jurado. C6 ahora solicita dos líneas por venta y exige dos ventas, cuatro líneas, cuatro movimientos de venta y stock total 25. El DOM verifica artículos primero=7, segundo=8 y tres saldos total=25; el tercero resulta 10. Los oráculos SQL existentes unen SaleId/itemId, cantidad y movimiento; verifican saldos contra movimientos. No considero necesaria una nueva abstracción de oráculos para este incremento. Deben pasar el C6 real y el rollback/replay backend existentes en CI.

5. Durabilidad: continúa limitada a sessionStorage y la misma pestaña. No demuestra recuperación después de cerrar pestaña/navegador ni desde otro dispositivo.

Autorización: no observé ampliación de roles, rutas, CSRF ni alcance. Las regresiones locales de 401, identidad, permisos y respuestas tardías pasan.

## Comandos y resultados propios

- `$env:NODE_PATH=(Resolve-Path tests/frontend-deps/node_modules).Path; node --test dev/savia-staff-ui/*.test.mjs`: exit 0, 52/52. Ejecutado antes y después de corregir el reset; ambos pasan.
- `python tests/test_golden_path_browser_safety.py`: exit 0, 16/16.
- `python tests/test_golden_path_safety.py`: exit 0, 17/17.

Los 4 comandos de verificación agotaron el presupuesto asignado. No ejecuté browser-mock-validation, Chrome real ni backend. No afirmo aceptación visual, accesibilidad completa o integración SQL a partir de jsdom.

## Pendientes y responsables

Primary debe publicar evidencia permitida y verificar CI del candidato exacto: C6 multiartículo, rollback de segunda línea y replay backend. Cierre: run/SHA vinculados, cero fallos relevantes, cuatro líneas/cuatro débitos, stock25 y recargas sin cambios. Causa del pendiente: esta revisión prohíbe SQL/runtime local; no intenté arrancarlo.

Primary debe conservar evidencia visual antes/después y su límite, además de registro Trello/GitHub. Este jurado no inspeccionó esos artefactos. La autorización de publicar avances no autoriza merge ni deploy.

## Identificación del candidato

SHA256:

- app.mjs: 383C40447E91AA465CC945138699151826D7C1AD93F2F1ED041AA3DCDA303309
- client.mjs: 0447A3C83910D9A5618F98886D1025B9A74A3F59839EECA2EA0D7CC1CA6C4825
- commerce.test.mjs: C7F8FE1120AAC8CC6D70290A79FBE002E888E7A8CF722F7E65E9DC7E67D5E6C1
- browser_path.mjs: EA84DC9186201B7A74B1BCD3B5DFB0515DDB781E97D2872D38AB4943B492BECC
- golden_path.py: 4216481C199F5E9C76246B7F277F7D72F55E098567739B779CC61E026AFE7EA4
