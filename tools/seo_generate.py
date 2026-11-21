"""Generate the SEO, AIEO and robots files of the static storefront (idempotent).

Usage: python tools/seo_generate.py [--root DIR] [--config FILE] [--check]
Reads <root>/build-inputs/static/catalog.js, every *.html there, and the config (default: site.config.json).
Writes only inside <root>/build-inputs/static/:
  1. one <!-- seo:start --> ... <!-- seo:end --> block per page, in <head>, in place of the robots and description meta tags;
  2. robots.txt and llms.txt; sitemap.xml only when siteUrl is set and indexable is true (otherwise it deletes it).
It refuses (exit 2, writes nothing) when indexable is true and the data is sample data, or siteUrl is empty.
With --check nothing is written; the exit code is 1 when a change is pending.
Business values of the config (name, telephone, email, address, geo, openingHours) are never emitted.
"""
import argparse
import html
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
START, END = '<!-- seo:start -->', '<!-- seo:end -->'
NONINDEX = ('404.html', 'admin.html', 'bolsa.html', 'checkout.html', 'pedido.html')
LOCALE = 'es_NI'
LANG = 'es-NI'
META_LINE = re.compile(r'<meta name="robots"[^>]*>\s*<meta name="description"[^>]*>')
REGION = re.compile(re.escape(START) + r'.*?' + re.escape(END), re.S)
TITLE = re.compile(r'<title>(.*?)</title>', re.S)


def read_text(path):
    return path.read_bytes().decode('utf-8')


def write_text(path, text):
    path.write_bytes(text.encode('utf-8'))


def load_catalog(path):
    text = read_text(path)
    data, _ = json.JSONDecoder().raw_decode(text, text.index('{'))
    return data


def esc(value):
    return html.escape(value, quote=True)


def ld_dumps(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':')).replace('<', '\\u003c')


def clip(text, limit=160):
    text = ' '.join(text.split())
    if len(text) <= limit:
        return text
    cut = text[:limit - 1].rsplit(' ', 1)[0].rstrip(' ,;:.')
    return cut + '…'


def refusal(cfg, catalog):
    if not cfg.get('indexable'):
        return None
    why = []
    if catalog.get('mode') == 'local_test':
        why.append('catalog.mode is local_test')
    if catalog['brand'].get('commercial_status') == 'sample':
        why.append('brand is sample data')
    n = sum(1 for p in catalog['products'] if p.get('commercial_status') == 'sample')
    if n:
        why.append(f'{n} product(s) are sample data')
    if not (cfg.get('siteUrl') or '').strip():
        why.append('siteUrl is empty')
    return '; '.join(why) or None


def price(minor):
    return f'{minor / 100:.2f}'


def build(root, cfg):
    static = root / 'build-inputs' / 'static'
    catalog = load_catalog(static / 'catalog.js')
    brand, products = catalog['brand'], catalog['products']
    bname = brand['name']
    site = (cfg.get('siteUrl') or '').strip().rstrip('/')
    indexable = bool(cfg.get('indexable'))
    robots_meta = 'index,follow' if indexable else 'noindex,nofollow'
    U = lambda p: site + p
    page_path = lambda n: '/' if n == 'index.html' else '/' + n
    prod_pages = {f"producto-{p['slug']}.html": p for p in products}
    indexable_pages = ['index.html', 'catalogo.html', 'ayuda.html', *prod_pages]
    cats = []
    for p in products:
        if p['category'] not in cats:
            cats.append(p['category'])
    cat_words = ', '.join(c.lower() for c in cats)
    cat_list = ', '.join(cats[:-1]) + ' y ' + cats[-1] if len(cats) > 1 else ', '.join(cats)

    org = {'@type': 'Organization', 'name': bname, 'sameAs': list(brand.get('social', {}).values())}
    web = {'@type': 'WebSite', 'name': bname, 'inLanguage': LANG}
    if site:
        org['url'] = U('/')
        web['url'] = U('/')

    def describe(name, prod):
        if name == 'index.html':
            return clip(f'{bname}, {brand["country"]}: prendas de las categorías {cat_list}. Explorá la colección y mirá las tallas.')
        if name == 'catalogo.html':
            return clip(f'La colección de {bname}: {len(products)} prendas de las categorías {cat_list}, con tallas y precios.')
        if name == 'ayuda.html':
            return clip(f'Ayuda de {bname}: entrega, devoluciones y seguimiento de tu pedido.')
        d = ' '.join(prod['description'].split())
        if len(d) < 50:
            d = f"{prod['name']}. {d}"
        return clip(d)

    descs = {n: describe(n, prod_pages.get(n)) for n in indexable_pages}
    seen = {}
    for n in indexable_pages:  # keep descriptions unique: fall back to the product name in front
        if descs[n] in seen and n in prod_pages:
            descs[n] = clip(f"{prod_pages[n]['name']}. {prod_pages[n]['description']}")
        seen.setdefault(descs[n], n)

    def graph(name, prod):
        g = [org, web]
        home = {'@type': 'ListItem', 'position': 1, 'name': bname, 'item': U('/')}
        if name == 'catalogo.html':
            g.append({'@type': 'BreadcrumbList', 'itemListElement': [home, {'@type': 'ListItem', 'position': 2, 'name': 'Colección', 'item': U('/catalogo.html')}]})
            g.append({'@type': 'ItemList', 'itemListElement': [
                {'@type': 'ListItem', 'position': i + 1, 'url': U(page_path(f"producto-{p['slug']}.html")), 'name': p['name']}
                for i, p in enumerate(products)]})
        if prod:
            url = U(page_path(name))
            g.append({'@type': 'BreadcrumbList', 'itemListElement': [
                home, {'@type': 'ListItem', 'position': 2, 'name': 'Colección', 'item': U('/catalogo.html')},
                {'@type': 'ListItem', 'position': 3, 'name': prod['name'], 'item': url}]})
            g.append({'@type': 'Product', 'name': prod['name'], 'description': ' '.join(prod['description'].split()),
                      'sku': prod['id'], 'image': [U(i) for i in prod['images']],
                      'brand': {'@type': 'Brand', 'name': bname}, 'color': prod['color'], 'category': prod['category'],
                      'offers': [{'@type': 'Offer', 'sku': v['id'], 'price': price(prod['price_minor']), 'priceCurrency': prod['currency'],
                                  'availability': 'https://schema.org/InStock' if v['stock'] > 0 else 'https://schema.org/OutOfStock',
                                  'itemCondition': 'https://schema.org/NewCondition', 'url': url} for v in prod['variants']]})
        return {'@context': 'https://schema.org', '@graph': g}

    def region(name, text):
        if name in NONINDEX:
            m = re.search(r'<meta name="description"[^>]*>', text)
            return START + '<meta name="robots" content="noindex,nofollow">' + (m.group(0) if m else '') + END
        prod = prod_pages.get(name)
        title = html.unescape(TITLE.search(text).group(1).strip())
        d = descs[name]
        hero = (brand.get('hero') or {}).get('image')
        share_image = U(prod['images'][0]) if prod else (U(hero) if hero else None)
        tags = [f'<meta name="robots" content="{robots_meta}">', f'<meta name="description" content="{esc(d)}">']
        if site:
            tags.append(f'<link rel="canonical" href="{esc(U(page_path(name)))}">')
        og = [('og:title', title), ('og:description', d), ('og:site_name', bname), ('og:type', 'product' if prod else 'website'), ('og:locale', LOCALE)]
        if site:
            og.append(('og:url', U(page_path(name))))
            if share_image:
                og.append(('og:image', share_image))
        tags += [f'<meta property="{k}" content="{esc(v)}">' for k, v in og]
        tw = [('twitter:card', 'summary_large_image'), ('twitter:title', title), ('twitter:description', d)]
        if site and share_image:
            tw.append(('twitter:image', share_image))
        tags += [f'<meta name="{k}" content="{esc(v)}">' for k, v in tw]
        tags.append('<script type="application/ld+json">' + ld_dumps(graph(name, prod)) + '</script>')
        return START + ''.join(tags) + END

    def apply(name, text):
        reg = region(name, text)
        if REGION.search(text):
            return REGION.sub(lambda m: reg, text, count=1)
        if not META_LINE.search(text):
            raise SystemExit(f'{name}: robots+description meta tags not found')
        return META_LINE.sub(lambda m: reg, text, count=1)

    out = {}
    for name in [*indexable_pages, *NONINDEX]:
        path = static / name
        if not path.is_file():
            raise SystemExit(f'{name}: page missing')
        out[name] = apply(name, read_text(path))

    if indexable and site:
        out['robots.txt'] = ('User-agent: *\nAllow: /\n' + ''.join(f'Disallow: /{n}\n' for n in NONINDEX) + f'Sitemap: {site}/sitemap.xml\n')
        out['sitemap.xml'] = ('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
                              + ''.join(f'<url><loc>{esc(U(page_path(n)))}</loc></url>\n' for n in indexable_pages) + '</urlset>\n')
    else:
        out['robots.txt'] = 'User-agent: *\nDisallow: /\n'
        out['sitemap.xml'] = None
    cur = brand.get('currency', 'USD')
    sym = '$' if cur == 'USD' else cur + ' '
    lines = [f'# {bname}', '',
             f'> Tienda en línea de {cat_words} de {brand["country"]}. Catálogo de {len(products)} prendas.', '',
             '## Catálogo', '', f'- [Colección completa]({U("/catalogo.html")})', '', '## Productos', '']
    for p in products:
        lines.append(f"- [{p['name']}]({U(page_path('producto-' + p['slug'] + '.html'))}): {p['category']}, {sym}{price(p['price_minor'])}")
    out['llms.txt'] = '\n'.join(lines) + '\n'
    return out


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--root', default=str(REPO))
    ap.add_argument('--config', default=str(REPO / 'site.config.json'))
    ap.add_argument('--check', action='store_true')
    a = ap.parse_args(argv)
    root = Path(a.root).resolve()
    static = root / 'build-inputs' / 'static'
    cfg = json.loads(read_text(Path(a.config)))
    catalog = load_catalog(static / 'catalog.js')
    why = refusal(cfg, catalog)
    if why:
        print('refused: indexable needs live, non-sample data and a siteUrl (' + why + '); nothing written', file=sys.stderr)
        return 2
    pending = []
    for name, text in build(root, cfg).items():
        path = static / name
        if text is None:
            if path.exists():
                pending.append(name + ' (delete)')
                if not a.check:
                    path.unlink()
            continue
        if not path.is_file() or read_text(path) != text:
            pending.append(name)
            if not a.check:
                write_text(path, text)
    for name in pending:
        print(('pending ' if a.check else 'updated ') + name)
    print(f'{len(pending)} file(s) {"pending" if a.check else "updated"}')
    return 1 if a.check and pending else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
