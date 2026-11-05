# Jurado: cierre técnico CI multiartículo

Dictamen: APTO técnicamente para el incremento probado. La evidencia cierra los pendientes técnicos de jury.md. No declara producción lista.

Jurado: gpt-6-astra, razonamiento high. Revisión de artefactos locales en SUAZO-PC; no reejecuté pruebas ni SQL. Referencias: golden41956521562 y judge41956521427. Candidato: 922852cbf6c9af2eacb2e5c02a42d912c14f6893.

Verifiqué SHA256 de los ocho archivos fuente registrados por C6 contra sus bytes Git en ese commit. Todos coinciden. Los seis archivos staff también coinciden con browser-results.json.

C6 registra PASS en 21/21 pasos. Después de response_loss_committed, recover_after_reload y repeated_reload conserva exactamente dos ventas, cuatro líneas, cuatro movimientos de venta y existencia25. Mantiene dos POST, la misma venta y la misma clave durante recuperación. Los oráculos muestran cero claves duplicadas y cero discrepancias entre líneas, movimientos y saldos.

El golden API registra PASS en 19/19 pasos. Conserva replay sin efecto y conflicto por misma clave con otro cuerpo.

Backend: 601/601 passed; notPassed=0. Verifiqué 1/1 passed para cada método crítico:

- Rejected_later_line_rolls_back_earlier_line_and_failure_replay_remains_immutable.
- Server_priced_multiline_sale_replays_immutable_receipt_after_price_change.

Browser: 47/47 PASS. Incluye multiartículo, pérdida de respuesta y recarga a 1440px y 390px. Esta capa usa API simulada; C6 aporta la prueba separada Chrome→API→SQL real.

Sin hallazgos materiales abiertos en este incremento. La objeción del crítico sobre rollback/replay queda cerrada por resultados ejecutados. El reset y el catálogo desaparecido conservan el cierre del dictamen anterior.

Límites: datos sintéticos y entorno CI. No demuestra Windows/SUAZO-PC, confianza TLS productiva, pagos, dispositivos móviles reales, aceptación visual ni auditoría completa de accesibilidad. sessionStorage conserva el límite de recuperación en la misma pestaña. No cierra C2/C9/C10 ni autoriza merge/deploy.

Siguiente acción: primary vincula este dictamen y los artefactos al registro GitHub/Trello, conserva los límites y verifica el readback de publicación.
