from pathlib import Path
import json,re
root=Path('build-inputs/static')
m=json.loads((root/'responsive-images/manifest.json').read_text())
lookup={a['original']:a for a in m['assets']}
counts={}
for page in root.glob('*.html'):
 s=page.read_bytes()
 def patch(match):
  tag=match.group().decode()
  src=re.search(r'srcset="(/generated-luxury/[^" ]+)[^"]*"',tag)
  if not src:return match.group()
  a=lookup[src[1]]
  candidates=', '.join(d['path']+' '+str(d['width'])+'w' for d in a['derivatives'])
  sizes=re.search(r'sizes="([^"]+)"',tag)[1]
  return ('<source data-responsive-generated="" type="image/webp" srcset="'+candidates+'" sizes="'+sizes+'">'+tag).encode()
 new,n=re.subn(rb'<source type="image/png"[^>]*>',patch,s)
 if new!=s:page.write_bytes(new);counts[page.name]=n
p=Path('src/app.js');s=p.read_bytes()
needle=b'return `<picture class="${cls}"><source'
replacement=b'''return `<picture class="${cls}">${src.startsWith('/generated-luxury/') && src.endsWith('.png') ? `<source type="image/webp" srcset="${[360,720,dimensions[0]].filter((w,n,a)=>w<=dimensions[0]&&a.indexOf(w)===n).map(w=>esc(src.replace('/generated-luxury/','/responsive-images/').replace(/\\.png$/, '-'+w+'.webp'))+' '+w+'w').join(', ')}" sizes="(max-width:599px) 50vw,25vw">` : ''}<source'''
assert s.count(needle)==1
p.write_bytes(s.replace(needle,replacement))
Path('docs/release-20261105/responsive-images/changed-pictures.json').write_text(json.dumps(counts,indent=2))
print('Updated',len(counts),'HTML templates; original picture content retained')
