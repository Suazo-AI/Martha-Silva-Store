from pathlib import Path
import subprocess
p=Path('docs/savia-ux-20261116/sale')
s=subprocess.check_output(['git','show','2c96904f49d2df913850bc13cf53b3b03ceebacf:savia/web/screens/sale.mjs'],text=True,encoding='utf-8')
s=s.replace("'../", "'/savia/web/").replace("'./", "'/savia/web/screens/")
(p/'baseline.mjs').write_text(s,encoding='utf-8')
f=p/'fixture.html';s=f.read_text(encoding='utf-8-sig').replace("import sale from '/savia/web/screens/sale.mjs';", "const {default:sale}=await import(location.search.includes('baseline') ? './baseline.mjs' : '/savia/web/screens/sale.mjs');")
f.write_text(s,encoding='utf-8')
