from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlparse
from collections import Counter
ROOT=Path(__file__).resolve().parent.parent/'dist'
class DOM(HTMLParser):
 def __init__(self):super().__init__();self.ids=[];self.refs=[];self.urls=[];self.sources=[];self.videos=0
 def handle_starttag(self,t,attributes):
  a=dict(attributes)
  if 'id' in a:self.ids.append(a['id'])
  for k in ['aria-controls','aria-labelledby','aria-describedby']:
   self.refs+=a.get(k,'').split()
  for k in ['href','src','poster']:
   if a.get(k):self.urls.append(a[k])
  if a.get('srcset'):self.sources.extend(x.strip().split()[0] for x in a['srcset'].split(','))
  if t=='video':self.videos+=1
pages={}
for f in ROOT.glob('*.html'):
 d=DOM();d.feed(f.read_text());pages[f.name]=d
for name,d in pages.items():
 assert all(n==1 for n in Counter(d.ids).values()),(name,'duplicate IDs')
 assert all(x in d.ids for x in d.refs),(name,'dangling ARIA',d.refs)
 assert d.videos==0,(name,'unexpected video')
 for url in d.urls+d.sources:
  u=urlparse(url)
  if u.scheme:continue
  path=u.path.lstrip('/') or name
  assert (ROOT/path).is_file(),(name,'missing asset',url)
  if u.fragment:assert u.fragment in pages[path].ids,(name,'broken anchor',url)
print(f'PASS: {len(pages)} pages; local assets/srcset/routes/anchors/ARIA IDs; no video elements')
