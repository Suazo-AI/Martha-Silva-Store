import subprocess,base64,json,sys
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8')
base=[r'C:\Users\Jason\AppData\Roaming\npm\node_modules\agent-browser\bin\agent-browser-win32-x64.exe','--session','sale-44978']
def run(*a):
 r=subprocess.run(base+list(a),capture_output=True,text=True,encoding='utf-8')
 if r.returncode: raise RuntimeError(r.stdout+r.stderr)
 return r.stdout
out=Path('docs/savia-ux-20261116/sale')
log=[]
for label,query in [('before','?baseline'),('after','')]:
 for device,w,h in [('desktop',1440,900),('mobile',390,844)]:
  run('open','http://127.0.0.1:58982/docs/savia-ux-20261116/sale/fixture.html'+query)
  run('set','viewport',str(w),str(h))
  run('screenshot',str(out/f'{label}-{device}.png'))
  log.append(run('record','start',str(out/f'{label}-{device}.webm'),'--fps','10'))
  run('select','#sale-seller','00000000-0000-4000-8000-000000000001')
  run('click','.product')
  run('fill','#received','100')
  run('scrollintoview','#pay')
  run('screenshot',str(out/f'{label}-{device}-ticket.png'))
  log.append(run('record','stop'))
(out/'captures.txt').write_text('\n'.join(log),encoding='utf-8')
print('4 recordings and 8 screenshots captured')
