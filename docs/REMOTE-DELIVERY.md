# Entrega del repositorio

La importación remota inicial es una instantánea consolidada del trabajo recuperado. El repositorio local conserva la historia completa; LOCAL-COMMIT-HISTORY.txt registra los commits fuente para trazabilidad. No confundir los SHA locales con el commit creado por la API remota.

Los seis anexos brutos comprimidos research/rea/evidence/*.json.gz permanecen locales; no forman parte de esta entrega remota de código y evidencia legible. En particular, limoncello.json.gz tuvo su aprobación de subida cancelada y no se reintenta. El resumen legible de los hallazgos está en research/rea/FINDINGS.md. No se reintenta el archivo por otra ruta.

CI está preparada para ejecutarse tras el push. CD real y no-mistakes no están activados; consultar CI-CD.md y NO-MISTAKES.md. El hook local opcional permanece inactivo. La solicitud del propietario es público durante construcción, privado al terminar; comprobar visibilidad real y no inferirla de este documento.
