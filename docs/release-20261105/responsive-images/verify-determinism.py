from pathlib import Path
from PIL import Image
from io import BytesIO
import hashlib,json,time
base=Path('docs/release-20261105/responsive-images');m=json.loads(Path('build-inputs/static/responsive-images/manifest.json').read_text());start=time.monotonic();n=0;bad=[]
for a in m['assets']:
 with Image.open(Path('build-inputs/static')/a['original'].lstrip('/')) as im:
  for d in a['derivatives']:
   buf=BytesIO();im.convert('RGB').resize((d['width'],d['height']),Image.Resampling.LANCZOS).save(buf,format='WEBP',quality=82,method=6,exact=True)
   n+=1
   if hashlib.sha256(buf.getvalue()).hexdigest()!=d['sha256']:bad.append(d['path'])
r={'checked':n,'mismatches':bad,'elapsedSeconds':time.monotonic()-start,'method':'Independent in-memory re-encode of every derivative; no file rewrite'}
(base/'determinism.json').write_text(json.dumps(r,indent=2));print(json.dumps(r));raise SystemExit(bool(bad))
