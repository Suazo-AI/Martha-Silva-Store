# Playbook de recuperación y entrega

Objetivo: convertir una demo recuperada en un repositorio verificable y reutilizar el procedimiento sin copiar datos sensibles ni exagerar el resultado.

## Pipeline reutilizable

| Etapa | Acción | Evidencia y salida exigidas |
| --- | --- | --- |
| 1. Delimitar | Identificar original, demo mejorada, fuentes disponibles y destinos autorizados | Estado inicial, límites y rutas de trabajo |
| 2. Inventariar | Contar páginas, productos, variantes y referencias; separar metadatos de archivos | Manifiesto permitido y hashes de bytes presentes |
| 3. Preservar | Mantener historia, separar originales y trabajar en rama | Commit base; originales fuera del build corriente |
| 4. Sanear | Revisar archivos candidatos, excluir secretos y datos personales | Diff limitado y lista explícita de exclusiones |
| 5. Reconstruir | Ensamblar desde entradas versionadas, sin depender del equipo original | Dos builds con igualdad de rutas y bytes |
| 6. Comprobar | Pruebas unitarias/locales, DOM, estructura, assets y luego navegador | Comando, commit, resultado y límites por capa |
| 7. Integrar | Revisar cambios paralelos y repetir suite en conjunto | Commit integrado y árbol limpio |
| 8. Entregar | Push autorizado; comprobar SHA remoto y CI aplicable | Enlace real del repositorio y estado comprobado |
| 9. Publicar, si procede | Confirmar destino independiente, acceso y rollback | Evidencia del despliegue; nunca inferirlo del push |

## Registro de herramientas

| Herramienta / entrada | Uso permitido | Límite importante |
| --- | --- | --- |
| Git / worktrees | Historia, ramas y trabajo paralelo aislado | Una rama por ámbito; no borrar cambios ajenos |
| Python / `prepare.py` | Build del snapshot sin dependencias externas | No restaura el generador editorial histórico |
| `tests/check.py` | Suite agregada y fallo inmediato por etapa | Requiere Python, Node y jsdom instalado; Windows aún sin ejecución comprobada |
| Node / `tests/backend.cjs` | Adaptador local, validación y estado | No prueba un servidor, D1 ni pagos reales |
| jsdom / `tests/frontend-runtime.cjs` | Montajes y regresiones DOM | No prueba render, viewport ni foco nativo |
| `tools/audit_assets.py` | Presencia y hashes de medios permitidos | Sin bandera estricta no exige catálogo completo |
| REA / `research/rea/` | Evidencia estática sobre wrappers y SDK públicos | No ejecutar código de comercios ni enviar pagos |
| Navegador real | QA visual e interacción del candidato accesible | Registrar dispositivo, tamaño, origen y commit |

Las versiones de referencia y comandos de instalación están en [README](../README.md) y [tests](../tests/README.md). Las herramientas de staging incorporadas por otras áreas deben consultarse en su documentación propia antes de usarlas; no suponer opciones de CLI.

## Rutina antes de entregar

```sh
git status --short
python3 prepare.py
python3 tests/check.py                       # --install solo si faltan dependencias
python3 tools/audit_assets.py
git diff --check
git diff --stat
git diff                                # revisar contenido, no solo nombres
```

La auditoría puede actualizar evidencia: revisar el diff antes de incluirlo. Para exigir recuperación total sin sobrescribir el reporte versionado:

```sh
python3 tools/audit_assets.py --require-complete --output /tmp/martha-full-audit.json
```

Actualmente se espera que este último comando falle por faltantes. No reducir el manifiesto ni sustituir fotos para convertir el fallo en un supuesto éxito. Para una fuente nueva seguir el [procedimiento de importación](ASSET-COMPLETENESS.md).

Tras integrar, registrar el SHA con `git rev-parse HEAD`. Comparar contra la rama de destino mediante `git ls-remote <remoto-autorizado> refs/heads/<rama>` y revisar CI de ese SHA. Estos marcadores deben reemplazarse por el remoto y rama reales; no contienen un destino predeterminado. No añadir credenciales a URLs o registros.

## QA real pendiente

Cuando exista un navegador con acceso al candidato:

- Revisar las nueve páginas en escritorio y móvil: navegación, imágenes, cortes, scroll y ausencia de desbordamiento.
- Probar filtros y Atrás/Adelante; bolsa vacía y con artículos; cambios de cantidad, falta de stock y clics repetidos.
- Revisar zoom/dialog: Escape, cierre, foco de retorno y teclado; verificar lectura y controles accesibles.
- Probar checkout de **demo**, recarga, cancelación y estado inválido sin datos personales ni tarjetas reales.
- Revisar administración de demo, cierre de sesión y datos locales; no interpretarlo como control de acceso seguro.
- Guardar capturas y resultado del flujo junto a commit, navegador y viewport. Medir rendimiento antes de afirmar mejoras.

Si el destino exige login o no es accesible, registrar exactamente la pantalla o error. Eso no demuestra que el sitio esté caído ni autoriza eludir el acceso.

## Lo que funcionó / lo que debe evitarse

| Reutilizar | Evitar y por qué |
| --- | --- |
| Fuentes autocontenidas y build determinista | Dependencias de carpetas externas: impiden reproducir |
| Lista permitida, staging privado y hashes | Copia recursiva del equipo: arrastra datos y secretos |
| Catálogo original separado del demo pequeño | Publicar productos sin medios o inventario comprobado |
| Pruebas de estado inválido y clics repetidos | Verificar solo el camino feliz: oculta corrupción y carreras |
| Evidencia por nivel de prueba | Llamar navegador a jsdom: atribuye cobertura inexistente |
| Investigación de pagos sin ejecutar comercios | Confundir un SDK o logo con pagos integrados o elegibilidad |
| Mantener original y demo separados | Sobrescribir el original para probar una mejora |
| Resultado primero, bloqueo concreto después | Prometer una copia completa o enlace público sin verificación |

## Plantilla de registro de entrega

```text
Resultado:
Commit y rama:
Destino remoto y SHA confirmado:
Archivos/alcance:
Comandos y resultados:
CI: pasa / falla / pendiente / no configurada / no verificada
QA no ejecutada:
Bloqueo: acción + destino + motivo + estado
Siguiente condición de aceptación:
```

Este registro contiene evidencia técnica del proyecto, no conversaciones, notas privadas ni credenciales.

[Inicio](../README.md) · [Estado](PROJECT-STATUS.md) · [Decisiones](DECISIONS.md)
