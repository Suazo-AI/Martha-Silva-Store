# Registro y sincronización de avances

Destino autorizado: rama `Tony` de `Suazo-AI/Martha-Silva-Store`, repositorio público.
El mecanismo es local a este checkout. No usa un servicio ni un vigilante de archivos.

1. El agente documenta resultado, comprobación, límites y siguiente acción en el documento del área.
2. El agente revisa y añade únicamente los archivos de ese avance al índice Git.
3. `pre-commit` inspecciona los bytes del índice y agrega un recibo en `docs/progress/`.
4. `post-commit` verifica los commits pendientes y hace push sin force a `Tony`.
5. El hook compara el SHA remoto y guarda el resultado en `.git/progress-sync.json`.
6. GitHub Actions comprueba el recibo, las pruebas del hook y los hashes de evidencia.

Cada recibo enumera archivos y blobs Git. `NOT_RUN_BY_HOOK` significa que el hook
no ejecutó pruebas del producto. La evidencia de las pruebas debe quedar en la documentación.
Un commit no demuestra aceptación visual, comercial, de seguridad ni del piloto.

El hook bloquea rutas sensibles, tipos de archivo peligrosos, enlaces simbólicos,
archivos mayores de 8 MiB y algunos formatos de credenciales. Es un filtro conservador;
no garantiza detectar todo secreto o dato personal. Revisar el diff sigue siendo obligatorio.
No ejecuta Docker, SQL, scripts del producto, despliegues ni pruebas pesadas.
No incluye archivos sin stage y no crea commits por pulsación de tecla.

## Activación en otro checkout confiable

Git no instala hooks al clonar. Revisar primero `.githooks/` y `tools/progress.py`.
Se necesitan Git, Python 3, GitHub CLI autenticada y autorización para publicar en este repositorio público.
Desde `Tony`, con `origin/Tony` actualizado:

```sh
python tests/test_progress.py
python tools/progress.py install
git config --show-origin --get core.hooksPath
git config --local --get progress.autopush
```

La instalación solo cambia `core.hooksPath=.githooks` y `progress.autopush=true`
en la configuración local del repositorio. Rechaza otro hook local ya instalado.
Las credenciales se consultan mediante `gh auth git-credential` para un único push.
No modifica el helper global ni imprime tokens.

## Fallo o divergencia

Un fallo de `post-commit` conserva el commit local. Git puede devolver éxito aunque
el push falle. Solo `SYNCED` con SHA remoto coincidente acredita sincronización.
No hay reintentos ocultos ni force-push. Si otro equipo avanzó `Tony`, revisar la
divergencia y reconciliar los cambios antes de volver a publicar.

Después de corregir la causa:

```sh
python tools/progress.py publish
```

Si el hook creó un recibo y después cambió el índice, retirar solo ese recibo nuevo
del índice y del disco antes de regenerarlo. No editar recibos ya publicados.
Si se detecta un secreto en historia pendiente, sanear toda esa historia antes del push.

## Desactivar y restaurar

Para detener el push automático y conservar el registro:

```sh
git config --local progress.autopush false
```

Si antes no había un hook local, retirar la configuración añadida:

```sh
git config --local --unset core.hooksPath
git config --local --unset progress.autopush
```

Si existía un valor anterior, restaurar ese valor exacto. No cambiar configuración global.
`tools/sync_progress.py` y sus pruebas quedan como implementación histórica inactiva
para `main` privado; los hooks actuales usan `tools/progress.py`.
