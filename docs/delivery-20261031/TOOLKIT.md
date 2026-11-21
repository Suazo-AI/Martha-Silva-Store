# Toolkit mínimo para el stack actual

> Corte histórico del 31 de octubre. Continuación al 2026-11-03: [AGENT-START](../AGENT-START.md),
> [validación reciente](../testing-20261103/README.md) y [estado vigente](../PROJECT-STATUS.md).
> Conservar el diagnóstico; no repetir pasos consumidos ni interpretar sus pendientes como hechos actuales.


Este toolkit selecciona lo que ya existe. No instala skills, agentes, MCPs, bases ni observabilidad nueva. Las recetas de producto son para futuros incrementos autorizados; los resultados de este encargo están en VERIFICATION.

## Herramientas y límites

| Trabajo | Herramienta / fuente | Qué demuestra |
| --- | --- | --- |
| Identificar candidato | Git + hashes SHA-256 de archivos locales | Exactamente qué se inspeccionó; no que funcione. |
| Localizar regla | `rg`, fuente directa y CodeGraph/graphify solo si ya existe índice | Política, ruta y dependencias implementadas. |
| Frontend | Node test runner, tests existentes `dev/savia-staff-ui/*.test.mjs` | Contratos de cliente, DOM simulado y estados. No navegador real. |
| Backend | .NET SDK `10.0.402`, proyecto API `net10.0`, EF SQL Server `10.0.13` | Compilación y comportamiento de los checks ejecutados. |
| Integridad | Casos SQL existentes + readbacks sanitizados en entorno autorizado | Efectos, rollback y concurrencia; fixtures no son producción. |
| UI real | Navegador/DevTools disponible; Playwright si ya está preparado | Click real, red, consola, teclado, viewport y recuperación. |
| Rendimiento | Performance/Network y plan real de SQL Server | Cuello de botella medido; no copiar EXPLAIN ANALYZE de PostgreSQL. |
| Registro | `tools/progress.py`, `.githooks/`, `docs/progress/` | Archivos publicados y SHA remoto; no aceptación del producto. |
| Investigación | GitHub read-only con referencias por SHA | Procedencia y prácticas seleccionadas; no autorización para ejecutarlas. |

## Comandos existentes

Directorio para todos los comandos:

```powershell
Set-Location -LiteralPath 'C:/Users/Jason/MARTHA-SILVA/github'
```

Identificar trabajo y revisar antes de tocarlo:

```powershell
git status --short --branch
git rev-parse HEAD
git diff --stat
git diff --cached --name-only
```

Pruebas de frontend interno, sin arrancar API:

```powershell
node --test dev/savia-staff-ui/auth.test.mjs dev/savia-staff-ui/branch-compat.test.mjs dev/savia-staff-ui/dom.test.mjs dev/savia-staff-ui/pagination.test.mjs dev/savia-staff-ui/commerce.test.mjs
```

`commerce.test.mjs` estaba sin seguimiento al inspeccionar. Antes de usar esta receta en otro checkout, comprobar que el candidato contiene todos los archivos. No publicar los cambios ajenos para hacerla reproducible.

Guardas .NET: el filtro de `.github/workflows/backend.yml` no basta para excluir SQL interno. Algunos tests internos carecen del Trait y se activan con variables heredadas. Ejecutar este bloque unido, solo después de revisar el candidato:

```powershell
$saviaSqlEnvironment = Get-ChildItem Env: | Where-Object {
    $_.Name -match '^(MARTHA_|SAVIA_INTERNAL_).*SQL' -and
    -not [string]::IsNullOrWhiteSpace($_.Value)
}
if ($saviaSqlEnvironment) {
    throw 'STOP: hay configuración SQL heredada. Revisar un entorno de pruebas aislado; no ejecutar esta receta.'
}
dotnet --version
dotnet restore backend/tests/Martha.Store.Api.Tests --locked-mode
if ($LASTEXITCODE -ne 0) { throw 'Restore falló. Conservar el error y resolver antes de probar.' }
dotnet test backend/tests/Martha.Store.Api.Tests --no-restore --configuration Release --filter 'Category!=SqlServer'
```

El restore puede acceder a la red. Verificar SDK y caché antes de instalar nada. La precondición aborta sin mostrar valores. No limpiar variables y continuar a ciegas. En el candidato inspeccionado, los opt-in SQL usan esas familias; volver a comprobar los atributos y fixtures si cambian. Esta receta no valida migraciones ni concede permiso SQL.

Registro e integridad de evidencia exportada:

```powershell
python tests/test_progress.py
python tools/export_progress.py --verify
```

Regresión histórica exigida por el repositorio:

```powershell
python tests/check.py
```

Este último comando reconstruye el snapshot y ejecuta simulaciones de tienda pública. Requiere jsdom ya instalado. Revisar cambios antes/después; no equivale a aceptación SAVIA. Un fallo de symlink Windows se registra como entorno del verificador, no como venta rota. No desactivar controles para hacerlo pasar.

Para publicar, revisar y añadir únicamente archivos propios del incremento. El hook genera su recibo y sincroniza `Tony`. Comprobar `.git/progress-sync.json` con estado `SYNCED`, comparar SHA remoto y revisar CI. Si falla, conservar commit; corregir causa antes de `python tools/progress.py publish`.

## CI: qué cubre realmente

| Workflow | Trigger observado | Límite |
| --- | --- | --- |
| `tony-snapshot.yml` | Push Tony / manual | Snapshot, sintaxis pública y regresiones históricas. |
| `progress.yml` | Push Tony | Recibo, guardas de sincronización y hashes exportados. |
| `backend.yml` | Push main, PR hacia main, manual | Guardas backend; SQL además exige main y contexto de confianza. Un push Tony no lo ejecuta. |

Propuesta posterior: cuando se incorpore un cambio interno, hacer que su check acotado existente corra en el candidato correspondiente. No cambiar ahora CI ni habilitar SQL para mejorar la apariencia del tablero.

## Rendimiento: convertir “milisegundos” en un contrato

Primero medir una tarea completa: abrir inventario, seleccionar artículo, registrar venta y obtener recibo. Registrar candidato, dispositivo, red, volumen, concurrencia, frío/caliente y errores.

Presupuestos iniciales **propuestos, no resultados actuales**:

| Medida | Umbral inicial | Cómo evitar una conclusión falsa |
| --- | --- | --- |
| LCP / INP / CLS | ≤2.5 s / ≤200 ms / ≤0.1 | Referencias de web.dev; percentil 75 en campo. Un ensayo local no representa población. |
| Lectura interna HTTP | p95 ≤300 ms | Medir al menos 100 lecturas, sin carga destructiva; misma red/datos. Ajustar contrato antes de optimizar si entorno real exige otro. |
| Venta → recibo confirmado | p95 ≤1 s | Propuesta de UX; lecturas y escrituras separadas. Requiere lote sintético autorizado, nunca ventas reales para benchmark. |
| Integridad y errores | Cero duplicados y cero éxitos inventados | Reducir latencia no permite omitir commit, permisos ni recuperación. |

Para 100 muestras, declarar percentil por rango más cercano: ordenar duraciones y tomar posición `ceil(0.95*n)`. Guardar muestras sanitizadas, no solo promedio. Comparar varios ensayos con las mismas condiciones; una mejora dentro del ruido no justifica complejidad.

Si hay lentitud, seguir la traza: navegador → red → API → SQL. Cambiar una causa medida. Repetir el mismo escenario. No introducir cache de permisos, saldo o precio de venta para alcanzar un número.

## Kit de arranque del siguiente agente

Leer README, NEXT-INCREMENT y solo las fuentes de N1–N10. Copiar la plantilla de tarea y el bug cuando corresponda. Confirmar candidato, permisos y entorno. Ejecutar un caso; resolver su bloqueo antes de ampliar.

Entregar comandos exactos, exit codes, evidencia del repro, cambio mínimo, readback, limitaciones y siguiente acción. La carpeta del área conserva el historial; las credenciales y autorizaciones permanecen privadas.
