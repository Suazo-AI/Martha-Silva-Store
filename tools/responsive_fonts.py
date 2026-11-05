"""Deterministic complete WOFF2 encoding; existing licensed TTFs remain fallbacks."""
from pathlib import Path
from io import BytesIO
import hashlib,json
from fontTools.ttLib import TTFont
from fontTools.ttLib.woff2 import WOFF2FlavorData
ROOT=Path(__file__).resolve().parents[1]
FONTS=ROOT/'build-inputs/static/prototypes/fonts'
def encode(p):
 f=TTFont(p,recalcTimestamp=False);f.flavor='woff2';f.flavorData=WOFF2FlavorData(transformedTables=set());b=BytesIO();f.save(b);f.close();return b.getvalue()
def verify(p,data):
 a=TTFont(p,recalcTimestamp=False);b=TTFont(BytesIO(data),recalcTimestamp=False)
 assert set(a.keys())==set(b.keys())
 assert a.getBestCmap()==b.getBestCmap();assert a.getGlyphOrder()==b.getGlyphOrder()
 for tag in a.keys():
  if tag=='GlyphOrder':continue
  x,y=a.getTableData(tag),b.getTableData(tag)
  if tag=='head':
   # WOFF2 sets bit 11 (lossless compression) and recalculates checksum.
   assert b['head'].flags == (a['head'].flags | 0x800)
   x=x[:8]+b'\0'*4+x[12:16]+(int.from_bytes(x[16:18],'big') & ~0x800).to_bytes(2,'big')+x[18:]
   y=y[:8]+b'\0'*4+y[12:16]+(int.from_bytes(y[16:18],'big') & ~0x800).to_bytes(2,'big')+y[18:]
  assert x==y,tag
 return dict(tables=list(a.keys()),characters=len(a.getBestCmap()),glyphs=len(a.getGlyphOrder()),unitsPerEm=a['head'].unitsPerEm,weight=a['OS/2'].usWeightClass,licenses=[r.toUnicode() for r in a['name'].names if r.nameID in [0,13,14] and r.platformID==3])
def main():
 rows=[]
 for p in sorted(FONTS.glob('font-*.ttf')):
  data=encode(p);assert encode(p)==data;r=verify(p,data);p.with_suffix('.woff2').write_bytes(data)
  rows.append(dict(path=p.name,ttfBytes=p.stat().st_size,woff2Bytes=len(data),ttfSha256=hashlib.sha256(p.read_bytes()).hexdigest(),woff2Sha256=hashlib.sha256(data).hexdigest(),**r))
 print(json.dumps(rows,indent=2))
if __name__=='__main__':main()
