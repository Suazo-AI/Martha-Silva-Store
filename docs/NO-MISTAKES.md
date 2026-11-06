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
5. En la rama de un PR propio, ejecutar `git push no-mistakes <rama-de-trabajo>`. Revisar los hallazgos y el diff que se publicará; el proxy puede editar, actualizar el PR y publicar reparaciones. No dirigirlo a `main`, `Tony` ni ramas de otra persona. Cero reintentos de reparación en la política no impide todas las ediciones iniciales. No omitir fases ni escribir la atestación a mano.

## Cierre verificable

- Registrar URL del PR, SHA publicado, corrida del daemon y evidencia de la prueba específica del cambio. Para UI, revisar la captura antes de compartirla. Redactar datos personales y credenciales.
- Verificar el check **PR must be raised via no-mistakes**, `build-and-guards` y los demás checks requeridos en el SHA del PR. Repetir la evaluación si se modifica el cuerpo o se añade un commit.
- Antes del primer merge: ejercer un rechazo real sin declaración y un pase real producido por el CLI sobre la rama. Un fixture positivo solo verifica el parser. La política local de `.no-mistakes.yaml` se lee de `origin/main`; antes de su primera integración se usa el perfil seguro del operador.
- Los PR abiertos antes de la adopción deben incorporar la base vigente y emitir los checks nuevos. En el corte de preparación, cuatro de los siete checks de `main` están definidos en el PR de integración SAVIA y no en la base antigua. No marcar pendientes como aprobados: coordinar la incorporación de esos workflows o apilar este cambio en la rama de integración para probar juntos el resultado antes del merge final.
- Rollback: revertir este incremento mediante un PR revisado; ninguna regla de rama se reemplazó. En la máquina, `no-mistakes eject` pertenece solo al clon dedicado. No detener un servicio compartido ni borrar estado de otros proyectos.

[Release e integridad](https://github.com/kunchenguid/no-mistakes/releases/tag/v1.106.1) · [configuración fijada](https://github.com/kunchenguid/no-mistakes/blob/5732d1ed88a1572fa6115d6ede5d69bfec097946/docs/src/content/docs/reference/repo-config.md) · [argumentos de Codex](https://github.com/kunchenguid/no-mistakes/blob/5732d1ed88a1572fa6115d6ede5d69bfec097946/docs/src/content/docs/reference/global-config.md). Las verificaciones históricas de v1.84.0 (Linux) y v1.57.0 (SUAZO-PC) no prueban la instalación de esta versión en Windows.
