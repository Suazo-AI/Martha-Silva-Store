# C6: corrección candidata; aceptación final de CI pendiente

Lote: `20261103`. Host de edición: SUAZO-PC. Ejecutor seleccionado por Jason: `gpt-6.1-sol / xhigh`.
Tarjeta: https://trello.com/c/ezVfv0Pk. Integración destino: PR #2 de `Suazo-AI/Martha-Silva-Store`.
Base: `260b75951729189d987ffe423218ab1643bcfa3c`.
Rama de trabajo: `task/c6-browser-sql-20261103`.
Worktree: `C:/Users/Jason/MARTHA-SILVA/test-runs/c6-browser-sql-20261103`.

Resultado actual: candidato corregido y **33/33 pruebas ligeras PASS**.
CI `41757409404` del candidato anterior falló solo en logout; ver diagnóstico y delta exacto al final.
Chrome → API HTTPS → SQL real: **NOT RUN** en este host.
C6 no queda aceptada ni se declara lista para producción con estas comprobaciones.

## Cambios

| Ruta | Cambio |
| --- | --- |
| `tests/golden-path/golden_path.py` | Modo `browser`; protocolo privado y allowlist; checkpoints con oráculos existentes; límite de 300 s; cierre idempotente del grupo propio de Node/Chrome; metadatos saneados en evidencia existente |
| `tests/golden-path/browser_path.mjs` | Login Cashier real; stock; venta cantidad 2; recibo/recarga; venta cantidad 1 con respuesta HTTP 200 descartada mediante CDP; pendiente conservada y recuperación GET; otra recarga; stock; logout |
| `tests/test_golden_path_browser_safety.py` | 12 casos adversariales sobre frontera de evidencia, orden, barrera SQL, timeout y retirada del grupo propio |
| `tests/golden-path/README.md` | Interfaz reproducible, 11 checkpoints de navegador, seguridad y límites |
| `docs/c6-e2e-20261103/implementation.md` | Este resultado, evidencia y siguiente acción |

No se cambió producto, UI, backend, paquetes, lockfiles ni configuración.
El workflow pertenece al coordinador y se revisó únicamente en su copia scratch.
No se hicieron commits, push, instalaciones, SQL, arranques, Docker ni cambios de certificados.
No se tocaron `validation/` ni `outputs/` históricos.

## Contrato que debe comprobar CI

Se reutilizan exactamente setup, migrador EF de release, consola Owner, seed HTTP, `step`, oráculos,
escaneo, manifiesto y retirada de C5. `smoke` sigue siendo predeterminado; `serve` conserva su contrato.
La corrida browser planea 9 pasos de preparación, 11 checkpoints de navegador y 1 retirada.

1. Cashier inicia sesión mediante la UI real. `__Host-Savia.Session` exige Secure/HttpOnly/Strict, host loopback y Path=/.
2. Los seis recursos UI servidos por la API deben tener los mismos hashes que las fuentes actuales.
3. El inventario DOM debe mostrar 3 saldos y existencia total 30.
4. El formulario envía cantidad 2, ubicación y artículo, sin precio ni total. El recibo exige precio 1250 y total 2500 del servidor.
5. SQL debe ver 1 venta, 1 línea, 1 movimiento de venta, 1 operación y existencia 28.
6. Recarga y stock conservan recibo y conteos; no aparece otro POST de venta.
7. Otra venta de cantidad 1 usa otra clave. Chrome envía el POST al servidor real.
8. CDP pausa la respuesta real en `requestStage: Response`; exige HTTP 200 y recibo válido antes de `Fetch.failRequest`.
9. La UI debe mostrar pendiente, conservar la clave original y bloquear la venta nueva.
10. **Antes de permitir la recarga**, Python exige en SQL 2 ventas/líneas/movimientos de venta/operaciones y existencia 27.
11. Recarga recupera la misma venta mediante GET operations y la misma clave. Otra recarga conserva el recibo.
12. Ambas recargas y la consulta de stock conservan los conteos de negocio y exactamente 2 POST acumulados.
13. Logout deja 0 sesiones. Cada checkpoint exige 2 migraciones y cero violaciones de los 8 invariantes existentes.
14. La retirada debe detener API, borrar solo la base cuya creación fue confirmada y verificar ausencia; CI retira su contenedor propio.

La prueba adversarial usa datos simulados para afirmar que **la barrera rechaza** una supuesta segunda venta
comprometida cuando el oráculo solo ve una. No acredita que una venta SQL haya ocurrido.
El transporte no usa `route.fetch`, reenvíos, respuestas fabricadas ni API simulada.

## Evidencia y privacidad

`evidence.json` y `oracles.md` incluyen runtime Chrome/Node/Playwright; SHA-256 del arnés, ejecutor JS,
seis fuentes UI y binario Release; DOM comprobado; método/ruta sin query; HTTP y claves de operación.
La respuesta perdida se marca únicamente después de leer el recibo real en memoria.
El protocolo rechaza campos extra, rutas arbitrarias, claves no UUID y estados fuera de orden.

Credenciales solo viajan por stdin privado; cookies y CSRF se añaden al escáner de valores conocidos.
No se emiten cuerpos, cabeceras, conexiones, excepciones crudas, perfiles ni login recordings.
No se graban trace/HAR. Solo se publican los dos archivos verificados por `verify_evidence.py`.
El manifiesto `evidence-approved` conserva la promoción de bytes exactos y el cierre ante fallo.
El escaneo de valores conocidos no demuestra ausencia de secretos desconocidos.

Chrome recibe solo el SPKI del certificado efímero en un perfil privado nuevo.
No se modifica un almacén de confianza ni se usa `ignoreHTTPSErrors` o bypass TLS global.
Se bloquean peticiones fuera del origen HTTPS loopback.
Python limita el subprocess a 300 segundos y termina su grupo propio incluso ante fallo.
La incertidumbre de propiedad de la base conserva la política C5: no borrar una base sin confirmación de creación.

## Comprobaciones iniciales, anteriores al CI

| Comando / lectura | Resultado real | Límite |
| --- | --- | --- |
| `python -m unittest discover -s tests -p 'test_golden_path*_safety.py'` | `Ran 29 tests in 0.292s`, `OK`, exit 0: 17 C5 + 12 C6 | Dobles de proceso/SQL; sin runtime |
| `node --check tests/golden-path/browser_path.mjs` | Exit 0; sin salida | Solo sintaxis |
| `ast.parse` de `golden_path.py` y `test_golden_path_browser_safety.py` | `PYTHON_AST_OK 2 files`, exit 0 | No ejecuta POSIX/API/SQL |
| `git diff --check` | Sin errores de whitespace | No es aceptación funcional |
| Importación del Playwright instalado y `expect.configure({timeout:15000})` | `version=1.62.1`, `configure=function`, `configured=function` | CI solicita 1.63.0; esa versión no se ejecutó localmente |
| Tipos CDP del Playwright instalado | `requestStage`, `getResponseBody`, `failRequest` presentes | Contrato de API; sin ejercitar Chrome |
| `yaml.safe_load` del workflow scratch del coordinador | 17 pasos; una invocación `--mode browser` | Sintaxis YAML/estructura; no es actionlint ni ejecución Actions |

Paquete existente inspeccionado:
`C:/Users/Jason/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright`.
Workflow scratch leído:
`C:/Users/Jason/MARTHA-SILVA/coordination/c6-browser-sql-20261103/golden-path.yml`.

## Fallas resueltas y siguiente comprobación

| Evidencia / causa | Corrección aplicada y resultado | Dueño / cierre |
| --- | --- | --- |
| Primera corrida: 28 OK, 1 ERROR; Windows carece de `signal.SIGKILL` en el doble POSIX | El test fija la constante solo en su mock. Nueva corrida: 29/29 OK. El runtime sigue limitado a Linux/macOS | Resuelto en pruebas; no se cambió la política de proceso real |
| Revisión detectó `expect.setTimeout` sin contrato garantizado | Se usa `expect.configure({timeout:15000})`; importación real local confirma ambas funciones | Resuelto; versión CI 1.63.0 pendiente de CI |
| Doble señalización por `finally` y `teardown` | Se conserva exit y se limpia el handle. Test de idempotencia exige solo TERM/KILL una vez | Resuelto en doble; cierre Chrome real pendiente de CI |
| Chrome/API/SQL no ejecutados por el alcance local asignado | No se intentó un runtime no autorizado en Windows. Fuentes y comando exacto preparados para Linux CI aislado existente | Coordinador publica y verifica SHA/CI; cerrar solo con evidencias reales y retirada |

Lección aplicada: una respuesta HTTP 200 interceptada no basta para aceptar recuperación.
Se exige primero el estado SQL y solo después se permite continuar el navegador.
La prueba adversarial conserva esa barrera y evita convertir una afirmación del ejecutor en éxito.

## Comando para CI, no ejecutado localmente

Requisitos existentes en el runner: Node 24, Chrome, OpenSSL, Playwright 1.63.0 y binarios Release.
Usar la conexión del contenedor SQL desechable ya autorizado; nunca el piloto.

```sh
python3 tests/golden-path/golden_path.py --mode browser --no-build \
  --playwright-directory "$RUNNER_TEMP/c6-playwright/node_modules/playwright" \
  --out "$RUNNER_TEMP/c6-evidence" < /dev/null
python3 tests/golden-path/verify_evidence.py --source "$RUNNER_TEMP/c6-evidence" \
  --destination "$RUNNER_TEMP/c6-approved"
```

Aceptación pendiente: CI del SHA integrado con C5 y C6 completos, cero skips, tabla de oráculos,
recuperación sin otro POST/venta/débito, evidencia aprobada y retirada con readback de API/base/contenedor.
La revisión independiente, commit, publicación y Trello pertenecen al coordinador.

## Corrección posterior al CI 41757409404

SHA probado en CI: `6aeb9a35f45331ace85ac48dc19bfd9264b0f722`. Job: `126336673298`.
Fuentes de diagnóstico: `coordination/c6-ci-41757409404/evidence.json` y `oracles.md` saneados.
El runtime real fue Chrome 156.0.8078.47, Node v24.22.1 y Playwright 1.63.0.

Resultado real: los diez checkpoints anteriores a logout pasaron, incluida recuperación y recarga repetida.
SQL final de stock: 2 ventas, 2 líneas, 2 movimientos de venta, 2 operaciones de venta, existencia 27,
2 migraciones y 8 invariantes inválidos en cero. Hubo exactamente 2 POST de venta.
`browser.logout` falló en 20126 ms con `c6_browser_failed`.
La retirada anterior declaró PASS; su ausencia de grupos Node/Chrome no estaba comprobada.
Ese PASS histórico no satisface el contrato de ausencia añadido aquí.

**Causa confirmada del gap de retirada:** Playwright usa `detached: process.platform !== "win32"`
al lanzar Chrome. El grupo de Chrome en Linux es independiente del grupo Node.
El arnés anterior solo señalaba el grupo Node y no hacía una lectura final de ausencia.
Fuente directa: `playwright-core/lib/coreBundle.js` del paquete existente 1.62.1.
Los tipos instalados incluyen `Browser.newBrowserCDPSession` y `SystemInfo.getProcessInfo`.

**Causa de logout aún sin confirmar:** 20126 ms coincide aproximadamente con el timeout de navegación de 20000 ms.
La evidencia anterior omite fase y requests cuando una acción falla; no distingue click, 204, navegación o formulario.
El código directo exige renovación CSRF, POST logout, revocación, redirección y preparación CSRF del login.
El probe con Chrome y fuentes UI reales sobre transporte completamente en memoria pasó en 2371 ms con `me=401`.
Este probe no usa API ni SQL y no reproduce el fallo de CI. No acredita logout real corregido.
La prueba local de identidad CDP no fue concluyente: ruta Chrome por defecto ausente y probe con ejecutable existente agotó 15 s.
No se declara éxito de esa API en Windows a partir del timeout.
Contabilidad posterior: los dos intentos pidieron perfiles temporales nuevos; ninguno usó un perfil del usuario.
Lectura CIM exitosa: 0 Chrome vivos y 0 PID con perfil Playwright. No se enviaron señales.
Tras validar los dos destinos literales propios dentro de TEMP, se retiraron 2 perfiles y se leyó ausencia de ambos.
Los nombres de perfil privados no se incluyen en este documento público.
No se autorizaron ni intentaron SQL, Docker, API local, instalaciones o cambios de seguridad.

Cambios mínimos en el candidato:

- El logout observa el POST real y exige HTTP 204 antes de verificar URL de login, formulario habilitado y `me=401`.
- `click({noWaitAfter:true})` separa el click de las comprobaciones explícitas de navegación y formulario.
- Un fallo conserva solo un código fijo de fase en el checkpoint y el error global. No emite mensajes ni cuerpos.
- Chrome entrega su PID por el canal privado antes de los checkpoints. Python valida grupo, perfil exacto y ascendencia Node.
- Python registra hora de inicio para evitar señalar un PID reutilizado. TERM/KILL apunta solo a grupos con identidad vigente.
- La lectura final de ambos grupos debe estar vacía. Proceso persistente, identidad distinta o error de lectura impide PASS.
- El cierre sigue siendo idempotente. Smoke y serve conservan su flujo; no hay cambios de producto ni workflow.

Comprobaciones nuevas:

| Comando | Resultado exacto | Límite |
| --- | --- | --- |
| `python -m unittest discover -s tests -p 'test_golden_path*_safety.py'` | `Ran 33 tests in 0.251s`, `OK`, exit 0: 17 C5 + 16 C6 | Dobles de proceso/SQL; no runtime Linux |
| `node --check tests/golden-path/browser_path.mjs` | Exit 0 | Sintaxis, antes del último cambio exclusivo de tests/docs |
| `git diff --check` | Exit 0 | Rutas rastreadas; revisión adicional de los cinco archivos: 0 líneas con whitespace final |
| `ast.parse` de las dos fuentes Python | `PYTHON_AST_OK 2 files`, exit 0 | Sintaxis de los bytes actuales |

La primera corrida actualizada produjo 31 OK y 1 ERROR porque el reloj simulado no incluía el nuevo handshake.
Se corrigió el fixture del reloj; luego 32/32 OK. El caso de perfil ajeno añadido después da 33/33 OK.
Los casos significativos nuevos prueban retirada de ambos grupos, Chrome persistente tras salir Node,
identidad reutilizada sin señales, lectura denegada y rechazo de perfil ajeno.

Pendiente, dueño y cierre: el coordinador publica el nuevo SHA y corre el mismo comando CI documentado arriba.
Se requiere logout completo con SQL sesiones=0, todos los checkpoints y retirada `browser_processes_absent=true`.
Si falla, el código de fase distingue el siguiente diagnóstico. No ampliar pruebas locales de timeout.
Lección aplicada: salida del padre o señal enviada no demuestra ausencia de un proceso hijo con grupo independiente.

Hashes SHA-256 de los bytes entregados:

| Ruta | SHA-256 |
| --- | --- |
| `tests/golden-path/golden_path.py` | `e420885d49e066ca50cf6582d574149eb847338813362040c72bf92dbd9072fb` |
| `tests/golden-path/browser_path.mjs` | `60e9c9a636dac13149a57449247edce1491c842d727936d6d8e2e760bb5a7aaf` |
| `tests/test_golden_path_browser_safety.py` | `fbf94d089f5815f28e1d214292175ea9153d0e1806c8fa6a805ce193b9665fa7` |
| `tests/golden-path/README.md` | `2e1cf928279e97a267080952d73cd24756550fc259db59aae3621cf2a9ba4322` |

### Delta exacto contra 6aeb9a35 (cuatro fuentes; este reporte se entrega aparte)

```diff
--- a/tests/golden-path/golden_path.py
+++ b/tests/golden-path/golden_path.py
@@ -402,0 +403,3 @@
+        self.browser_groups = {}
+        self.browser_ownership_confirmed = False
+        self.browser_processes_absent = False
@@ -837,0 +841,37 @@
+    @staticmethod
+    def browser_process_identity(pid):
+        # Linux /proc start time prevents a reused PID from authorizing a signal.
+        fields = (Path('/proc') / str(pid) / 'stat').read_text().rsplit(')', 1)[1].split()
+        return {'pid': pid, 'parent': int(fields[1]), 'group': int(fields[2]), 'start': fields[19]}
+
+    def browser_group_members(self, group):
+        members = {}
+        for entry in Path('/proc').iterdir():
+            if not entry.name.isdecimal():
+                continue
+            try:
+                identity = self.browser_process_identity(int(entry.name))
+            except FileNotFoundError:
+                continue
+            if identity['group'] == group:
+                members[identity['pid']] = identity['start']
+        return members
+
+    def register_browser_group(self, pid, chrome=False):
+        expect(type(pid) is int and pid > 1, 'browser_process_identity_invalid')
+        identity = self.browser_process_identity(pid)
+        expect(identity['group'] == pid, 'browser_process_group_invalid')
+        if chrome:
+            command = (Path('/proc') / str(pid) / 'cmdline').read_bytes().split(b'\0')
+            profile = ('--user-data-dir=' + str(self.private / 'chrome-profile')).encode()
+            expect(profile in command, 'browser_profile_ownership_invalid')
+            parent = identity['parent']
+            for _ in range(32):
+                if parent == self.browser_process.pid:
+                    break
+                expect(parent > 1, 'browser_process_parent_invalid')
+                parent = self.browser_process_identity(parent)['parent']
+            expect(parent == self.browser_process.pid, 'browser_process_parent_invalid')
+        self.browser_groups[pid] = {pid: identity['start']}
+        self.browser_ownership_confirmed = chrome
+
@@ -839 +879 @@
-        """Stop only this run's process group, including Chrome descendants after Node failure."""
+        """Retire registered Node/Chrome groups and require a final absence readback."""
@@ -843 +883 @@
-        # Node is its own session leader. Kill remaining Chrome children even if Node already exited.
+        absent = False
@@ -845,17 +885,32 @@
-            os.killpg(process.pid, signal.SIGTERM)
-        except ProcessLookupError:
-            pass
-        try:
-            process.wait(timeout=5)
-        except subprocess.TimeoutExpired:
-            pass
-        try:
-            os.killpg(process.pid, signal.SIGKILL)
-        except ProcessLookupError:
-            pass
-        process.wait(timeout=5)
-        for pipe in (process.stdin, process.stdout):
-            if pipe:
-                pipe.close()
-        self.browser_exit = process.returncode
-        self.browser_process = None
+            # Playwright detaches Chrome: retire its group before retiring Node.
+            groups = list(reversed(self.browser_groups))
+            for sig in (signal.SIGTERM, signal.SIGKILL):
+                for group in groups:
+                    members = self.browser_group_members(group)
+                    if not members:
+                        continue
+                    known = self.browser_groups[group]
+                    if not any(known.get(pid) == start for pid, start in members.items()):
+                        continue  # Never signal a group whose ownership cannot be proved.
+                    known.update(members)
+                    try:
+                        os.killpg(group, sig)
+                    except ProcessLookupError:
+                        pass
+                for _ in range(50):
+                    process.poll()  # Reap Node before checking /proc.
+                    if all(not self.browser_group_members(group) for group in groups):
+                        absent = True
+                        break
+                    time.sleep(0.1)
+                if absent:
+                    break
+            self.browser_processes_absent = bool(absent and self.browser_ownership_confirmed)
+        except (OSError, ValueError, IndexError):
+            self.browser_processes_absent = False
+        finally:
+            self.browser_exit = process.poll()
+            for pipe in (process.stdin, process.stdout):
+                if pipe:
+                    pipe.close()
+            self.browser_process = None
@@ -931,2 +986,7 @@
-                                  'c6_recovery_key_or_post_count', 'c6_logout_or_post_count', 'c6_browser_failed'}
-                raise HarnessError(code if code in allowed_errors else 'browser_protocol_invalid')
+                                  'c6_recovery_key_or_post_count', 'c6_logout_or_post_count', 'c6_browser_failed',
+                                  'c6_browser_process_identity', 'c6_logout_click', 'c6_logout_response',
+                                  'c6_logout_http', 'c6_logout_navigation', 'c6_logout_form', 'c6_logout_me'}
+                code = code if code in allowed_errors else 'browser_protocol_invalid'
+                if self.steps and self.steps[-1]['step'].startswith('browser.'):
+                    self.steps[-1]['error_code'] = code
+                raise HarnessError(code)
@@ -935,0 +996 @@
+            self.register_browser_group(process.pid)
@@ -936,0 +998,5 @@
+            ownership = receive()
+            expect(isinstance(ownership, dict) and set(ownership) == {'owned_browser_pid'},
+                   'browser_process_identity_invalid')
+            self.register_browser_group(ownership['owned_browser_pid'], chrome=True)
+            send({'ok': True})
@@ -998,0 +1065,2 @@
+            records['browser_ownership_confirmed'] = self.browser_ownership_confirmed
+            records['browser_processes_absent'] = self.browser_processes_absent
@@ -1087,0 +1156 @@
+                              and (args.mode != 'browser' or cleanup.get('browser_processes_absent') is True)
--- a/tests/golden-path/browser_path.mjs
+++ b/tests/golden-path/browser_path.mjs
@@ -16,0 +17 @@
+let failurePhase = 'c6_browser_failed';
@@ -35,0 +37,11 @@
+  failurePhase = 'c6_browser_process_identity';
+  const ownershipSession = await context.browser().newBrowserCDPSession();
+  const {processInfo} = await ownershipSession.send('SystemInfo.getProcessInfo');
+  const browserProcesses = processInfo.filter(entry => entry.type === 'browser');
+  check(browserProcesses.length === 1 && Number.isSafeInteger(browserProcesses[0].id)
+    && browserProcesses[0].id > 1, 'c6_browser_process_identity');
+  process.stdout.write(`${JSON.stringify({owned_browser_pid: browserProcesses[0].id})}\n`);
+  const ownershipAck = await incoming.next();
+  check(!ownershipAck.done && JSON.parse(ownershipAck.value).ok === true, 'c6_sql_checkpoint_refused');
+  await ownershipSession.detach();
+  failurePhase = 'c6_browser_failed';
@@ -258 +270,11 @@
-  await page.locator('[data-action="logout"]').click();
+  // Observe the real 204 separately from navigation and login preparation.
+  failurePhase = 'c6_logout_click';
+  const logoutResponse = page.waitForResponse(result => new URL(result.url()).pathname === '/internal/api/security/logout'
+    && result.request().method() === 'POST', {timeout: 15000});
+  logoutResponse.catch(() => {}); // Keep the observer handled if the click fails first.
+  await page.locator('[data-action="logout"]').click({noWaitAfter: true});
+  failurePhase = 'c6_logout_response';
+  check((await logoutResponse).status() === 204, 'c6_logout_http');
+  failurePhase = 'c6_logout_navigation';
+  await page.waitForURL(url => url.href === `${origin.origin}/internal/login`, {waitUntil: 'commit', timeout: 20000});
+  failurePhase = 'c6_logout_form';
@@ -259,0 +282 @@
+  failurePhase = 'c6_logout_me';
@@ -266 +289 @@
-  const safe = /^c6_[a-z_]{1,80}$/.test(error?.message) ? error.message : 'c6_browser_failed';
+  const safe = /^c6_[a-z_]{1,80}$/.test(error?.message) ? error.message : failurePhase;
--- a/tests/test_golden_path_browser_safety.py
+++ b/tests/test_golden_path_browser_safety.py
@@ -90,0 +91 @@
+        harness.register_browser_group = Mock()
@@ -97,0 +99 @@
+        chunks = [b'{"owned_browser_pid":12346}\n', *chunks]
@@ -136 +138 @@
-        self.assertEqual(sum(message == {'ok': True} for message in sent), 6)
+        self.assertEqual(sum(message == {'ok': True} for message in sent), 7)  # ownership + six SQL ACKs
@@ -144 +146 @@
-            self.run_child(harness, process, [], clock=[0, 200, 400, 600])
+            self.run_child(harness, process, [], clock=[0, 0, 0, 400, 600])
@@ -148 +150 @@
-    def test_stop_kills_owned_process_group_after_wait_timeout(self):
+    def owned_processes(self):
@@ -153,3 +155,14 @@
-        process.wait.side_effect = [GP.subprocess.TimeoutExpired('node', 5), 0]
-        process.returncode = -9
-        with patch.object(GP.os, 'killpg', create=True) as kill, patch.object(GP.signal, 'SIGKILL', 9, create=True):
+        process.poll.return_value = -9
+        harness.browser_groups = {12345: {12345: 'node-start'}, 12346: {12346: 'chrome-start'}}
+        harness.browser_ownership_confirmed = True
+        alive = {12345: {12345: 'node-start'}, 12346: {12346: 'chrome-start'}}
+        harness.browser_group_members = Mock(side_effect=lambda group: alive[group].copy())
+        return harness, process, alive
+
+    def test_stop_kills_both_owned_groups_then_reads_absence_and_is_idempotent(self):
+        harness, process, alive = self.owned_processes()
+        def signal_group(group, sig):
+            if sig == 9:
+                alive[group].clear()
+        with patch.object(GP.os, 'killpg', side_effect=signal_group, create=True) as kill, \
+             patch.object(GP.signal, 'SIGKILL', 9, create=True), patch.object(GP.time, 'sleep'):
@@ -156,0 +170 @@
+            self.assertTrue(harness.browser_processes_absent)
@@ -159,3 +173,3 @@
-            self.assertEqual(kill.call_count, 2)
-        self.assertEqual(kill.call_args_list[0].args, (12345, GP.signal.SIGTERM))
-        self.assertEqual(kill.call_args_list[1].args, (12345, 9))
+            self.assertEqual([call.args for call in kill.call_args_list],
+                [(12346, GP.signal.SIGTERM), (12345, GP.signal.SIGTERM), (12346, 9), (12345, 9)])
+        self.assertTrue(all(not members for members in alive.values()))
@@ -164,0 +179,44 @@
+    def test_persistent_chrome_after_term_and_kill_fails_absence_readback(self):
+        harness, process, alive = self.owned_processes()
+        alive[12345].clear()  # Node exited; the independently detached Chrome group remains.
+        with patch.object(GP.os, 'killpg', create=True) as kill, \
+             patch.object(GP.signal, 'SIGKILL', 9, create=True), patch.object(GP.time, 'sleep'):
+            harness.stop_browser()
+        self.assertFalse(harness.browser_processes_absent)
+        self.assertEqual([call.args for call in kill.call_args_list], [(12346, GP.signal.SIGTERM), (12346, 9)])
+
+    def test_reused_group_identity_is_never_signaled_and_fails_readback(self):
+        harness, process, alive = self.owned_processes()
+        alive[12345].clear()
+        alive[12346] = {12346: 'different-process-start'}
+        with patch.object(GP.os, 'killpg', create=True) as kill, \
+             patch.object(GP.signal, 'SIGKILL', 9, create=True), patch.object(GP.time, 'sleep'):
+            harness.stop_browser()
+        kill.assert_not_called()
+        self.assertFalse(harness.browser_processes_absent)
+
+    def test_readback_error_cannot_pass_cleanup(self):
+        harness, process, _ = self.owned_processes()
+        harness.browser_group_members.side_effect = PermissionError('private unit fixture')
+        with patch.object(GP.os, 'killpg', create=True) as kill, patch.object(GP.signal, 'SIGKILL', 9, create=True):
+            harness.stop_browser()
+        kill.assert_not_called()
+        self.assertFalse(harness.browser_processes_absent)
+
+    def test_chrome_registration_requires_own_profile_and_node_parent(self):
+        harness, process, _ = self.prepare()
+        del harness.register_browser_group
+        harness.browser_process = process
+        process.pid = 12345
+        identity = {'pid': 12346, 'parent': 12345, 'group': 12346, 'start': 'chrome-start'}
+        with patch.object(harness, 'browser_process_identity', return_value=identity), \
+             patch.object(GP.Path, 'read_bytes', return_value=(
+                 '--user-data-dir=' + str(harness.private / 'chrome-profile')).encode() + b'\0'):
+            harness.register_browser_group(12346, chrome=True)
+        self.assertTrue(harness.browser_ownership_confirmed)
+        self.assertEqual(harness.browser_groups, {12346: {12346: 'chrome-start'}})
+        with patch.object(harness, 'browser_process_identity', return_value=identity), \
+             patch.object(GP.Path, 'read_bytes', return_value=b'--user-data-dir=/other/profile\0'):
+            with self.assertRaisesRegex(GP.HarnessError, 'browser_profile_ownership_invalid'):
+                harness.register_browser_group(12346, chrome=True)
+
--- a/tests/golden-path/README.md
+++ b/tests/golden-path/README.md
@@ -57 +57 @@
-| `browser.logout` | Logout real; `me` = 401 | 0 sesiones, 2 ventas |
+| `browser.logout` | Logout HTTP 204; URL de login, formulario habilitado; `me` = 401 | 0 sesiones, 2 ventas |
@@ -72,2 +72,5 @@
-El padre limita el proceso a 300 segundos y mata solo su grupo de procesos ante fallo o timeout.
-La retirada conserva las guardas de propiedad de la base y exige el readback existente de C5.
+El padre limita el proceso a 300 segundos. CDP identifica Chrome por un canal privado.
+Linux valida su perfil, ascendencia y hora de inicio antes de registrar sus grupos propios de Node y Chrome.
+La retirada usa TERM/KILL solo con identidad confirmada y exige leer la ausencia de ambos grupos.
+Una lectura fallida, identidad reutilizada o proceso persistente impide PASS; conserva las guardas SQL de C5.
+El logout publica solo un código fijo por fase ante fallo; nunca el mensaje crudo del navegador.
```
