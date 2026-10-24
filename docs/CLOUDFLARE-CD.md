# CD aislado de la demo (no producción)

Destino único: **`martha-silva-preview`**, Worker nuevo de assets estáticos.
El original `martha-silva-demo` y sus rutas/bindings no se modifican. No se
activa GitHub Pages ni pagos/backend. El sitio publicado será público; no
introducir datos reales de clientes. Esta configuración por sí sola **no
significa que haya un despliegue ni una conexión de escritura autorizada**.

## Activación deliberada

1. La conexión persistente está autorizada **solo para el nuevo Worker**, no
   para Admin amplio. Confirmar externamente cuenta y destino nuevos; el acceso
   Cloudflare comprobado sigue siendo de solo lectura y `gh` CLI no está
   autenticado. No reutilizar el token histórico/de solo lectura.
2. Un administrador autorizado debe crear **solo** `martha-silva-preview` y
   habilitar su subdominio workers.dev. Crear un Worker requiere rol Admin a
   nivel Workers: ese permiso amplio no está autorizado por el alcance actual.
   El bootstrap requiere intervención de un administrador ya autorizado o
   aprobación separada; no dar ese permiso amplio permanentemente a CI.
3. Crear un token dedicado con **Editor únicamente sobre ese Worker existente**,
   limitado a la cuenta elegida. No necesita rutas de zona, D1, KV, pagos ni
   acceso al Worker original. Guardarlo directamente como secreto de Actions
   `CLOUDFLARE_PREVIEW_API_TOKEN`; nunca en chat, comandos, logs o Git.
4. Configurar las variables de repositorio `CLOUDFLARE_ACCOUNT_ID` y
   `CLOUDFLARE_PREVIEW_URL` (la URL HTTPS real devuelta por Cloudflare, con forma
   `https://martha-silva-preview.<subdominio>.workers.dev`). No hay cuenta ni URL
   real codificadas en el repositorio.
   La URL se valida offline antes del token/deploy, pero su forma no demuestra
   asociación con `CLOUDFLARE_ACCOUNT_ID`. La comprobación externa de esa
   asociación y del alcance del token es un gate obligatorio de activación.
5. Solo después de revisar destino/permisos, establecer
   `CLOUDFLARE_DEPLOY_ENABLED=true`. Ejecutar el workflow en **main** o enviar
   un cambio aprobado a main. Si falta el token, el job informa que no despliega.
   Proteger main y revisar cambios de workflow/config antes de integrarlos.

## Cadena verificable

Los checks existentes pasan en Ubuntu **y** Windows. Después se ensambla un
artefacto `recovered-demo-<SHA>` y se incorpora `deployment.json` con SHA completo
más hashes SHA-256. El job de deploy depende de ambos jobs, nunca corre para PR,
y descarga el artefacto de **esa misma ejecución**, no reconstruye la tienda.
Elimina primero el dist versionado para impedir mezclas. Verifica inventario,
SHA, URL y empaquetado sin credenciales antes de exponer el token al control
de presencia y al paso deploy. Solo el marcador raíz se excluye del inventario;
los marcadores anidados se incluyen y los enlaces simbólicos se rechazan.
Justo antes comprueba por lectura remota que main no haya avanzado; rechaza runs
ya obsoletos. Es una salvaguarda **no atómica**, no una garantía absoluta:
main puede avanzar entre esa lectura y la escritura remota.
Wrangler oficial está fijado en 4.152.0 con lockfile; las acciones están fijadas
por SHA. No hay GitHub write permissions, rutas, Worker histórico ni bindings.
La concurrencia serializa el destino sin cancelar un deploy a mitad de escritura;
los jobs tienen timeout. El manifiesto de release es público, sin datos privados.

La comprobación HTTP posterior compara el marcador y cinco assets con el
artefacto y exige 404 para una ruta inexistente. Tolera propagación hasta seis
intentos con pausas de diez segundos y timeout por petición. No usa credenciales,
no envía pedidos y no equivale a QA visual, de accesibilidad o de pagos.
Rechaza redirecciones fuera del origen HTTPS aprobado antes de seguirlas;
permite normalizaciones en el mismo origen. 401/403 y redirecciones inseguras
fallan sin reintento.
Un fallo de smoke deja el workflow rojo; **no revierte automáticamente**.
Guardar SHA, versión/URL emitidas por Wrangler y resultado de smoke como evidencia.

Actions run [`40136425925`](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/40136425925) para `f22276a`: Ubuntu, Windows y artefacto **PASS**;
despliegue **SKIPPED**. No demuestra escritura Cloudflare ni URL publicada.

## Verificación local (sin acceso Cloudflare)

```sh
npm ci --ignore-scripts --no-audit --no-fund
python3 tests/test_deployment.py
npm run deploy:check
```

`--dry-run` valida configuración/empaquetado, no permisos remotos ni publicación.
Para probar un artefacto separado: ejecutar prepare.py con un directorio vacío,
`tools/deployment.py stamp --directory <salida> --sha <SHA-completo>`, y luego
`verify` con los mismos argumentos. Nunca desplegar originales/cloudflare.

## Detención y rollback

1. Poner `CLOUDFLARE_DEPLOY_ENABLED=false` para impedir nuevos jobs y comprobar
   que no haya despliegues en curso; deshabilitar la variable no cancela uno activo.
2. En Cloudflare, seleccionar **martha-silva-preview > Deployments**. Identificar
   por la evidencia anterior una versión buena y usar **Rollback**. Verificar
   nombre/cuenta antes de confirmar; nunca seleccionar `martha-silva-demo`.
3. Repetir smoke contra el artefacto/SHA de esa versión. Si expiró el artefacto
   (retención 7 días), reconstruir desde ese commit limpio, verificar suite y
   comparar el release marcador antes de declarar recuperación.
4. Revertir por un commit revisado el cambio defectuoso en main, ejecutar QA y
   reactivar la variable solo tras verificar el destino. No force-push.

Rollback restaura una versión, no datos de recursos conectados; aquí no hay
bindings de datos. En el primer despliegue no existe una versión anterior:
no inventar un rollback; detener CD y solicitar una retirada del nuevo preview
si resulta necesaria. Revocar el token dedicado cuando se retire la conexión.

## Referencias oficiales verificadas (2026-10-24)

- [Static Assets](https://developers.cloudflare.com/workers/static-assets/)
- [Configuración Wrangler: assets](https://developers.cloudflare.com/workers/wrangler/configuration/#assets)
- [CI/CD con GitHub Actions y autenticación](https://developers.cloudflare.com/workers/ci-cd/external-cicd/github-actions/)
- [Roles por Worker, bootstrap y permisos mínimos](https://developers.cloudflare.com/workers/authorization/workers/)
- [Rollback y límites](https://developers.cloudflare.com/workers/versions-and-deployments/rollbacks/)
