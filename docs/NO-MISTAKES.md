# Verificar PR con no-mistakes

Este es el procedimiento de revisión de ramas de trabajo de Martha Silva/SAVIA. La política del repositorio queda vigente al integrar este cambio en la rama predeterminada. El equipo que ejecuta Codex y el verificador de GitHub tienen funciones diferentes.

## Qué exige GitHub

El workflow `.github/workflows/backend.yml` ejecuta la [acción oficial v1.106.1](https://github.com/kunchenguid/no-mistakes/tree/5732d1ed88a1572fa6115d6ede5d69bfec097946/.github/actions/require-no-mistakes) al abrir, editar, reabrir, actualizar o sacar de borrador un PR. Lee el cuerpo y el SHA **actuales**. Requiere review, test y document completados, sin exenciones por autor, rama o ruta. No hace checkout ni usa secretos del comercio.

En PRs hacia `main`, el job ya obligatorio `build-and-guards` comprueba explícitamente el resultado: si el verificador falla, se cancela o se omite, el job falla. Si pasa, aún debe ejecutar las pruebas originales. Se mantienen los otros seis checks exigidos en `main`; no se necesita sustituir la protección ni desactivar checks para adoptar este cambio. En otras ramas se informa el resultado; solo una rama protegida puede impedir el merge. Ni una declaración editable del autor ni un check verde demuestran que no haya errores.

## Preparar el ejecutor Windows (SUAZO-PC)

Usar un clon independiente, bajo una cuenta de desarrollo sin secretos productivos. El checkout canónico de `Tony` conserva AUTO-SYNC y sus recibos. No usar un worktree que comparta su configuración Git. Si ya hay un daemon/servicio no-mistakes de otra versión o perfil bajo la misma cuenta, identificar su propietario y resolver el aislamiento antes de iniciar otro. No reemplazarlo.

1. Obtener el instalador de este cambio revisado en `tools/install-no-mistakes.ps1`. Verifica el SHA256 del ZIP oficial apropiado para x64 o ARM64 y después versión/commit. La instalación no altera el PATH persistente, no autentica cuentas y no ejecuta agentes. En PowerShell:

   ```powershell
   $nm = (.\tools\install-no-mistakes.ps1).Executable
   & $nm --version    # v1.106.1 (5732d1e)
   $env:PATH = (Split-Path $nm) + ';' + $env:PATH
   $env:NO_MISTAKES_TELEMETRY = '0'
   $env:NO_MISTAKES_NO_UPDATE_CHECK = '1'
   $env:NM_HOME = Join-Path $env:LOCALAPPDATA 'SAVIA-no-mistakes-state'
   ```

2. En este perfil privado de `NM_HOME` crear `config.yaml` con el siguiente contenido, o revisar el existente **sin sobrescribirlo**. Confirmar que no se hereda un bypass de sandbox y que el daemon y los comandos de shell solo tienen acceso de desarrollo. La restricción de Codex no aísla el daemon entero.

   ```yaml
   agent: codex
   agent_args_override:
     codex: ["--sandbox", "workspace-write"]
   ```

3. Comprobar Git, `gh auth status`, Codex autenticado, permisos del repositorio y URL de `origin` en el clon dedicado. No imprimir tokens. Revisar `git config --show-origin --get core.hooksPath`, `git config --get progress.autopush` y hooks instalados. Detenerse si existe otro publicador en el clon. Usar la misma configuración y binario en las sesiones posteriores.
4. Desde ese clon, con su propia rama de trabajo, ejecutar `no-mistakes init --skip-user-skill`. **Esto sí inicia el daemon** y crea la puerta y el remote local; puede registrar un servicio. No ejecutar este paso en el checkout de Tony. Ejecutar `no-mistakes doctor` y revisar el texto: se necesita agente ejecutable, daemon operativo, Git y acceso efectivo a GitHub. Un código cero de doctor no basta.
5. En la rama propia de cada PR, fijar explícitamente su destino. Esto importa para el arranque: #6 apunta a la rama de #2; #2 y #5 apuntan a `main`. El comando genérico puede calcular el alcance contra la rama predeterminada. No cambiar la base de un PR para que pase. Si el destino acordado cambió, revisar el nuevo diff antes de iniciar otra corrida.

   Desde el clon dedicado, elegir el número, destino e intención del PR. Este ejemplo es **solo para #6**:

   ```powershell
   $repo = 'Suazo-AI/Martha-Silva-Store'
   $number = 6
   $target = 'claude/funny-brahmagupta-5e5rj0'
   $intent = 'Comprobar que un PR sin revisión, prueba y documentación del último commit queda rechazado y que se preservan los controles de SAVIA.'
   $before = gh pr view $number --repo $repo --json number,url,state,baseRefName,headRefName,headRefOid,isCrossRepository | ConvertFrom-Json
   if ($LASTEXITCODE -ne 0 -or $before.state -ne 'OPEN' -or $before.isCrossRepository -or $before.baseRefName -cne $target) { throw 'PR o destino inesperado.' }
   if ((git branch --show-current) -cne $before.headRefName -or (git rev-parse HEAD) -cne $before.headRefOid -or (git status --porcelain)) { throw 'Se necesita la rama propia, limpia y en el SHA del PR.' }
   $before | Format-List url,baseRefName,headRefName,headRefOid
   & $nm axi run --intent $intent --base-branch $target --no-publish-intent
   if ($LASTEXITCODE -ne 0) { throw 'Inspeccionar el diagnóstico. No se acredita ningún pase.' }
   ```

   La devolución puede ser `gate:` (pendiente de decisión), `checks-passed` (comprobación CI completa, todavía sin merge), `passed-with-skips` (verificación omitida) o `passed-with-override` (excepción). Ejecutar `no-mistakes axi status` para conocer el estado real. Ante `gate:`, consultar los hallazgos y responder solo con una decisión justificada mediante `no-mistakes axi respond`; no utilizar `--yes` ni autorizar excepciones automáticamente. Reanudar con `no-mistakes axi run` solo cuando corresponda a la corrida estacionada. Si ya alcanzó `checks-passed` y sigue monitoreando el PR, **no** iniciar otra corrida ni hacer rebase manual; el operador puede usar `no-mistakes axi handoff` para cerrar el monitoreo sin fusionar. Un exit code cero con verificaciones omitidas o excepciones no acredita READY. Al terminar, releer número, URL, base y SHA (`gh pr view` como arriba). Deben ser el mismo PR y destino, y el nuevo SHA debe coincidir con el head revisado y la evidencia del CLI. El proxy puede editar y publicar reparaciones en la rama de trabajo. No omitir fases ni añadir la atestación a mano. [Referencia del CLI fijado](https://github.com/kunchenguid/no-mistakes/blob/5732d1ed88a1572fa6115d6ede5d69bfec097946/docs/src/content/docs/reference/cli.md#no-mistakes-axi-run).

## Cierre verificable

- Registrar URL del PR, SHA publicado, corrida del daemon y evidencia de la prueba específica del cambio. Para UI, revisar la captura antes de compartirla. Redactar datos personales y credenciales.
- Verificar el check **PR must be raised via no-mistakes**, `build-and-guards` y los demás checks requeridos en el SHA del PR. Repetir la evaluación si se modifica el cuerpo o se añade un commit.
- Antes del primer merge: ejercer un rechazo real sin declaración y un pase real producido por el CLI sobre la rama. Un fixture positivo solo verifica el parser. La política local de `.no-mistakes.yaml` se lee de `origin/main`; antes de su primera integración se usa el perfil seguro del operador.
- Los PR abiertos antes de la adopción deben incorporar la base vigente y emitir los checks nuevos. En el corte de preparación, cuatro de los siete checks de `main` están definidos en el PR de integración SAVIA y no en la base antigua. No marcar pendientes como aprobados: coordinar la incorporación de esos workflows o apilar este cambio en la rama de integración para probar juntos el resultado antes del merge final.
- Rollback: revertir este incremento mediante un PR revisado; ninguna regla de rama se reemplazó. En la máquina, `no-mistakes eject` pertenece solo al clon dedicado. No detener un servicio compartido ni borrar estado de otros proyectos.

[Release e integridad](https://github.com/kunchenguid/no-mistakes/releases/tag/v1.106.1) · [configuración fijada](https://github.com/kunchenguid/no-mistakes/blob/5732d1ed88a1572fa6115d6ede5d69bfec097946/docs/src/content/docs/reference/repo-config.md) · [argumentos de Codex](https://github.com/kunchenguid/no-mistakes/blob/5732d1ed88a1572fa6115d6ede5d69bfec097946/docs/src/content/docs/reference/global-config.md). Las verificaciones históricas de v1.84.0 (Linux) y v1.57.0 (SUAZO-PC) no prueban la instalación de esta versión en Windows.
