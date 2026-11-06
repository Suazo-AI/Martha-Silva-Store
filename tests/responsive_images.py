"""Focused responsive delivery checks; source identity is bound to actual before capture."""
from pathlib import Path
import hashlib,json,re,unittest
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
STATIC=ROOT/'build-inputs/static'
class ResponsiveImages(unittest.TestCase):
 def test_originals_dimensions_hashes_and_fallback(self):
  m=json.loads((STATIC/'responsive-images/manifest.json').read_text())
  before=json.loads((ROOT/'docs/release-20261105/responsive-images/before/source-manifest.json').read_text())
  hashes={e['path']:e['sha256'] for e in before['files']}
  self.assertLessEqual(len(m['assets']),200)
  self.assertLessEqual(sum(len(a['derivatives']) for a in m['assets']),600)
  for a in m['assets']:
   original=STATIC/a['original'].lstrip('/')
   self.assertEqual(hashlib.sha256(original.read_bytes()).hexdigest(),a['sha256'])
   self.assertEqual(a['sha256'],hashes['build-inputs/static'+a['original']])
   for d in a['derivatives']:
    f=STATIC/d['path'].lstrip('/')
    self.assertEqual(hashlib.sha256(f.read_bytes()).hexdigest(),d['sha256'])
    with Image.open(f) as im:self.assertEqual(im.size,(d['width'],d['height']))
    self.assertEqual(d['height'],round(a['height']*d['width']/a['width']))
    self.assertLessEqual(d['width'],a['width'])
  self.assertEqual(hashlib.sha256((STATIC/'catalog.js').read_bytes()).hexdigest(),hashes['build-inputs/static/catalog.js'])
  # D-030 selected Jason composition; exact LF bytes required by .gitattributes.
  selected_layouts={'index.html': '35a8495127d2da4ce6061e77092fb46682e5a7c5d34ec5c88f2646985f3db1f5', 'catalogo.html': '672886e25c2de0535b5265f9e105d63f1acbb50eeefceb6f8cebc79328268c92'}
  for page in STATIC.glob('*.html'):
   s=page.read_bytes();stripped=re.sub(rb'<source data-responsive-generated=""[^>]+>',b'',s)
   self.assertEqual(hashlib.sha256(stripped).hexdigest(),selected_layouts.get(page.name,hashes['build-inputs/static/'+page.name]),page.name)
   self.assertEqual(s,(ROOT/'dist'/page.name).read_bytes())
if __name__=='__main__':unittest.main()
