"""Offline whole-frame WebP derivatives. Originals and catalog identity are immutable."""
from pathlib import Path
import hashlib,json
import PIL
from PIL import Image,features
ROOT=Path(__file__).resolve().parents[1]
STATIC=ROOT/'build-inputs/static'
OUT=STATIC/'responsive-images'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def generate():
 sources=sorted((STATIC/'generated-luxury').rglob('*.png'))
 assert len(sources)<=200
 records=[]
 for source in sources:
  rel=source.relative_to(STATIC/'generated-luxury')
  with Image.open(source) as im:
   w,h=im.size; derivatives=[]
   for width in sorted(set([min(360,w),min(720,w),w])):
    height=round(h*width/w)
    target=OUT/rel.parent/(rel.stem+f'-{width}.webp');target.parent.mkdir(parents=True,exist_ok=True)
    scaled=im.convert('RGB').resize((width,height),Image.Resampling.LANCZOS)
    scaled.save(target,format='WEBP',quality=82,method=6,exact=True)
    derivatives.append(dict(path='/'+target.relative_to(STATIC).as_posix(),width=width,height=height,bytes=target.stat().st_size,sha256=digest(target)))
   records.append(dict(original='/'+source.relative_to(STATIC).as_posix(),sha256=digest(source),bytes=source.stat().st_size,width=w,height=h,full_source_frame=True,metadata_stripped=True,derivatives=derivatives))
 assert sum(len(r['derivatives']) for r in records)<=600
 manifest=dict(generator='tools/responsive_images.py',pillow=PIL.__version__,libwebp=features.version('webp'),config=dict(widths=[360,720,'original'],quality=82,method=6,resample='LANCZOS',crop=False),provenance='Original generated-luxury assets remain unchanged. Existing IA labels and upstream evidence/releases/20261030/luxury-selected-assets.json retained.',assets=records)
 OUT.mkdir(parents=True,exist_ok=True);(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
 print(json.dumps(dict(sources=len(records),derivatives=sum(len(r['derivatives']) for r in records))))
if __name__=='__main__':generate()
