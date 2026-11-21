# APTO tecnico: C4 y C5

Task: `C4-C5-INDEPENDENT-20261104`. Estado: completo. Revisor: `gpt-6-astra/high`, host `SUAZO-PC`.

Base congelada: `d475d6d4a2caffe9d8181acdff80794ff3f6abb4`. No use READY ni estados del ledger como prueba. No encontre un defecto concreto que invalide el contrato C4/C5. No hay hallazgos bloqueantes ni reparos tecnicos demostrados.

## Vinculo de evidencia

Lei directamente los artefactos locales de [backend 41779354410](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41779354410) y [Golden 41779354413](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41779354413).

Esas ejecuciones pertenecen a `8744a9699812d62ea5ed31c63781748f833c3def`, no a d475. El checkout real `2c29209667631c38047f33f3e84f4d777a7740e3` tiene padres main `3b004916` y 8744. Git local confirma que ambos arboles son `32112430eff2932fa593338b3e454dd2020bc9a5`.

Git confirma que d475 tiene padre 8744. Solo difieren `docs/DECISIONS.md`, `docs/PROJECT-STATUS.md`, `docs/pipeline/ledger.json` y un recibo de progreso. Producto, pruebas, migraciones, dependencias y workflows conservan bytes. Esto permite reutilizar la prueba tecnica; no convierte el run anterior en CI del SHA nuevo.

## Matriz contra contrato

| Criterio | Fuente inmutable y evidencia directa | Limite |
|---|---|---|
| C4: sin modelo pendiente | `InternalMigrationTests.cs:55`: HasPendingModelChanges false; metodo 1/1 | Resultado CI 8744 |
| C4: script EF completo y guarda | `InternalReleaseScriptTests.cs:39`: igualdad con GenerateScript, registro de cada migracion y rechazo de SQL administrativo; metodo 1/1 | Normaliza solo BOM/CRLF/saltos finales |
| C4: vacia e historia con readback | `InternalReleaseScriptTests.cs:52`: script aplicado por lotes a vacia e historia primera migracion; preserva todas las columnas originales; compara esquema contra migrador independiente y reaplica; metodo 1/1 | Historia sintetica, no copia de cliente |
| C4: respaldo/restauracion adicional | `PrivatePilotReleaseTests.cs:107`: BACKUP CHECKSUM, VERIFYONLY y RESTORE real; igualdad de negocio/esquema y restricciones; metodo 1/1 | Copia sintetica de release completo |
| C5: local y CI, migraciones reales | `GoldenPath.Sql/Program.cs:105`, `golden_path.py:529`, `golden-path.yml:90`: IMigrator, build bloqueado y mismo entrypoint | Local soportado POSIX; Windows no probado |
| C5: cinco identidades | `golden_path.py:616`, `:677`, `:709`: Owner por consola, personal HTTP, perfiles y denegaciones | Una sucursal; no auditoria universal de scopes |
| C5: venta/replay/oraculos | `golden_path.py:412`, `:768`; SQL en `Program.cs:154` | 19 pasos PASS, 18 capturas SQL sin violaciones |
| C5: retiro/publicacion | `golden_path.py:1060`, `:1146`; `verify_evidence.py:16`; workflow `:105`, `:153` | Codigo de falla revisado, sin nueva inyeccion runtime |

Las rutas C# de la tabla estan en `backend/tests/Martha.Store.Api.Tests/`. Las del arnes estan en `tests/golden-path/` y el workflow en `.github/workflows/`.

El script actual tiene SHA-256 `8aacf56efaa92d3f7d6e3233c557c21f0ad55995df18eaa41ce8f5f688893da8`. Verifique que conserva el prefijo completo anterior y agrega 132 lineas. Ninguna migracion C# ni snapshot cambio desde antes de esa correccion. No detecte una migracion aplicada reescrita.

Los seis metodos focales C4 constan 1/1 en el JSON saneado. El total del artefacto es 601/601; ese total no sustituye la lectura de cada metodo.

Golden conserva una venta, una linea, una operacion de venta y stock 28 despues de replay, conflicto 409 y recuperacion. El replay exige el mismo saleId. Logout deja cero sesiones activas. Las invariantes SQL se ejecutan despues de cada paso exitoso con esquema disponible; una accion fallida conserva FAIL y termina el recorrido.

Cleanup registra API exit 0, base borrada, directorio privado retirado y cero fail/crit. Registra 38 warnings: no se afirma cero warnings. El binding contiene extractos de upload y ausencia del contenedor Golden. La guarda de creacion incierta exige revision del operador y nunca elimina una base sin propiedad confirmada.

La publicacion valida dos archivos contra un manifiesto de bytes exactos. Un fallo de sanitizacion retira esos archivos y marcador. Una ejecucion funcional fallida puede publicar evidencia saneada marcada FAIL; eso no es un exito inventado. El escaneo solo acredita secretos conocidos.

## Limites y entrega

No ejecute tests, build, SQL, API, Docker ni consultas remotas. No modifique checkout, indice, ledger, Trello ni estados TONY/C9. Los digests ZIP del binding proceden de API; no los recompute. Los hashes de archivos locales y blobs Git si se calcularon y estan en [evidence.json](evidence.json).

Changed: solo este informe y evidence.json. Verification: lectura de fuentes inmutables, historia Git, diferencias, artefactos y seis resultados nominales. Usage: tokens, coste y duracion exacta desconocidos. Unverified: CI d475, runtime Windows, datos reales, produccion y aceptacion operativa. Blockers: ninguno en el contrato tecnico revisado.

Next action: root verifica el dictamen y los hashes e integra bajo su carril. Mantener siete TONY en review y C9 blocked. No se revisaron C11, N5-COV ni C9.
