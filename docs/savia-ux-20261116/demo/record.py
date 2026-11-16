"""Owned local recording route. No remote traffic or credentials."""
import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('shell', ROOT / 'savia/demo/site/verify.py')
shell = importlib.util.module_from_spec(spec)
spec.loader.exec_module(shell)
shell.SESSION = 'savia-entry-20261116-record'
phase = sys.argv[1]
out = Path(__file__).parent
server = shell.ThreadingHTTPServer(('127.0.0.1', 0), shell.functools.partial(shell.Quiet, directory=str(ROOT / 'savia/.out/demo-site')))
thread = shell.threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
origin = f'http://127.0.0.1:{server.server_port}'
results = []
try:
    for w,h in [(1440,900),(390,844)]:
        shell.browser('open', origin)
        shell.browser('set', 'viewport', w,h)
        shell.browser('record', 'start', out / f'{phase}-{w}.webm')
        try:
            shell.browser('open', origin)
            shell.browser('wait', '#login-user' if phase == 'before' else '#demo-entry')
            results.append({'width':w,'initial':shell.evaluate("({login:!!document.querySelector('#login-user'),entry:!!document.querySelector('#demo-entry'),overflow:document.documentElement.scrollWidth>innerWidth})")})
            if phase == 'before': shell.browser('select','#demo-role','MANAGER')
            else: shell.browser('click','[data-demo-role=MANAGER]')
            shell.browser('wait','--fn',"!!document.querySelector('#operator-label')?.textContent.includes('Gerente')")
            shell.browser('reload')
            shell.browser('wait','--fn',"!!document.querySelector('#operator-label')?.textContent.includes('Gerente')")
            shell.browser('click','#demo-banner button')
            if phase == 'after':
                shell.browser('wait','#confirm-no')
                shell.browser('click','#confirm-no')
                shell.browser('click','#demo-banner button')
                shell.browser('click','#confirm-yes')
            shell.browser('wait','#login-user' if phase == 'before' else '#demo-entry')
        finally: shell.browser('record','stop')
finally:
    shell.browser('close')
    server.shutdown()
    server.server_close()
    (out / f'{phase}-recording.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
print(json.dumps(results))
