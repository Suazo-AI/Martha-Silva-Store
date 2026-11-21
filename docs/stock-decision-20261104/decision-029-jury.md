# D-029 — dictamen del jurado

**APTO documental; sin hallazgos materiales. Entrega devuelta al coordinador, no aceptación operativa.**

Host: SUAZO-PC. Modelo: gpt-6-astra, razonamiento high.

D-029 registra la reconstrucción guiada aprobada con datos ficticios. El guion ofrece frases literales, preguntas concretas y una hoja sin respuestas inventadas. C2 conserva estado `todo`; la entrevista sigue sin coordinar ni realizar.

Coincido con el crítico: los bloques suman 26 minutos y permiten proponer unos 30 con transiciones. La duración y facilidad para un entrevistador nuevo siguen sin prueba práctica. No requieren corregir el guion antes de entregarlo.

La aritmética es correcta: C$1,000 base; C$35 de descuento y C$965 total; C$200 de cambio; C$600 + C$400; inventario 5→4 y 2→1; caja C$1,300 y diferencia C$50. Las variantes están separadas.

Distingue declarado, observado, pendiente y SAVIA probado. No transforma el relato en aceptación del sistema ni reabre multiartículo o D-026/D-027.

## Verificación independiente

- `python tests/test_progress.py`: exit 0; 23 pruebas en 72.963 s; OK.
- `python tools/export_progress.py --verify`: exit 0; 15 hashes conservados; PASS.
- `python tools/delivery_status.py --check`: exit 0; ledger válido; 34 items.
- `git diff --check`: exit 0; sin errores; avisos LF/CRLF.
- Escaneo de seis Markdown: 83 destinos locales existentes; cero ausentes. Ocho anclas no verificadas. El posterior `decision-029-review.md` no estuvo incluido.

Los mensajes SYNCED del test no prueban una publicación real de este checkout. No se ejecutaron pruebas funcionales, SQL, Docker ni llamadas externas. No se repitió `tests/check.py`; el coordinador informó un bloqueo previo WinError 1314.

El primer lookup usó `docs/PROGRESS-LEDGER.json`, inexistente. Se resolvió localizando y leyendo C2 en `docs/pipeline/ledger.json`; sin cambios al proyecto.

**Siguiente acción:** Jason coordina la conversación, usa el guion y devuelve el resumen saneado. El coordinador verifica la entrega y conserva C2 abierta hasta respuestas y matriz verificables.
