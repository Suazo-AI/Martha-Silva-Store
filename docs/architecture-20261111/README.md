# Arquitectura objetivo de SAVIA: tiempo real, crecimiento y móvil

Fecha: 2026-11-11. Autor del rol: arquitecto (agente primary), con mandato de Jason sobre cómo se construye.
Estado: decisiones técnicas tomadas por el arquitecto; gasto, cuentas y datos de clientas siguen pendientes de sus dueños.
Nada de esto está implementado todavía. Candidato leído: `Tony` @ `89d036e`.

## Quién decide qué

| Tipo de decisión | Decide |
| --- | --- |
| Cómo se construye (stack, protocolos, rendimiento, pruebas) | Arquitecto |
| Gasto, cuentas, tiendas de apps, despliegue | Jason |
| Datos de clientas y permisos del personal | Martha, con revisión legal antes de producción |

## Decisiones técnicas tomadas

### T-1. Una fuente de verdad en la nube; la caja vende sin internet

Una base central sirve a sitio, CRM, app y todas las sucursales.
Cada caja guarda ventas en una cola local cuando no hay conexión y las sube al volver.
Las ventas ya llevan `Idempotency-Key`; un reintento no duplica.
Los choques de stock se resuelven con la revisión de excepciones existente (D-026/D-027).
Pendiente: cotización y aprobación de hosting por Jason. Hasta entonces se desarrolla y prueba en SUAZO-PC.

### T-2. Tiempo real con Server-Sent Events

El servidor empuja cambios a las pantallas abiertas. Incluido en .NET 10; sin dependencia nueva.
Las escrituras siguen por HTTP con CSRF e idempotencia.
Con más de un servidor se agrega un canal compartido entre instancias; no hace falta con uno.

### T-3. Presupuesto de rendimiento verificado en CI

- Acción de caja: p95 ≤ 200 ms.
- Cambio visible en otra pantalla: ≤ 1 s.
- Sitio: LCP ≤ 2,5 s, INP ≤ 200 ms, CLS ≤ 0,1 en perfil de móvil de gama baja con 4G lento.

Un cambio que rompa el presupuesto falla CI.

### T-4. App móvil: un solo código para web, Android e iOS

1. La interfaz web se vuelve PWA: manifiesto, service worker y la cola offline de T-1.
   Se instala en Android desde Chrome sin tienda.
2. Para Google Play se envuelve el mismo código con Capacitor.
   Capacitor da acceso nativo cuando haga falta: cámara para códigos de barra, impresora, notificaciones.
3. iOS usa el mismo proyecto Capacitor. Solo cambia la firma y la publicación.

Descartado: Kotlin y Swift nativos (dos códigos para un equipo pequeño);
React Native o Flutter (reescribir pantallas que ya existen y tienen pruebas).
Hoy `dev/savia-staff-ui` es web sin service worker ni manifiesto; ese es el punto de partida.

## Pendiente de sus dueños

- Martha: permiso de la cajera sobre clientas.
- Jason: canal de avisos, cotización de hosting, para quién es la app primero, cuentas de tiendas.

## Prueba independiente de cada decisión

| Decisión | Pasa si | La refuta |
| --- | --- | --- |
| T-1 | Corte de red a mitad de turno: cero ventas perdidas o duplicadas al reconectar | Una venta falta o aparece dos veces en SQL |
| T-2 | Venta en pantalla A visible en pantalla B en ≤ 1 s, medido en navegador real | Retraso mayor o evento perdido tras reconexión |
| T-3 | Lighthouse CI y prueba de carga dentro de umbrales en el SHA | Cualquier métrica fuera de umbral |
| T-4 | Misma build pasa las pruebas de navegador y corre instalada en un Android de gama baja | Una pantalla que funciona en web y falla instalada |
