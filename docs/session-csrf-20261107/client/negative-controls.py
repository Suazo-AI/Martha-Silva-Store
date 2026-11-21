"""Offline disposable negative controls; never modifies tracked product source."""
from pathlib import Path
import hashlib, json, os, re, shutil, subprocess
ROOT = Path(__file__).resolve().parents[3]
PRIVATE = ROOT / 'private-exports/session-client-20261107'
TEST = 'session-transition.test.mjs'
FILES = ['login.mjs','client.mjs','app.mjs','supply.mjs','index.html',TEST]
SOURCE = ROOT / 'dev/savia-staff-ui'
def sha(data): return hashlib.sha256(data).hexdigest()
def binding(data): return {'rawSha256':sha(data),'lfSha256':sha(data.replace(b'\r\n',b'\n'))}
original = {name:(SOURCE/name).read_bytes() for name in FILES}
controls = [
 ('auth-epoch', 'login.mjs', 'if (generation !== epoch)', 'if (false)', 'old-session CSRF renewal'),
 ('commerce-generation', 'app.mjs', 'const current = (g, id) => generation === g && getSession()?.id === id;', 'const current = (g, id) => true;', 'sale: old-session business response at mount'),
 ('supply-generation', 'supply.mjs', 'const same=(g,a)=>g===epoch && getSession()?.id===a?.id && getSession()?.version===a?.version;', 'const same=(g,a)=>true;', 'supply: old-session business response at mount'),
 ('review-generation', 'app.mjs', 'const same=(e,a)=>epoch===e && getSession()?.id===a.id && getSession()?.version===a.version;', 'const same=(e,a)=>true;', 'review: old-session business response at mount'),
 ('automatic-resend', 'app.mjs', "if(current(g,id) && pending?.key) await resolve('recover');", "if(current(g,id) && pending?.key) await resolve('record');", 'same account/version'),
 ('reference-rewrite', 'app.mjs', 'pending=value;', 'pending=value; storage().setItem(keyFor(id),JSON.stringify(value));', 'same account/version'),
 ('key-rewrite', 'login.mjs', 'idempotencyKey: key, csrfToken:', "idempotencyKey: '10000000-0000-0000-0000-000000000099', csrfToken:", 'explicit continuation'),
 ('skip-business-renewal', 'login.mjs', "if (sale || supplyWrite || (review && method==='POST')) await renewCsrf();", "if (false) await renewCsrf();", 'explicit continuation'),
]
env = os.environ.copy()
env['NODE_PATH']='C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules'
PRIVATE.mkdir(parents=True,exist_ok=True)
results=[]
for name, file, old, new, pattern in controls:
 folder=PRIVATE/name
 folder.mkdir(exist_ok=True)
 for f, data in original.items(): (folder/f).write_bytes(data)
 data=(folder/file).read_bytes()
 assert data.count(old.encode())==1, (name,'mutation target not unique')
 mutant=data.replace(old.encode(),new.encode())
 (folder/file).write_bytes(mutant)
 try:
  command=['node','--test',f'--test-name-pattern={pattern}',str(folder/TEST)]
  run=subprocess.run(command,cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=30)
  log=PRIVATE/f'{name}.log';log.write_bytes(run.stdout)
  output=run.stdout.decode('utf-8',errors='replace')
  counts={k:int(v) for k,v in re.findall(r'(?:#|ℹ) (tests|pass|fail|skipped|cancelled) (\d+)',output)}
  results.append({'control':name,'file':file,'replacement':{'from':old,'to':new},'command':command,'exit':run.returncode,'counts':counts,'original':binding(data),'mutant':binding(mutant),'log':str(log.relative_to(ROOT)).replace('\\','/'),'logSha256':sha(run.stdout)})
 finally:
  (folder/file).write_bytes(data)
  assert (folder/file).read_bytes()==data
  results[-1]['disposableRestoredExactly']=True
 assert run.returncode!=0 and counts.get('fail',0)>0,(name,'regression not detected')
 print(name,run.returncode,counts)
assert all((SOURCE/f).read_bytes()==data for f,data in original.items())
report={'sourceSha':'030b64f7cba87c6a0d710892deb9a8493ea8bbf4','productSourceUnchanged':True,'controls':results}
(ROOT/'docs/session-csrf-20261107/client/negative-controls.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
