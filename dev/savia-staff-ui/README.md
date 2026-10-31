# Interfaz interna de SAVIA

Fuentes de la interfaz para personal y propietarios. Se desarrollan aparte de la
tienda Martha Silva: este directorio no es entrada de `prepare.py`, no se copia a
`dist/` y no se publica en el Worker de la tienda ni en `/savia/`.

El servidor .NET privado embebe seis recursos mediante una lista explícita.
El montaje está implementado bajo habilitación de desarrollo; no hay despliegue
ni acceso a SQL verificados. Ocultar la navegación o un botón no constituye
autorización. El alcance actual es un negocio por instancia/base aislada.

## Reparto de archivos

- `login.html` y `login.mjs`: ingreso anónimo, sin datos del negocio.
- `index.html`: estructura semántica, navegación y formularios del personal.
- `styles.css`: diseño adaptable, estados y foco de teclado.
- `app.mjs` y `client.mjs`: interacción y contrato HTTP del servidor.

Montaje acordado: `/internal/login` entrega el ingreso; `/internal/` y los
módulos del personal requieren `internal.read` en .NET. `styles.css` puede
servirse sin sesión porque contiene únicamente presentación. Las API devuelven
401/403 JSON; la redirección hacia ingreso corresponde a la navegación del
documento. Ese montaje es un contrato de integración, no prueba de despliegue.

El corte actual implementa CSRF, ingreso, verificación de sesión, cierre y
lecturas de clientes/artículos con paginación 25/50/100. Conserva consulta y página
por vista; una búsqueda sin aplicar no se mezcla con el desplazamiento anterior.
Ante 401 se vacían datos e identidad, incluso si la respuesta pertenece a una
consulta anterior. Nuevos clientes, edición, ventas y compras siguen apagados.

El corte de sucursales reserva clientes/proveedores a Owner. La UI oculta y
bloquea esas consultas para los otros roles y abre Artículos; el servidor sigue
siendo la autoridad. Artículos muestra el catálogo global, no existencias por
sucursal. No hay selector ni administración de sucursales en esta interfaz.
Antes de operar se requieren pruebas del servidor, sesión y ámbito persistido.

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
entorno cloud de Cutufay. Históricamente, el paquete paginado `41c66e52…` recibió 20 PASS:
9 de auth, 5 DOM y 6 de paginación. Son dobles explícitos, no SQL ni navegador.
Ese resultado no valida la nueva compatibilidad; los nueve casos de
`branch-compat.test.mjs` están escritos y pendientes de ejecución cloud.

Comandos: `node --test dev/savia-staff-ui/auth.test.mjs`, y para DOM/paginación
`node --test dev/savia-staff-ui/dom.test.mjs dev/savia-staff-ui/pagination.test.mjs dev/savia-staff-ui/branch-compat.test.mjs`
con jsdom 26.1.0 del lock existente de `tests/frontend-deps` disponible mediante
`NODE_PATH`. No se añadieron dependencias ni una instalación nueva de jsdom.
La suite agregada `tests/check.py` no se ejecutó para este cambio bajo el límite
de memoria. No hay QA visual/móvil, SQL real, push, CI ni despliegue acreditados.
