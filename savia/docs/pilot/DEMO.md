# Demo para la dueña: guion de 15 minutos

Datos inventados, una sola tienda (Masaya), en la computadora de Jason.
Orden pensado para lo que la dueña dijo que mira: los KPIs del negocio y de los trabajadores.

## Preparar (10 minutos antes)

1. Cierre programas pesados y otros agentes. Con la computadora cargada, la foto de etiqueta tarda más de 12 segundos y falla.
2. En PowerShell, desde la raíz del repositorio:

```powershell
python savia/tools/pilot.py down
python savia/tools/pilot.py reset --demo    # historia inventada nueva; solo reemplaza SAVIA_DEV_pilot
python savia/tools/pilot.py up --lan        # pide las cinco contraseñas; anótelas para la demo
```

3. Abra <http://127.0.0.1:5080/> en la computadora.
4. En el teléfono, en la misma Wi-Fi, abra la dirección que imprime `up --lan`, terminada en `/etiqueta/`.
   Si Windows pregunta por el Firewall, permita redes privadas.
5. Tenga a mano una etiqueta de prenda real y el archivo `savia/docs/pilot/import-samples/catalogo-ejemplo.csv`.

Ensayo automático (opcional): con las cinco variables `SAVIA_PILOT_PASSWORD_*` definidas, `python savia/tools/demo_rehearsal.py`.
Abre las 15 pantallas del guion sin escribir nada y guarda capturas en `savia/.out/demo/`.

## Guion

| # | Quién | Pantalla | Qué mostrar | Qué decir |
| --- | --- | --- | --- | --- |
| 1 | duena.muestra | Reportes, Negocio, período Mes | Vendido, Devoluciones, Venta neta, Ticket promedio, Margen | "Vendido menos devoluciones da la venta neta. Vendido entre ventas da el ticket promedio." |
| 2 | duena.muestra | Reportes, Equipo | Vendido, prendas, tickets y comisión por vendedora; cierres y diferencia de caja de la gerente | "La suma de las vendedoras es el mismo Vendido de la otra pestaña." |
| 3 | duena.muestra | Aprobaciones | Lista de descuentos y devoluciones que la gerente autorizó | "La gerente se autoriza a sí misma; usted lo ve todo aquí." |
| 4 | duena.muestra | Precios | Cambie un precio con motivo; confirme; abra el historial | "Solo usted cambia precios. Queda quién, cuándo y por qué." |
| 5 | gerente.muestra | Caja | Abra la caja contando billetes y monedas | "La caja se abre y se cierra por denominación." |
| 6 | gerente.muestra | Venta | Elija dos vendedoras; una prenda de cada una; cobre en efectivo; abra el recibo | "Un solo ticket y un solo pago; cada prenda le cuenta a quien la vendió." |
| 7 | gerente.muestra | Historial, Devolución | Devuelva una prenda de esa venta; muestre las cuatro salidas; elija crédito en tienda | "Treinta días de plazo; cambio, crédito, efectivo o transferencia. La comisión se revierte sola." |
| 8 | bodega.muestra, en el teléfono | Etiqueta | Foto de la etiqueta; los campos se llenan solos; corrija uno; registre | "Nadie digita el inventario. La foto no sale de esta computadora." |
| 9 | bodega.muestra | Recepción | Clasifique una entrega: buenas, una dañada, una faltante | "Solo las buenas quedan a la venta." |
| 10 | duena.muestra | Reportes, período Día | La venta y la devolución recién hechas ya aparecen; comisión actualizada | "Lo que pasa en caja se ve al momento." |
| 11 | duena.muestra | Importar catálogo | Suba el CSV de ejemplo; muestre la vista previa con errores por fila | "Su catálogo actual entra desde un archivo, con revisión antes de guardar." |

## Qué no está y cómo decirlo

- Traslados y apartados entre sucursales: decididos y diseñados; se construyen con la conexión entre tiendas.
- Impresora de recibos y escáner físico: no probados con equipo real.
- Las tres tiendas conectadas: hoy funciona una tienda sola.
- Los datos son inventados; los reales entran con Importar catálogo.

## Si algo falla

- La foto tarda o falla: escriba los datos a mano en el mismo formulario; el flujo sigue.
- Una pantalla no carga: `python savia/tools/pilot.py down` y `up --lan` otra vez; los datos se conservan.
- Quiere empezar de cero: `python savia/tools/pilot.py reset --demo`.

## Evidencia del guion

Ensayo del 2026-11-13 sobre la historia nueva: `REHEARSAL PASS: 15 of 15 screens`, 0 errores del navegador.
Los pasos 5 a 9 escriben datos; los cubre `web/tests/e2e_pilot.py`, no el ensayo.
Sin probar: el teléfono real de Jason, una etiqueta real, la impresora y el escáner.
