from pathlib import Path
import json,hashlib,subprocess
p=Path('savia/web/screens/sale.mjs');p.write_bytes(p.read_bytes().replace(b'\r\n',b'\n'))
root=Path('docs/savia-ux-20261116/sale')
results=json.loads((root/'mounted-results.json').read_text(encoding='utf-8'))
print('Mounted checks:',len(results))
files=['savia/web/screens/sale.mjs','savia/web/ui.mjs','savia/web/sale-recovery.mjs','savia/web/tests/sale-recovery.test.mjs','savia/web/tests/sale-ux.browser.mjs']
manifest={}
for f in files:
 entry={'candidateSha256':hashlib.sha256(Path(f).read_bytes()).hexdigest()}
 original=subprocess.run(['git','show','2c96904f49d2df913850bc13cf53b3b03ceebacf:'+f],capture_output=True)
 if original.returncode==0:entry['frozenSha256']=hashlib.sha256(original.stdout).hexdigest()
 manifest[f]=entry
(root/'source-bindings.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(root/'baseline-race.json').write_text(json.dumps({'source':'2c96904f49d2df913850bc13cf53b3b03ceebacf','route':'fixture.html?baseline','observed':{'posts':1,'firstRequestQuantity':1,'editedQuantity':2,'payEnabledDuringHeldPost':True,'firstSellerWasFirstRow':True},'limits':'No second POST sent; synthetic HTTP only. Captured from actual probe tool output.'},indent=2),encoding='utf-8')
