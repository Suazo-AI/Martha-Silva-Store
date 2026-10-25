# SAVIA interno: base de trabajo

Sistema destinado exclusivamente a staff y propietarios: CRM, administración,
ventas, inventario y abastecimiento. La tienda pública de Martha Silva es otra
superficie. No publicar este sistema dentro de la tienda ni reintroducir `/savia/`.

La rama `feat/savia-internal-foundation` conserva la historia del backend y parte
del commit real `f7e859bd0e6edf6bdef8b391b63589a212f0d088`. El checkout es parcial:
backend, contratos, documentación y harness; no contiene los assets públicos.
No se reutiliza la caja ficticia de seis productos descartada.

La base f7 aporta reservas e inventario sintéticos, idempotencia, cancelación y
consulta de intentos. Sus datos XXX no son precios ni existencias comerciales;
cancelar una reserva no es registrar una venta ni un reembolso.

Se incorporaron 57 archivos del corte privado verificado en cloud: autenticación,
roles, directorio, ventas/devoluciones, inventario, compras/recepciones, runner de
operaciones y migración separada. Están implementados como código de desarrollo;
su persistencia y sus transacciones aún no se comprobaron con SQL real. El modo
interno permanece cerrado por defecto y requiere Development más habilitación
explícita. No es una entrega de producción.

La interfaz conecta ingreso, sesión y consultas paginadas de clientes/artículos.
El CRUD y los flujos de venta/compra/recepción de la interfaz siguen deshabilitados.
No hay backend publicado ni cuenta de personal creada. Las ventas y devoluciones
del código no procesan pagos bancarios ni reembolsos.

La implementación privada se coordina con Cutufay en cloud sobre 45 fuentes
verificadas. Su importación local `82b2e206…` tiene procedencia f7 documentada;
no es el SHA original ni demuestra un push a GitHub. El delta privado
`db4d9d27…` se incorporó contrastando 57 hashes y las dos modificaciones contra
la base real, sin sobrescribir la UI. Procedencia exacta en
[backend-source-import](evidence/savia-internal/backend-source-import.json).

Los criterios y flujos propuestos están en [REUSE-MAP](docs/savia-internal/REUSE-MAP.md),
[STAFF-WORKFLOWS](docs/savia-internal/STAFF-WORKFLOWS.md) y
[ACCEPTANCE](docs/savia-internal/ACCEPTANCE.md). Deben conciliarse con los contratos
compartidos del integrador antes de atribuir una función como implementada.

Se requieren controles de identidad, permisos y negocio en el servidor. No usar
el admin de `localStorage`, credenciales predeterminadas ni un selector visual
como seguridad. No se importaron clientes, pedidos reales, contraseñas o perfiles.

Este checkout no inició servidores, SQL ni una publicación privada o pública.
El ejecutor cloud reportó 435 pruebas C# PASS y 56 SQL omitidas; restore bloqueado
y Release sin advertencias ni errores. La UI paginada tiene 20 pruebas PASS
con dobles y jsdom. Aquí no se reejecutaron bajo la presión de memoria de Windows.
SDK de referencia: 10.0.402. Ver [evidencia](evidence/savia-internal/BACKEND-435-REPORT.md)
y los registros específicos de UI; los resultados anteriores de f7 son históricos.
La operación con SQL, credenciales y hosting requiere su destino y configuración
comprobados; la autorización para escribir código no acredita esos requisitos.
El alojamiento de pruebas solicitado es gratuito y sin tarjeta; el candidato y
sus incompatibilidades pendientes están en [FREE-HOSTING](docs/savia-internal/FREE-HOSTING.md).
