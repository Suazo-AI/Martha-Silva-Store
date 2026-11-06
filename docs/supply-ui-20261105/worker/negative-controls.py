from pathlib import Path
import tempfile,shutil,subprocess,os,json,hashlib
root=Path.cwd();out=root/'docs/supply-ui-20261105/worker';source=root/'dev/savia-staff-ui/supply.mjs';before=source.read_bytes();env=os.environ.copy();env['NODE_PATH']='C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules'
results=[]
with tempfile.TemporaryDirectory(prefix='negative-',dir=out) as tmp:
 base=Path(tmp);target=base/'dev/savia-staff-ui';target.mkdir(parents=True)
 for name in ['supply.mjs','supply.test.mjs','login.mjs','index.html']:shutil.copyfile(root/'dev/savia-staff-ui'/name,target/name)
 original=(target/'supply.mjs').read_bytes()
 def run(label):
  v=subprocess.run(['node','--test','--test-name-pattern=persist before POST|client sends exact',str(target/'supply.test.mjs')],env=env,capture_output=True)
  (out/(label+'.log')).write_bytes(v.stdout+v.stderr);return v.returncode
 results.append({'case':'baseline','exit':run('negative-baseline')})
 for label,old,new in [('duplicate',"if(busy||pending||blocked||!allowed()||!order||!receivable(order.status))return;","if(blocked||!allowed()||!order||!receivable(order.status))return;"),('identity',"body:pending.body}","body:{...pending.body,receiptId:'00000001-0000-0000-0000-000000000099'}}")]:
  s=original.decode('utf-8-sig');assert s.count(old)==1,(label,s.count(old));(target/'supply.mjs').write_text(s.replace(old,new),encoding='utf8')
  code=run('negative-'+label);results.append({'case':label,'exit':code,'expectedFailure':code!=0});assert code!=0,label
  (target/'supply.mjs').write_bytes(original);assert (target/'supply.mjs').read_bytes()==original
  code=run('restored-'+label);results.append({'case':'restored-'+label,'exit':code,'byteExact':True});assert code==0
assert source.read_bytes()==before
(out/'negative-controls.json').write_text(json.dumps({'productUntouched':True,'RAW':hashlib.sha256(before).hexdigest(),'LF':hashlib.sha256(before.replace(b'\r\n',b'\n')).hexdigest(),'results':results},indent=2))
print(json.dumps(results))
