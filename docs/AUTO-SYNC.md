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

## Importación histórica congelada de PR2

`tools/progress.py` admite exclusivamente los 16 SHA ya publicados entre
`20932d5c97f2caaafad7dc888879957791907f36` y
`88faa2dd0d51fc1c5089b721ba5b17c23d4d61d4`, enumerados en el código y en
[`progress-imports/pr2-88faa2dd.json`](progress-imports/pr2-88faa2dd.json).
El manifiesto fija árbol, padres, cambios, blobs Git y SHA256 de cada archivo.
Su SHA256 sobre los bytes LF almacenados por Git es
`22c5c476de48cddbb91801783dbedf74c0143f506da7995acdfcb786d8b08e15`.

La comprobación conserva los filtros de rutas, modos, tamaño y secretos.
Una alteración del manifiesto o de su alcance bloquea la publicación.
Los commits nuevos siguen necesitando exactamente un recibo generado por el hook.
La importación no fabrica recibos históricos ni acredita aceptación del producto.
No modifica historia, remotos, hooks ni configuración de seguridad.

### Reconciliación puntual autorizada de PR2

Jason autorizó conservar los dos historiales divergentes mediante un único commit
de unión, sin fusionar PR2 a `main` ni reescribir historia. El importador activo
añade exclusivamente `9719d8edc226d09aa09df1be02658236fceaf97c` a los 16 SHA anteriores.
El manifiesto original permanece congelado. El nuevo manifiesto
[`progress-imports/pr2-9719d8ed.json`](progress-imports/pr2-9719d8ed.json)
conserva esos 16 registros y fija árbol, padres y blobs del único SHA adicional.
Su SHA256 sobre bytes LF de Git es
`f279097cd07684fe66fce857a09dea06b42804cfc44e24aff759754a9955dc7b`.

El permiso no admite un SHA adicional ni un merge sin recibo. El commit de unión
y cualquier avance nuevo mantienen el recibo y todos los filtros habituales.
Los resultados de aceptación siguen separados de esta excepción histórica.

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
