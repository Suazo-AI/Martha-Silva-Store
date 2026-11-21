import subprocess,base64,json,sys
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8')
base=[r'C:\Users\Jason\AppData\Roaming\npm\node_modules\agent-browser\bin\agent-browser-win32-x64.exe','--session','sale-44978']
def run(*a):
 r=subprocess.run(base+list(a),capture_output=True,text=True,encoding='utf-8');
 if r.returncode:raise RuntimeError(r.stderr+r.stdout)
 return r.stdout
run('open','http://127.0.0.1:58982/docs/savia-ux-20261116/sale/fixture.html')
js="(async()=> (await import('/savia/web/tests/sale-ux.browser.mjs')).runSaleUX())()"
try:
 result=run('eval','-b',base64.b64encode(js.encode()).decode());print(result);Path('docs/savia-ux-20261116/sale/mounted-results.json').write_text(result,encoding='utf-8')
except Exception as e: print(e);sys.exit(1)
