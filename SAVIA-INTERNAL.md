# SAVIA interno: base de trabajo

Sistema destinado exclusivamente a staff y propietarios: CRM, administración,
ventas, inventario y abastecimiento. La tienda pública de Martha Silva es otra
superficie. No publicar este sistema dentro de la tienda ni reintroducir `/savia/`.

La rama `feat/savia-internal-foundation` conserva la historia del backend y parte
del commit real `f7e859bd0e6edf6bdef8b391b63589a212f0d088`. El checkout es parcial:
backend, contratos, documentación y harness; no contiene los assets públicos.
No se reutiliza la caja ficticia de seis productos descartada.

El código existente aporta reservas e inventario sintéticos, idempotencia,
cancelación y consulta de intentos. No constituye un CRM/ERP terminado ni una
autenticación para personal. Los datos XXX de prueba no son precios o existencias
comerciales. Cancelar una reserva no es registrar una venta ni un reembolso.

La implementación privada se coordina con Cutufay en cloud sobre 45 fuentes
verificadas. Su importación local `82b2e206…` tiene procedencia f7 documentada;
no es el SHA original ni demuestra un push a GitHub. Los cambios entregados se
integrarán aquí contrastando los hashes de la base y conservando esta historia.

Los criterios y flujos propuestos están en [REUSE-MAP](docs/savia-internal/REUSE-MAP.md),
[STAFF-WORKFLOWS](docs/savia-internal/STAFF-WORKFLOWS.md) y
[ACCEPTANCE](docs/savia-internal/ACCEPTANCE.md). Deben conciliarse con los contratos
compartidos del integrador antes de atribuir una función como implementada.

Se requieren controles de identidad, permisos y negocio en el servidor. No usar
el admin de `localStorage`, credenciales predeterminadas ni un selector visual
como seguridad. No se importaron clientes, pedidos reales, contraseñas o perfiles.

Este checkout no inició servidores, SQL ni una publicación privada o pública.
Las 45 pruebas C# aprobadas y 21 SQL omitidas pertenecen al informe del ejecutor
para f7; aquí no se reejecutaron. SDK de referencia: 10.0.402, restore bloqueado.
La operación con SQL, credenciales y hosting requiere su destino y configuración
comprobados; la autorización para escribir código no acredita esos requisitos.
