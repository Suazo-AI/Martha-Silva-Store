'use strict';
// Static/image-header and serial DOM checks. These are not browser rendering tests.
// Run after prepare.py: node --test tests/luxury-editorial.cjs
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const {JSDOM, VirtualConsole} = require('./frontend-deps/node_modules/jsdom');
const root = path.resolve(__dirname, '..');
const dist = path.join(root, 'dist');
const manifest = require('../evidence/luxury/editorial-provenance.json');
const assets = new Map(manifest.assets.flatMap(asset => asset.derivatives.map(derivative => [derivative.runtime_path, {...derivative, original: asset.original, post: asset.post_id}])));
const publication = require('./fixtures/published-catalog-contract.json');
const release = require('../evidence/releases/20261030/current-runtime-sha256.json');
const selected = new Map(require('../evidence/releases/20261030/luxury-selected-assets.json').selected_assets.map(r => ['/' + r.runtime_destination, r]));
const responsive = new Map(require('../build-inputs/static/responsive-images/manifest.json').assets.map(r => [r.original, r]));
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const html = () => fs.readFileSync(path.join(dist, 'index.html'), 'utf8');
const normalize = value => value.replace(/\s+/g, ' ').trim();

function dimensions(bytes) {
  if (bytes.subarray(0,8).toString('hex') === '89504e470d0a1a0a') return {width:bytes.readUInt32BE(16),height:bytes.readUInt32BE(20)};
  if (bytes[0] === 0xff && bytes[1] === 0xd8) {
    let offset = 2;
    while (offset < bytes.length) {
      assert.equal(bytes[offset++], 0xff);
      while (bytes[offset] === 0xff) offset++;
      const marker = bytes[offset++];
      if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker)) {
        return {width: bytes.readUInt16BE(offset + 5), height: bytes.readUInt16BE(offset + 3)};
      }
      offset += bytes.readUInt16BE(offset);
    }
  }
  if (bytes.toString('ascii', 0, 4) === 'RIFF' && bytes.toString('ascii', 8, 12) === 'WEBP') {
    const type = bytes.toString('ascii', 12, 16);
    if (type === 'VP8X') return {width: 1 + bytes.readUIntLE(24, 3), height: 1 + bytes.readUIntLE(27, 3)};
    if (type === 'VP8 ') return {width: bytes.readUInt16LE(26) & 0x3fff, height: bytes.readUInt16LE(28) & 0x3fff};
    if (type === 'VP8L') {
      const bits = bytes.readUInt32LE(21);
      return {width: (bits & 0x3fff) + 1, height: ((bits >>> 14) & 0x3fff) + 1};
    }
  }
  throw new Error('Unsupported image header');
}

function withDOM(run) {
  const dom = new JSDOM(html());
  try { return run(dom.window.document); } finally { dom.window.close(); }
}

test('new sections have named headings and preserve the independent bridal section', () => withDOM(d => {
  assert.equal(d.querySelectorAll('.luxury-hero').length, 1);
  assert.equal(d.querySelectorAll('.luxury-editorial').length, 1);
  assert.equal(d.querySelectorAll('h1').length, 1);
  for (const section of d.querySelectorAll('.luxury-hero, .luxury-editorial')) {
    assert.ok(d.getElementById(section.getAttribute('aria-labelledby')));
    assert.equal(section.classList.contains('campaign'), false);
  }
  assert.equal(d.querySelectorAll('.editorial-campaign').length, 1);
  assert.equal(normalize(d.querySelector('.editorial-campaign h2').textContent), 'El edit de novias');
}));

test('only the new lead receives high priority; all supporting and editorial images are lazy', () => withDOM(d => {
  const lead = d.querySelector('.luxury-hero__lead img');
  assert.equal(lead.getAttribute('src'), '/generated-luxury/champagne/01-front-v1.png');
  assert.equal(lead.getAttribute('fetchpriority'), 'high');
  assert.equal(lead.getAttribute('loading'), 'eager');
  assert.equal(d.querySelectorAll('img[fetchpriority="high"]').length, 1);
  const others = [...d.querySelectorAll('.luxury-hero img, .luxury-editorial img')].filter(img => img !== lead);
  assert.equal(others.length, 8);
  for (const img of others) {
    assert.equal(img.getAttribute('loading'), 'lazy');
    assert.notEqual(img.getAttribute('fetchpriority'), 'high');
  }
}));

test('all 44 derivative byte hashes and actual image headers agree with provenance and whole-frame scaling', () => {
  assert.equal(manifest.assets.length, 6);
  assert.equal(assets.size, 44);
  for (const [relative, record] of assets) {
    assert.match(relative, /^\/editorial\/[A-Za-z0-9_-]+\.(jpg|webp)$/);
    const bytes = fs.readFileSync(path.join(dist, relative));
    assert.equal(bytes.length, record.bytes, relative);
    assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'), record.sha256, relative);
    assert.deepEqual(dimensions(bytes), {width: record.width, height: record.height}, relative);
    assert.equal(record.source_sha256, record.original.sha256, relative);
    assert.equal(record.full_source_frame, true, relative);
    assert.equal(record.metadata_stripped, true, relative);
    assert.ok(record.width <= record.original.width, relative);
    assert.equal(record.height, Math.round(record.original.height * record.width / record.original.width), relative);
  }
});

function assertCurrentImages(d) {
  // The preserved publication pins the entire authored page after delivery additions are removed.
  assert.equal(hash(html().replace(/<source data-responsive-generated=""[^>]+>/g, '')), release['index.html'].sha256);
  assert.match(d.querySelector('meta[name="robots"]').content, /noindex/);
  for (const img of d.querySelectorAll('.luxury-hero img, .luxury-editorial img')) {
    const url=img.getAttribute('src'), record=selected.get(url), derived=responsive.get(url);
    assert.ok(record, 'Independent publication selection: '+url);
    const bytes=fs.readFileSync(path.join(dist,url));
    assert.equal(hash(bytes),record.sha256);
    assert.deepEqual(dimensions(bytes), {width:record.dimensions[0],height:record.dimensions[1]});
    assert.equal(+img.getAttribute('width'),record.dimensions[0]);
    assert.equal(+img.getAttribute('height'),record.dimensions[1]);
    assert.match(img.alt,/Imagen generada con IA/);
    assert.equal(img.getAttribute('decoding'),'async');
    assert.equal(img.getAttribute('srcset'),url+' '+record.dimensions[0]+'w');
    assert.ok(derived); assert.equal(derived.sha256,record.sha256);
    assert.equal(derived.full_source_frame,true);
    const picture=img.closest('picture');
    const fallback=picture.querySelector('source[type="image/png"]');
    assert.equal(fallback.getAttribute('srcset'),img.getAttribute('srcset'));
    assert.equal(picture.querySelectorAll('source[type="image/webp"]').length,1);
    for (const source of picture.querySelectorAll('source[type="image/webp"]')) {
      assert.ok(source.hasAttribute('data-responsive-generated'));
      assert.equal(source.getAttribute('sizes'),img.getAttribute('sizes'));
      assert.equal(source.getAttribute('srcset'),derived.derivatives.map(r=>r.path+' '+r.width+'w').join(', '));
      for(const r of derived.derivatives) {
        const data=fs.readFileSync(path.join(dist,r.path));
        assert.equal(hash(data),r.sha256);
        assert.deepEqual(dimensions(data),{width:r.width,height:r.height});
        assert.equal(r.height,Math.round(record.dimensions[1]*r.width/record.dimensions[0]));
      }
    }
  }
}
test('published generated images keep exact identity, IA labels, dimensions and whole-frame fallbacks',()=>withDOM(assertCurrentImages));
test('identity and IA-label guards reject independent negative controls',()=>withDOM(d=>{
  const img=d.querySelector('.luxury-hero img'), alt=img.alt, src=img.getAttribute('src');
  img.alt='Fotografia original'; assert.throws(()=>assertCurrentImages(d)); img.alt=alt;
  img.setAttribute('src','/generated-luxury/rosa/01-front-v1.png');
  assert.throws(()=>assertCurrentImages(d)); img.setAttribute('src',src);
  const source=img.closest('picture').querySelector('source[type="image/webp"]');
  source.remove(); assert.throws(()=>assertCurrentImages(d)); img.closest('picture').prepend(source); assertCurrentImages(d);
}));
test('six generated editorial illustrations retain historic post context without purchase bindings',()=>withDOM(d=>{
  const cards=[...d.querySelectorAll('.luxury-editorial__card')];assert.equal(cards.length,6);
  const posts=new Set(manifest.assets.map(a=>a.post_id)), seen=new Set();
  for(const card of cards){
    const img=card.querySelector('img'),post=img.getAttribute('data-luxury-editorial').replace(/-\d+$/,'');
    assert.ok(posts.has(post));seen.add(post);
    const link=card.querySelector('a');assert.equal(link.href,'https://www.instagram.com/p/'+post+'/');
    assert.equal(link.target,'_blank');assert.ok(link.rel.split(/\s+/).includes('noopener'));
    assert.ok(link.rel.split(/\s+/).includes('noreferrer'));
    assert.equal(card.querySelector('[data-product-card], [data-add-to-cart], [data-variant], button'),null);
    assert.match(img.alt,/Imagen generada con IA/);
  }
  assert.equal(seen.size,6);assert.equal(manifest.editorial_only,true);
}));

test('scoped CSS retains contain fit, focus visibility, and reduced-motion handling', () => {
  const css = fs.readFileSync(path.join(dist, 'styles.css'), 'utf8');
  assert.match(css, /\.luxury-hero[^{}]*img[^{}]*\{[^}]*object-fit\s*:\s*contain/s);
  assert.match(css, /\.luxury-editorial[^{}]*img[^{}]*\{[^}]*object-fit\s*:\s*contain/s);
  assert.match(css, /\.luxury-[^{}]*:focus-visible/);
  assert.match(css, /@media\s*\(prefers-reduced-motion:\s*reduce\)[\s\S]*\.luxury-/);
});

test('Spanish default and English toggle translate every new visible/accessible string and restore Spanish', async () => {
  const errors = [];
  const virtualConsole = new VirtualConsole();
  virtualConsole.on('jsdomError', error => errors.push(error.message));
  const dom = new JSDOM(html(), {url: 'https://demo.test/index.html', runScripts: 'outside-only', virtualConsole});
  const w = dom.window;
  try {
    const records = [];
    for (const section of w.document.querySelectorAll('.luxury-hero, .luxury-editorial')) {
      const walker = w.document.createTreeWalker(section, w.NodeFilter.SHOW_TEXT);
      while (walker.nextNode()) {
        const node = walker.currentNode;
        if (node.parentElement.closest('[aria-hidden="true"]')) continue;
        const value = normalize(node.textContent);
        if (/[\p{L}]/u.test(value)) records.push({node, value});
      }
      for (const element of section.querySelectorAll('[alt], [aria-label], [title]')) {
        for (const attribute of ['alt', 'aria-label', 'title']) {
          const value = element.getAttribute(attribute);
          if (value) records.push({node: element, attribute, value: normalize(value)});
        }
      }
    }
    for (const file of ['catalog.js', 'locale-en.js', 'i18n.js']) w.eval(fs.readFileSync(path.join(dist, file), 'utf8'));
    assert.match(w.document.documentElement.lang, /^es(?:-|$)/);
    for (const record of records) assert.ok(Object.hasOwn(w.MARTHA_EN, record.value), 'Missing authored English: ' + record.value);
    const values = () => records.map(record => normalize(record.attribute ? record.node.getAttribute(record.attribute) : record.node.textContent));
    w.MarthaI18n.setLanguage('en');
    assert.equal(w.document.documentElement.lang, 'en');
    assert.deepEqual(values(), records.map(record => w.MARTHA_EN[record.value]));
    w.MarthaI18n.setLanguage('es');
    assert.match(w.document.documentElement.lang, /^es(?:-|$)/);
    assert.deepEqual(values(), records.map(record => record.value));
    assert.deepEqual(errors, []);
  } finally { w.close(); }
});

test('published sample catalog remains pinned independently; original-catalog suite owns commerce and historical stages',()=>{
  const bytes=fs.readFileSync(path.join(dist,'catalog.js'));
  assert.deepEqual(bytes,fs.readFileSync(path.join(root,'build-inputs/static/catalog.js')));
  assert.equal(hash(bytes),publication.source_catalog_sha256);
  assert.equal(publication.source_catalog_sha256,release['catalog.js'].sha256);
  const dom=new JSDOM('',{runScripts:'outside-only'});
  try{dom.window.eval(bytes.toString('utf8'));const c=dom.window.DEMO_CATALOG;
    assert.equal(c.products.length,40);assert.equal(c.products.reduce((n,p)=>n+p.variants.length,0),120);
    assert.equal(c.products.reduce((n,p)=>n+p.images.length,0),152);
    assert.equal(c.brand.commercial_status,'sample');
  }finally{dom.window.close();}
});
