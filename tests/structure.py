from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import urlparse
from collections import Counter

ROOT = Path(__file__).resolve().parent.parent / 'dist'
VOID = {'area', 'base', 'br', 'col', 'embed', 'hr', 'img', 'input', 'link', 'meta', 'param', 'source', 'track', 'wbr'}


class DOM(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids, self.refs, self.urls, self.sources, self.videos, self.scripts, self.stack = [], [], [], [], [], [], []

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if 'id' in attrs:
            self.ids.append(attrs['id'])
        for key in ['aria-controls', 'aria-labelledby', 'aria-describedby']:
            self.refs += attrs.get(key, '').split()
        for key in ['href', 'src', 'poster', 'data-src', 'data-webm']:
            if attrs.get(key):
                self.urls.append(attrs[key])
        if attrs.get('srcset'):
            self.sources.extend(item.strip().split()[0] for item in attrs['srcset'].split(','))
        if tag == 'video':
            ancestors = {value for _, values in self.stack for value in values}
            self.videos.append((attrs, ancestors))
        if tag == 'script' and attrs.get('src'):
            self.scripts.append(attrs['src'])
        if tag not in VOID:
            self.stack.append((tag, attrs.get('class', '').split()))

    def handle_endtag(self, tag):
        for index in range(len(self.stack) - 1, -1, -1):
            if self.stack[index][0] == tag:
                del self.stack[index:]
                break


pages = {}
for file in ROOT.glob('*.html'):
    dom = DOM()
    dom.feed(file.read_text(encoding='utf-8'))
    pages[file.name] = dom

assert len(pages) == 47, ('expected 47 original page templates', len(pages))
for name, dom in pages.items():
    assert all(count == 1 for count in Counter(dom.ids).values()), (name, 'duplicate IDs')
    assert all(reference in dom.ids for reference in dom.refs), (name, 'dangling ARIA', dom.refs)
    for attrs, ancestors in dom.videos:
        assert 'autoplay' not in attrs, (name, 'unexpected autoplay')
        assert 'src' not in attrs, (name, 'product video must retain deferred loading')
        assert 'playsinline' in attrs and attrs.get('preload') == 'none', (name, 'unexpected video loading policy')
        if name == 'index.html':
            assert not ({'campaign', 'hero'} & ancestors), (name, 'hero must remain photographic')
    assert all(not urlparse(source).scheme and not source.startswith('//') for source in dom.scripts), (name, 'remote script')
    for url in dom.urls + dom.sources:
        parsed = urlparse(url)
        if parsed.scheme:
            continue
        assert not url.startswith('//'), (name, 'protocol-relative resource', url)
        relative = parsed.path.lstrip('/') or name
        assert '..' not in Path(relative).parts, (name, 'path traversal', url)
        assert (ROOT / relative).is_file(), (name, 'missing asset', url)
        if parsed.fragment:
            assert relative in pages and parsed.fragment in pages[relative].ids, (name, 'broken anchor', url)
print(f'PASS: {len(pages)} pages; local assets/srcset/deferred-video/routes/anchors/ARIA IDs; photographic hero')
