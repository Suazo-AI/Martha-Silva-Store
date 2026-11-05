# D028 — Crítico

**Dictamen: protección instalada según recibo; avanzar a obtener C2. No equivale a integración segura demostrada ni cierra todo C1.**

Rol: crítico `gpt-6.1-sol`, razonamiento `high`. Modo VALIDATE, revisión documental de las cinco fuentes asignadas. Sin API propia, ejecución, contactos ni mutaciones externas.

## Evidencia y límites

El recibo D028 enumera los siete checks de la propuesta D027, ligados a `app_id=15368`; conserva `strict`, administradores sujetos al control, PR obligatorio, conversaciones resueltas y prohibición de force-push/borrado. No encuentro discrepancia material en los campos enumerados. El recibo declara coincidencia exacta; esta revisión no reproduce su comparación ni inspecciona la respuesta REST original.

`main` conserva `3b0049163ece2d9431cee01f1bea624a66d9d8d4`. PR #2 consta abierto, sin merge, con head `8744a9699812d62ea5ed31c63781748f833c3def`. El snapshot conserva cero deployments y sus identificadores. Esto respalda el alcance registrado; no prueba imposibilidad de desplegar por otras rutas.

Configuración leída no demuestra rechazo efectivo: no hubo push/merge adversarial. Cero aprobaciones requeridas tampoco impone un segundo revisor humano. No exigir una prueba destructiva ni cambiar esa política aprobada para continuar C2.

La variable y el comportamiento efectivo de despliegue siguen sin verificar. Por eso no declarar C1 completo si su aceptación incluye esa lectura. Mantener esa brecha explícita; no autoriza cambiar variables ni desplegar.

`PROJECT-STATUS.md` todavía recomienda autorizar la protección ya aplicada. El coordinador debe reemplazar esa instrucción vigente por el recibo y sus límites; conservar la historia. No bloquea recopilar C2.

## Mejor siguiente evidencia

Recomiendo reconstrucción guiada de 20–30 minutos con Martha, usando prendas, identidades y montos ficticios. Un cuestionario aislado captura respuestas, pero suele omitir transiciones entre registrar, cobrar, entregar comprobante, descontar existencias y cerrar caja.

Pedir que Martha muestre o describa cómo realiza hoy una venta de dos prendas: documento y campos usados, medio de pago realmente utilizado, confirmación del cobro, comprobante, efecto en existencias y registro que llega al cierre. Anotar cada paso como observado, declarado o pendiente. Si no puede mostrar el sistema, registrar explícitamente esa limitación.

Efectivo más transferencia sigue siendo una hipótesis: incluirlo solo si Martha confirma ese uso. No convertir el ejemplo en una política nueva. Una venta no cubre devoluciones, anulaciones, fiscalidad ni todas las excepciones; registrar esas brechas para la aceptación posterior.

**Entrada más valiosa:** una traza saneada y coherente de esa venta completa, validada por Martha. No pedir bases, credenciales ni comprobantes identificables. Jason conserva la gestión del contacto; esta revisión no autoriza mensajes.

Informe devuelto al coordinador; aceptación pendiente.
Host de revisión: SUAZO-PC.
