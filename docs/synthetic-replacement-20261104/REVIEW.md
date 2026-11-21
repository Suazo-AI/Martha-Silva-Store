# Revisión independiente del simulador: APTO CON LÍMITES

Host SUAZO-PC. Modelo autorizado gpt-6.1-sol/high.
Task SISFAIN-MIG-QA-20261104; continuación del mismo lote.

## Resultado
18 escenarios; 51 comprobaciones; 0 fallos; 3 controles negativos detectados.
Los cinco comandos autorizados terminaron exit 0.
test_delivery_status: 24 tests. delivery_status --check: ledger válido, 34 items.
export_progress --verify: 15 hashes preservados.
El simulador y la plantilla conservaron los hashes del candidato congelado.

## Comandos y evidencia
- `python C:/Users/Jason/MARTHA-SILVA/github/docs/synthetic-replacement-20261104/simulate.py --out C:/Users/Jason/MARTHA-SILVA/coordination/research-20261104/migration/simulation-run` → exit 0; log `C:\Users\Jason\MARTHA-SILVA\coordination\research-20261104\migration\simulation-run\check-1.log`.
- `python tests/test_delivery_status.py` → exit 0; log `C:\Users\Jason\MARTHA-SILVA\coordination\research-20261104\migration\simulation-run\check-2.log`.
- `python tools/delivery_status.py --check` → exit 0; log `C:\Users\Jason\MARTHA-SILVA\coordination\research-20261104\migration\simulation-run\check-3.log`.
- `python tests/test_progress.py` → exit 0; log `C:\Users\Jason\MARTHA-SILVA\coordination\research-20261104\migration\simulation-run\check-4.log`.
- `python tools/export_progress.py --verify` → exit 0; log `C:\Users\Jason\MARTHA-SILVA\coordination\research-20261104\migration\simulation-run\check-5.log`.

## Hashes SHA256
- simulate.py: `1f1f5efe21eb0b3cdab7cb6acaebdeabed6b25f1b4bfd933e8ce3d6b784e5f85`.
- template.html: `e11c28600f843baac35209611b305eb5ab9b4af40e25eda4f0dc664af901da3b`.
- results.json: `83f72112b34ec861f5c457e3fe29f6065b3c3d738a192ad457126869d8d4226b`.
- index.html: `89e687b4f432f481e3c49cb5958044e8df70b96c706da9cbaae9ef51ef1f5657`.

## Revisión de aritmética, estado e independencia
S04: 2 × 350 + 900 + 1200 = C$2800; pagos 1000 + 1800.
S12–S14: ventas 2500 − devolución 350 − saldo 400 = caja C$1750.
Saldo: venta crédito 900 − anticipo 300 − abono 200 = C$400.
El artefacto final contiene caja 175000 centavos y saldo agregado 40000.
Se revisaron los 18 escenarios en la fuente: reconciliación autorizada/denegada, cero, multirenglón, replay, claves, atomicidad, pagos, rol, última unidad secuencial, recepción, devolución, crédito, cierre, snapshot, alteración, lote y controles negativos.
Los rechazos comparan el estado completo codificado antes/después.
Los valores esperados de importes principales son constantes externas al cálculo del modelo.
Los ocho checks adicionales del artefacto están en simulation-run/independent-artifact-checks.json.
HTML generado contiene los resultados embebidos y no conserva el marcador sin sustituir.

## Defecto inicial y corrección
Primera lectura: S01 describía ajuste autorizado/entrega/cobro, pero comprobaba rechazo del cajero.
Fuente original: simulate.py:182-186; template.html:54 atribuía el texto a resultado comprobado.
Se detuvo antes del runtime y se informó al primary.
El primary corrigió S01 para describir exclusivamente ajuste sin permiso rechazado y estado intacto.
Lectura fresca de simulate.py:182-186 confirmó esa corrección antes de ejecutar.
S02 conserva la entrega posterior a conciliación autorizada.
La fuente cambió durante la captura inicial; solo se conservó en consola el prefijo 81a89fc7 del hash anterior.
El hash completo 1f1f5efe… corresponde al candidato corregido, no a la versión del defecto.
Este informe reemplaza la atribución ambigua del REVIEW inicial.

## Límites de aceptación
APTO aplica únicamente al ejemplo secuencial sintético offline y a los checks autorizados.
No ejecuta código SAVIA, HTTP, SQL, Windows, SISFAIN, cobros reales ni impresoras.
No prueba concurrencia: S10 ejecuta A y después B.
El snapshot es copia/JSON en memoria; no prueba backup/restore SQL ni persistencia de un servicio.
Los controles negativos alteran copias de resultados; no son mutation testing del producto.
Modelo y checks comparten archivo: este agente revisó el código independientemente, pero no existe un oráculo ejecutable externo completo.
La revisión no valida todos los argumentos inválidos posibles de Model ni seguridad de su API interna.
La aritmética de caja propuesta no convierte esos módulos en capacidades implementadas de SAVIA.
No se verificó interacción visual en navegador.
No hay promesa de cero defectos ni aceptación de producción.

Siguiente acción: primary incorpora la evidencia saneada y mantiene separados modelo, pruebas de SAVIA y aceptación comercial.
