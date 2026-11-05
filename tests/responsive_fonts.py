"""Independent complete-font delivery and immutable fallback checks."""
from pathlib import Path
import hashlib,json,re,unittest,sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from tools.responsive_fonts import encode,verify
ROOT=Path(__file__).resolve().parents[1]
F=ROOT/'build-inputs/static/prototypes/fonts'
class Fonts(unittest.TestCase):
 def test_full_fonts_and_css(self):
  m=json.loads((ROOT/'docs/release-20261105/responsive-followup/before/source-manifest.json').read_text(encoding='utf8'))
  frozen={r['path']:r['sha256'] for r in m['files']}
  css=(F/'fonts.css').read_text();before=None
  for i in range(8):
   p=F/f'font-{i}.ttf';w=p.with_suffix('.woff2');data=w.read_bytes()
   self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),frozen[p.relative_to(ROOT).as_posix()])
   verify(p,data);self.assertEqual(encode(p),data)
   self.assertIn(f"url(font-{i}.woff2) format('woff2'), url(font-{i}.ttf) format('truetype')",css)
   self.assertEqual(data,(ROOT/'dist/prototypes/fonts'/w.name).read_bytes())
  old=re.sub(r"url\(font-\d.woff2\) format\('woff2'\), ",'',css)
  baseline=json.loads((ROOT/'docs/release-20261105/responsive-followup/font-baseline.json').read_text())
  self.assertEqual(baseline['rawSha256'],frozen['build-inputs/static/prototypes/fonts/fonts.css'])
  self.assertEqual(hashlib.sha256(old.encode()).hexdigest(),baseline['lfSha256'])
 def test_negative_control_rejects_lost_character(self):
  from fontTools.ttLib import TTFont
  from io import BytesIO
  p=F/'font-0.ttf';font=TTFont(BytesIO(p.with_suffix('.woff2').read_bytes()),recalcTimestamp=False)
  char=next(iter(font.getBestCmap()))
  for table in font['cmap'].tables:
   if table.isUnicode():table.cmap.pop(char,None)
  buf=BytesIO();font.save(buf)
  with self.assertRaises(AssertionError):verify(p,buf.getvalue())
if __name__=='__main__':unittest.main()
