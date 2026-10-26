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
const html = () => fs.readFileSync(path.join(dist, 'index.html'), 'utf8');
const normalize = value => value.replace(/\s+/g, ' ').trim();

function dimensions(bytes) {
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
  assert.match(lead.getAttribute('src'), /^\/editorial\/DdXjMXIFHwT-/);
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

test('every new image has truthful fallback dimensions and responsive candidates from the same original', () => withDOM(d => {
  const referenced = new Set();
  for (const img of d.querySelectorAll('.luxury-hero img, .luxury-editorial img')) {
    const fallback = assets.get(img.getAttribute('src'));
    assert.ok(fallback, img.getAttribute('src'));
    assert.equal(Number(img.getAttribute('width')), fallback.width);
    assert.equal(Number(img.getAttribute('height')), fallback.height);
    assert.ok(img.getAttribute('alt')?.trim());
    assert.equal(img.getAttribute('decoding'), 'async');
    const source = img.closest('picture').querySelector('source[type="image/webp"]');
    assert.ok(source);
    for (const element of [source, img]) {
      assert.ok(element.getAttribute('sizes'));
      const candidates = element.getAttribute('srcset').split(',').map(value => value.trim().split(/\s+/));
      assert.ok(candidates.length >= 2);
      for (const [url, width] of candidates) {
        const asset = assets.get(url);
        assert.ok(asset, url);
        assert.equal(asset.source_sha256, fallback.source_sha256, url);
        assert.equal(width, asset.width + 'w', url);
        referenced.add(url);
      }
    }
  }
  assert.ok(referenced.size > 0, 'Responsive image paths were checked');
}));

test('six editorial photos link to their authentic posts without product or purchase bindings', () => withDOM(d => {
  const cards = [...d.querySelectorAll('.luxury-editorial__card')];
  assert.equal(cards.length, 6);
  assert.equal(new Set(cards.map(card => assets.get(card.querySelector('img').getAttribute('src')).post)).size, 6);
  for (const card of cards) {
    const link = card.querySelector('a');
    const asset = assets.get(card.querySelector('img').getAttribute('src'));
    assert.equal(link.href, 'https://www.instagram.com/p/' + asset.post + '/');
    assert.equal(link.getAttribute('target'), '_blank');
    assert.ok(link.rel.split(/\s+/).includes('noopener'));
    assert.ok(link.rel.split(/\s+/).includes('noreferrer'));
    assert.equal(card.querySelector('[data-product-card], [data-add-to-cart], [data-variant], button'), null);
  }
  assert.equal(manifest.editorial_only, true);
  assert.match(normalize(d.querySelector('.luxury-editorial').textContent), /editorial/i);
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

test('the catalog stays a byte-identical 40-product / 120-variant / 170-gallery sample baseline', () => {
  const bytes = fs.readFileSync(path.join(dist, 'catalog.js'));
  // SHA from the verified 67d4647d5ee65c65dd037d2e664fcdc45c7009d6 runtime marker.
  assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'), 'e5d0d4fad22ba4ccb69ebda8b6888ca54185b87260f4715be52bea3a79794134');
  const dom = new JSDOM('', {runScripts: 'outside-only'});
  try {
    dom.window.eval(bytes.toString('utf8'));
    const catalog = dom.window.DEMO_CATALOG;
    assert.equal(catalog.products.length, 40);
    assert.equal(catalog.products.reduce((sum, product) => sum + product.variants.length, 0), 120);
    assert.equal(catalog.products.reduce((sum, product) => sum + product.images.length, 0), 170);
    assert.equal(catalog.brand.commercial_status, 'sample');
    assert.equal(bytes.includes(Buffer.from('/editorial/')), false);
  } finally { dom.window.close(); }
});
