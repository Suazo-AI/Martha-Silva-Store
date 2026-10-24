# Revisión opcional con no-mistakes

**Preparada, no instalada ni ejecutada.** No hay daemon, remote, hook o credencial
creados por esta integración. El ejemplo en `docs/no-mistakes.example.yaml` es
inerte. CI funciona independientemente y no instala agentes en runners de PR.

Proyecto solicitado: [kunchenguid/no-mistakes](https://github.com/kunchenguid/no-mistakes).
Se revisaron sus fuentes oficiales el 2026-10-24; hay que contrastarlas de nuevo
con la versión exacta que se instale.

## Advertencia importante

No es un linter de solo lectura: puede rebasar, editar, publicar ramas/PRs y
vigilar CI. El instalador arranca un daemon; `init` añade remote, hooks y una skill
a nivel de usuario. No ejecutar esos pasos como efecto secundario de una revisión.
[Inicio oficial](https://kunchenguid.github.io/no-mistakes/start-here/quick-start/).

El runner Codex usa por defecto un bypass de aprobaciones/sandbox. Antes de
cualquier ejecución, un operador autorizado debe revisar la configuración local
`~/.no-mistakes/config.yaml` y establecer explícitamente:

```yaml
agent: codex
agent_args_override:
  codex:
    - --sandbox
    - workspace-write
```

La documentación confirma que `--sandbox` suprime el bypass predeterminado.
No copiar modelos, tokens ni flags de bypass. Revisar también argumentos ya
existentes, configuración heredada y comando efectivo. Esto limita Codex, **no**
convierte el daemon ni sus comandos de shell en un sandbox. Si el modo restringido
no puede completar una fase, detenerse, no relanzar sin protección.
[Referencia global](https://kunchenguid.github.io/no-mistakes/reference/global-config/).

## Configuración del proyecto

El ejemplo selecciona Codex y nuestra suite portable; mantiene CI obligatorio y
no permite comandos provenientes de ramas no confiables. Para activarlo, revisar
y llevarlo como `.no-mistakes.yaml` a la rama predeterminada: los controles de
agente/comandos se leen de esa rama. Los presupuestos cero desactivan bucles de
reparación, **no** todas las modificaciones iniciales. La intención no se publica
en la descripción generada del PR.
[Configuración oficial](https://kunchenguid.github.io/no-mistakes/reference/repo-config/).

## Una sola puerta de publicación

El autosync de `docs/AUTO-SYNC.md` queda **desactivado**. No instalar su
`post-commit` ni ejecutar `tools/sync_progress.py` durante un flujo no-mistakes.
Además, ese helper exige repo privado y no corresponde al período público de
construcción. No quitar su control de visibilidad para forzar publicación.

Antes de activar no-mistakes: inspeccionar `git config --show-origin --get
core.hooksPath` y los hooks existentes. Si autosync estaba activo, restaurar con
cuidado la configuración anterior según su documentación; no borrar hooks ajenos.
Los worktrees pueden compartir configuración. No combinar ambos publicadores,
no configurar hooks globales, no hacer doble push ni saltarse una puerta fallida.

## Entrada explícita, solo tras autorización y preparación

1. Revisar una release oficial, su integridad y efectos; acordar host y permisos
   para instalación, daemon, autenticación, ediciones, rebase y publicación.
2. Preparar el override seguro anterior. Verificar Codex autenticado y ejecutable,
   Git/gh y transporte Git hacia `Suazo-AI/Martha-Silva-Store`, sin guardar secretos
   en el repositorio. Desactivar telemetría con `NO_MISTAKES_TELEMETRY=0` en el host.
3. Tras instalación autorizada: `no-mistakes doctor`; inspeccionar su resultado.
   Solo entonces inicializar con `no-mistakes init` y verificar remote/hooks.
4. En una **rama de trabajo**, con commits revisados, ejecutar explícitamente
   `git push no-mistakes <rama>`. Esto inicia un flujo que puede publicar; no es
   una prueba local inocua. Nunca iniciarlo en `main` ni con aprobación automática.
5. Inspeccionar diferencias, responder hallazgos sin omitir fallos, verificar SHA
   publicado, PR y ambos checks de CI. No afirmar revisión realizada antes.

No se ejecutó esta secuencia. Bloqueo actual: falta instalación autorizada y
verificación del runner, sandbox, credenciales/transporte y primera ejecución en
el host elegido. Hasta entonces usar la suite local y CI; no afirmar que
no-mistakes aprobó el código ni sustituir revisión humana o reglas de rama.
