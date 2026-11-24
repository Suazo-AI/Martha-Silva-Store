"""Deterministic complete WOFF2 encoding; existing licensed TTFs remain fallbacks.

Each font also gets a Latin WOFF2 subset served through unicode-range.
The complete WOFF2 declares only the characters outside LATIN, so the two ranges never overlap."""
from pathlib import Path
from io import BytesIO
import hashlib,json
from fontTools.ttLib import TTFont
from fontTools.ttLib.woff2 import WOFF2FlavorData
ROOT=Path(__file__).resolve().parents[1]
FONTS=ROOT/'build-inputs/static/prototypes/fonts'
LATIN='U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC, U+2122, U+2190-2193, U+2197, U+2212, U+2215, U+FEFF, U+FFFD'
def latin_codepoints():
 out=set()
 for part in LATIN.split(','):
  a=part.strip()[2:].split('-');out|=set(range(int(a[0],16),int(a[-1],16)+1))
 return out
def cmap_range(p):
 """unicode-range of the characters the font has outside LATIN: the ranges never overlap and a missing glyph never downloads it."""
 cps=sorted(set(TTFont(p,recalcTimestamp=False).getBestCmap())-latin_codepoints());out=[];start=prev=cps[0]
 for c in cps[1:]+[None]:
  if c is not None and c==prev+1:prev=c;continue
  out.append(f'U+{start:04X}' if start==prev else f'U+{start:04X}-{prev:04X}')
  if c is not None:start=prev=c
 return ', '.join(out)
def encode_latin(p):
 from fontTools import subset
 o=subset.Options();o.flavor='woff2';o.layout_features=['*'];o.name_IDs=['*'];o.name_languages=['*'];o.notdef_outline=True;o.hinting=True
 f=TTFont(p,recalcTimestamp=False);s=subset.Subsetter(o);s.populate(unicodes=latin_codepoints());s.subset(f)
 b=BytesIO();subset.save_font(f,b,o);f.close();return b.getvalue()
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
  latin=encode_latin(p);assert encode_latin(p)==latin;(FONTS/f'{p.stem}-latin.woff2').write_bytes(latin)
  rows.append(dict(path=p.name,ttfBytes=p.stat().st_size,woff2Bytes=len(data),ttfSha256=hashlib.sha256(p.read_bytes()).hexdigest(),woff2Sha256=hashlib.sha256(data).hexdigest(),latinBytes=len(latin),latinSha256=hashlib.sha256(latin).hexdigest(),**r))
 print(json.dumps(rows,indent=2))
if __name__=='__main__':main()
