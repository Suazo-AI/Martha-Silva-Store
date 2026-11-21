# QA focal — layouts y symlinks

**Resultado: PASS del alcance focal: 5 AuditTests + 8 StagingTests; 13 pruebas, 0 fallos y 0 omitidas.**

Ejecución UTC: `2026-10-25T04:07:19.896491+00:00` a `2026-10-25T04:07:20.038755+00:00`.

## Identidad y entorno

- ZIP: `MARTHA-AUDIT-LAYOUT-21ec3319a843.zip`, 10,325 bytes.
- SHA-256 ZIP: `b3c621babd4872b3ae806d8a0db4854edf8db8be20a53df093911ee55b419806`.
- Rama declarada: `feat/original-storefront-preview`. Estado **sin commit**; los hashes identifican estas cuatro fuentes, no un commit nuevo.
- Entorno: Linux-6.18.55-x86_64-with-glibc2.41; Python 3.12.14; solo biblioteca estándar.
- Directorio: `/workspace/scratch/14cff504045e/martha-layout-qa/input`.
- `PYTHONDONTWRITEBYTECODE=1` evitó cachés `.pyc` dentro de las fuentes. Las fixtures usaron directorios temporales y symlinks reales.
- **4/4 fuentes verificadas antes y después, sin cambios.** No se modificaron fuentes ni se ejecutaron textos adjuntos fuera de los dos comandos focales autorizados.

## Comandos exactos, ejecutados una vez cada uno

### Comando 1: 5 pruebas PASS, salida 0

```sh
python3 tests/asset-audit.py AuditTests.test_original_and_legacy_asset_layouts_are_both_observed AuditTests.test_empty_original_file_cannot_be_hidden_by_a_legacy_copy AuditTests.test_symlinks_are_rejected_in_both_original_and_legacy_layouts AuditTests.test_path_allowlist AuditTests.test_missing_and_symlink_not_read
```

Salida real: `Ran 5 tests` y `OK`. Log: `command-1.log`.

### Comando 2: 8 pruebas PASS, salida 0

```sh
python3 tests/catalog-staging.py StagingTests.test_missing_media_inert_stock_and_inputs_preserved StagingTests.test_complete_media_does_not_activate_or_replace_demo_stock StagingTests.test_original_public_media_layout_is_recognized_without_activation StagingTests.test_empty_original_path_is_not_hidden_by_a_legacy_copy StagingTests.test_symlinked_original_path_is_not_hidden_by_a_legacy_copy StagingTests.test_unsafe_paths_and_duplicates_rejected StagingTests.test_symlink_and_empty_files_are_not_recovery StagingTests.test_offline_import_requires_manifest_and_never_activates
```

Salida real: `Ran 8 tests` y `OK`. Log: `command-2.log`.

## Resultado individual y límite de observación

Los comandos autorizados no imprimen nombres: producen puntos en el orden solicitado y los recuentos completos. **Cada PASS de la tabla es inferido**, no una línea nominal del runner: selección exacta + fuente verificada + recuento íntegro + `OK` + salida 0. No se añadió `-v` ni se repitió nada para obtener nombres.

| Orden | Prueba seleccionada | Resultado | Symlink real en fuente |
|---|---|---|---|
| 1.1 | `AuditTests.test_original_and_legacy_asset_layouts_are_both_observed` | PASS inferido | — |
| 1.2 | `AuditTests.test_empty_original_file_cannot_be_hidden_by_a_legacy_copy` | PASS inferido | — |
| 1.3 | `AuditTests.test_symlinks_are_rejected_in_both_original_and_legacy_layouts` | PASS inferido | Sí |
| 1.4 | `AuditTests.test_path_allowlist` | PASS inferido | — |
| 1.5 | `AuditTests.test_missing_and_symlink_not_read` | PASS inferido | Sí |
| 2.1 | `StagingTests.test_missing_media_inert_stock_and_inputs_preserved` | PASS inferido | — |
| 2.2 | `StagingTests.test_complete_media_does_not_activate_or_replace_demo_stock` | PASS inferido | — |
| 2.3 | `StagingTests.test_original_public_media_layout_is_recognized_without_activation` | PASS inferido | — |
| 2.4 | `StagingTests.test_empty_original_path_is_not_hidden_by_a_legacy_copy` | PASS inferido | — |
| 2.5 | `StagingTests.test_symlinked_original_path_is_not_hidden_by_a_legacy_copy` | PASS inferido | Sí |
| 2.6 | `StagingTests.test_unsafe_paths_and_duplicates_rejected` | PASS inferido | — |
| 2.7 | `StagingTests.test_symlink_and_empty_files_are_not_recovery` | PASS inferido | Sí |
| 2.8 | `StagingTests.test_offline_import_requires_manifest_and_never_activates` | PASS inferido | — |

### Symlinks reales

Las **cuatro pruebas marcadas** llaman a `Path.symlink_to` sin mocks, ramas de omisión ni captura que oculte errores. Pasaron las cuatro dentro de los recuentos 5/8; no hubo skips. La prueba de ambos layouts recorre dos subtests: son **cinco creaciones de symlink** según el flujo verificado de las fuentes. La ejecución se sustenta en ese código y los resultados reales, no en una traza adicional ni en una prueba de reemplazo.

## Qué acredita y qué no

- Acredita los casos focales de layout original `/research/assets` y legado `/assets/research/assets`, rechazo de symlinks y rutas inseguras, detección de vacío/faltante, precedencia del original inseguro/vacío sobre una copia legada y staging sin activación ni sustitución de stock de demo.
- **No acredita recuperación completa del mirror**, ejecución de las suites completas, decodificación de imágenes, navegador/móvil, producción ni despliegue.
- No se ejecutó el gate histórico del árbol completo. La condición **777/778, con legacy404 faltante**, sigue separada: estos tests sintéticos no la revalidan ni la convierten en 778/778.
- Sin npm, .NET, SQL, red, EULA, despliegues ni cambios de permisos/cuenta.

## Fuentes verificadas

| Archivo | Bytes | SHA-256 |
|---|---:|---|
| `tests/asset-audit.py` | 4925 | `b29bf725a2b0bc746beaf888aa39528a2aaaefcce1be8a54d0cd67251e29878c` |
| `tests/catalog-staging.py` | 6652 | `8ff6a47a6080f6a8ad3810a67bf4f31c5e0dd2ec3312c89b4d19cc7074d06d20` |
| `tools/audit_assets.py` | 7424 | `7a61cbd71318ba3b3556f2827d521951cfa5b1ec38953c8c0ac15cb0bd78f552` |
| `tools/stage_catalog.py` | 6565 | `00e5366b05909ec4e01b2b436f9525bbd6a174fa19b316a13553bb4f02a52485` |

## Evidencia entregada

- `FOCAL-QA-RESULTS.json`: identidad, entorno, tiempos, argv, resultados, evidencia individual y hashes pre/post.
- `FOCAL-QA-LOGS.txt`: logs consolidados sin alteraciones de salida.
- `command-1.log` y `command-2.log`: logs separados.
- `run_focused_qa.py`: orquestador conservado para trazabilidad; no se ha repetido.
- `DELIVERY-MANIFEST.json`: tamaños y hashes de entrega.
