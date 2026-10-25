# Interfaz interna de SAVIA

Fuentes de la interfaz para personal y propietarios. Se desarrollan aparte de la
tienda Martha Silva: este directorio no es entrada de `prepare.py`, no se copia a
`dist/` y no se publica en el Worker de la tienda ni en `/savia/`.

La integración corresponde al servidor .NET privado. Antes de montarla, el
integrador debe acordar el acceso inicial y servir las operaciones y los datos
con sesión, permisos y aislamiento por negocio comprobados en el servidor.
Ocultar la navegación o un botón no constituye autorización.

## Reparto de archivos

- `login.html` y `login.mjs`: ingreso anónimo, sin datos del negocio.
- `index.html`: estructura semántica, navegación y formularios del personal.
- `styles.css`: diseño adaptable, estados y foco de teclado.
- `app.mjs` y, si procede, `client.mjs`: interacción y contrato HTTP del servidor.

Montaje acordado: `/internal/login` entrega el ingreso; `/internal/` y los
módulos del personal requieren `internal.read` en .NET. `styles.css` puede
servirse sin sesión porque contiene únicamente presentación. Las API devuelven
401/403 JSON; la redirección hacia ingreso corresponde a la navegación del
documento. Ese montaje es un contrato de integración, no prueba de despliegue.

No usar credenciales predeterminadas, autenticación en `localStorage`, datos
comerciales ficticios ni respuestas de éxito fabricadas. Una pantalla disponible
no demuestra que su operación esté implementada. Los precios, permisos,
existencias y resultados provienen del servidor.

## Verificación e integración

Los contratos exactos del integrador determinan rutas, DTO, sesión, CSRF y
recuperación de operaciones. No completar vacíos inventando endpoints. Las
respuestas perdidas después de una escritura requieren consultar el intento
original; no mostrar éxito ni generar una segunda operación equivalente.

La revisión debe distinguir comprobaciones estáticas, pruebas con dobles,
navegador real y persistencia SQL. El entorno Windows tiene presión de memoria:
la edición es ligera y los builds y recorridos de navegador se coordinan en el
entorno cloud de Cutufay. Los resultados se registrarán para los hashes exactos
entregados. Este README no declara una publicación privada ni QA completada.
