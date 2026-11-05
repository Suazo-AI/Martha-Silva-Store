# Detección de agentes al iniciar — 2026-11-04

Jason autorizó comprobar el trabajo del agente de T3 Code y avanzar en un área independiente.
La coordinación se verificó en SUAZO-PC. T3 conserva las simulaciones de fallas de SAVIA y su revisión.
Codex Desktop implementó únicamente el detector de agentes y sus adaptadores globales de arranque.
No se tocaron código, pruebas, Git index, rama ni documentos compartidos del checkout canónico de T3.
Esta evidencia se preparó en un worktree aislado, para integración/publicación serializada por su coordinador.

## Resultado comprobado

- Detector de solo lectura instalado en AI-OS/bin/agent-awareness.py.
- T3: proyecto, modelo, razonamiento y estado del último run por hilo, incluidos ejecutores delegados.
- Codex: metadatos y eventos de ciclo de tarea de colas acotadas; excluye la identidad propia conocida.
- Windows: procesos conocidos de harnesses. Una aplicación abierta no prueba trabajo activo.
- Hooks SessionStart añadidos a Codex y Claude; los grupos previos se conservaron.
- Comando de arranque añadido a seis adaptadores/instrucciones globales.
- Suite adversarial: 6/6 PASS; ambas invocaciones de hook con payload, exit 0, stderr vacío.
- Crítico gpt-6.1-sol/high y jurado gpt-6-astra/high. Dos hallazgos P2 del jurado corregidos y comprobados.
- Fuentes exportadas por copia exacta; sus SHA256 constan en verification.json. No son instaladores.

Comandos verificados:

```powershell
python C:/Users/Jason/AI-OS/tests/test_agent_awareness.py
python C:/Users/Jason/AI-OS/bin/agent-awareness.py --workspace C:/Users/Jason/MARTHA-SILVA/github
```

## Límites y pendientes

No es un candado ni un censo completo del PC. Es una fotografía temporal: reconsultar antes de escribir y al cambiar checkout.
Las proyecciones pueden sobrevivir a un worker caído. Claude/AGY/OpenCode tienen detección de proceso; actividad de tarea desconocida.
No se exportan conversaciones, prompts, comandos completos, secretos, bases ni configuraciones privadas.
No se cambiaron hashes de confianza de hooks. No hay daemon, tarea programada, llamada de modelo ni acceso de red en el detector.
No hubo SQL, Docker, certificados, merge ni despliegue.

**Pendiente de integración real:** observar la salida automática en una sesión nueva de Codex y otra de Claude.
La invocación directa pasó; no demuestra que el cliente haya cargado su hook.
Causa: no se reiniciaron clientes ni se abrió una nueva sesión real durante la verificación.
Owner: coordinador del siguiente arranque. Acción: abrir una sesión normal y comprobar el bloque AGENT AWARENESS.
Si el cliente solicita confianza, seguir su aprobación normal; no editar trusted_hashes.
Los demás harnesses usan instrucciones de arranque; sus hooks nativos no fueron instalados.

## Lección aplicada

Los primeros tests detectaron una consulta PowerShell mal formada y conexiones SQLite sin cerrar.
Se corrigieron ambas causas y se verificó la limpieza de fixtures en Windows.
El jurado reprodujo metadatos T3 inesperados y una base ausente con proceso activo.
Ahora ambos informan incertidumbre sin abortar ni afirmar ausencia de agentes.

Rollback local: quitar únicamente el comando agent-awareness.py de ambos SessionStart y los bloques marcados AGENT-AWARENESS-20261104.
Los originales están respaldados en AI-OS/backups/agent-awareness-20261104; preservar cambios posteriores.
La configuración y los snapshots locales permanecen fuera de Git. No se publica contenido de sesiones.
