"""Read-only source/scope audit. Never executes SQL or accesses network."""
import difflib, hashlib, json, subprocess, zipfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[8]
# Resolve from the actual managed working directory; do not act in canonical checkout.
ROOT = Path.cwd()
OUT = Path(__file__).resolve().parent
CANON = Path('C:/Users/Jason/MARTHA-SILVA/github/docs/merge-readiness-20261116/corrections/returns/sql')
def sha(b): return hashlib.sha256(b).hexdigest()
def git(*args): return subprocess.check_output(['git', *args], cwd=ROOT).decode().strip()
assert git('rev-parse','HEAD') == 'ba8ff2ba10935e99fc268ebbe5eae130f72c1cca'
r = json.loads((CANON/'REVIEW.json').read_text())
assert sha((CANON/'review-overlay.zip').read_bytes()) == r['archiveSha256']
assert sha((CANON/'astra-sql-review.md').read_bytes()) == 'ea007fb66f278432e24cd9a832f5b889b5b4d642366540ca5f4c5a5f64a458f0'
owned = {'savia/db/tests/sales/134_credit_return_validation.sql','savia/db/tests/sales/172_return_retry_safety.sql','savia/tests/Savia.Tests/ReturnRetrySafetyTests.cs','savia/tests/test_return_retry_safety.py'}
hashes=[]; delta=[]
with zipfile.ZipFile(CANON/'review-overlay.zip') as z:
 assert sorted(z.namelist()) == sorted(f['path'] for f in r['files'])
 for f in r['files']:
  frozen=z.read(f['path']); assert sha(frozen)==f['rawSha256']; assert sha(frozen.replace(b'\r\n',b'\n'))==f['lfSha256']
  actual=(ROOT/f['path']).read_bytes()
  hashes.append(dict(path=f['path'],rawSha256=sha(actual),lfSha256=sha(actual.replace(b'\r\n',b'\n')),overlayRawSha256=f['rawSha256']))
  if f['path'] not in owned: assert actual==frozen
  else:
   assert actual!=frozen
   delta.extend(difflib.unified_diff(frozen.decode().splitlines(True),actual.decode().splitlines(True),fromfile='overlay/'+f['path'],tofile=f['path']))
p='savia/db/tests/sales/134_credit_return_validation.sql'
b=(ROOT/p).read_bytes(); old=subprocess.check_output(['git','show','HEAD:'+p])
expected=old.replace(b'-- 51526 la devolucion ya existe con otro anticipo',b'-- 51538 la identidad financiera cambia con otro anticipo').replace(b'ERROR_NUMBER()<>51526',b'ERROR_NUMBER()<>51538')
assert b.replace(b'\r\n',b'\n')==expected.replace(b'\r\n',b'\n')
hashes.append(dict(path=p,rawSha256=sha(b),lfSha256=sha(b.replace(b'\r\n',b'\n'))))
delta.extend(difflib.unified_diff(old.decode().splitlines(True),b.decode().splitlines(True),fromfile='HEAD/'+p,tofile=p))
allowed=owned | {f['path'] for f in r['files']}
prefix=OUT.relative_to(ROOT).as_posix()+'/'
changed=set(git('diff','--name-only').splitlines()) | set(git('ls-files','--others','--exclude-standard').splitlines())
assert all(p in allowed or p.startswith(prefix) for p in changed), sorted(changed)
assert not git('diff','--cached','--name-only')
subprocess.run(['git','diff','--check'],check=True)
(OUT/'hashes.json').write_text(json.dumps(hashes,indent=2))
(OUT/'final-delta.patch').write_text(''.join(delta),encoding='utf-8',newline='\n')
(OUT/'scope.json').write_text(json.dumps(dict(source=git('rev-parse','HEAD'),branch=git('branch','--show-current'),changed=sorted(changed),indexUnchanged=True,frozenUnchanged=True),indent=2))
print('PASS: archive, five frozen inputs, four revised sources, immutable migration/manifest, exact SQL134 delta, scope and empty index')
