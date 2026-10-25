'use strict';
// Captured public demo data and observed media, never commercial inventory.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const {createDemoApi} = require('../src/demo-api.js');
const original = require('./fixtures/catalog-expansion.json');
const originalMedia = require('./fixtures/original-store-media.json');
const legacy = require('./fixtures/legacy-catalog.json');
const evidence = require('../evidence/asset-source-manifest.json');
const root = path.resolve(__dirname, '..');
const context = {window:{}};
vm.runInNewContext(fs.readFileSync(path.join(root, 'build-inputs/static/catalog.js'), 'utf8'), context);
const catalog = JSON.parse(JSON.stringify(context.window.DEMO_CATALOG));
const media = JSON.parse(JSON.stringify(context.window.STORE_MEDIA));
const allowed = new Set(evidence.sources.flatMap(source => source.media_paths));
const localMedia = /^\/research\/assets\/[A-Za-z0-9_./-]+\.(?:jpg|jpeg|png|webp|mp4|webm)$/;

function assertReference(reference) {
  assert.match(reference, localMedia);
  assert.ok(!reference.split('/').includes('..'), reference);
  assert.ok(allowed.has(reference), 'unrecorded original reference: ' + reference);
}

test('all 40 original products retain their captured sample prices, variants and stock', () => {
  assert.equal(catalog.mode, 'local_test');
  assert.equal(catalog.brand.commercial_status, 'sample');
  assert.equal(catalog.products.length, 40);
  assert.equal(new Set(catalog.products.map(product => product.id)).size, 40);
  assert.equal(catalog.products.reduce((count, product) => count + product.variants.length, 0), 120);
  assert.deepEqual(catalog.products.map(product => product.id), original.products.map(product => product.id));
  for (const [index, product] of catalog.products.entries()) {
    for (const [key, value] of Object.entries(original.products[index])) {
      if (key !== 'images') assert.deepEqual(product[key], value, product.id + ':' + key);
    }
    assert.equal(product.commercial_status, 'sample');
    assert.deepEqual(product.images, originalMedia[product.id].images);
  }
});

test('the shared STORE_MEDIA and enriched product fields preserve all observed gallery metadata', () => {
  assert.deepEqual(media, originalMedia);
  assert.equal(Object.keys(media).length, 40);
  assert.equal(Object.values(media).reduce((count, item) => count + item.images.length, 0), 170);
  for (const product of catalog.products) {
    const item = media[product.id];
    for (const [key, value] of Object.entries(item)) assert.deepEqual(product[key], value, product.id + ':' + key);
    for (const key of ['jpeg_images', 'image_sets', 'jpeg_sets', 'image_labels']) {
      assert.equal(item[key].length, item.images.length, product.id + ':' + key);
    }
    for (const image of [...item.images, ...item.jpeg_images]) assertReference(image);
    for (const srcset of [...item.image_sets, ...item.jpeg_sets]) {
      for (const candidate of srcset.split(',')) {
        const [reference, width, extra] = candidate.trim().split(/\s+/);
        assertReference(reference);
        assert.match(width, /^[1-9][0-9]*w$/);
        assert.equal(extra, undefined);
      }
    }
    for (const key of ['video', 'video_webm', 'video_poster']) if (item[key]) assertReference(item[key]);
  }
});

test('every rendered gallery, responsive image and product-video file exists locally without symlinks', () => {
  const references = new Set(JSON.stringify(media).match(/\/research\/assets\/[A-Za-z0-9_./-]+\.(?:jpg|jpeg|png|webp|mp4|webm)/g));
  assert.ok(references.size > 700);
  const staticRoot = path.join(root, 'build-inputs/static');
  for (const reference of references) {
    assertReference(reference);
    const relative = reference.slice(1);
    const target = path.join(staticRoot, relative);
    let current = staticRoot;
    for (const part of relative.split('/')) {
      current = path.join(current, part);
      assert.ok(!fs.lstatSync(current).isSymbolicLink(), 'symlink: ' + reference);
    }
    assert.ok(fs.statSync(target).isFile(), reference);
    assert.ok(fs.statSync(target).size > 0, 'empty media: ' + reference);
  }
});

test('the served full catalog supports the real legacy six-to-120 variant migration', async () => {
  const saved = new Map();
  const storage = {getItem:key => saved.get(key) ?? null, setItem:(key, value) => saved.set(key, value)};
  const oldApi = createDemoApi(legacy, storage);
  const variant = legacy.products[0].variants[0].id;
  await oldApi('/api/cart/items', {variant_id:variant, quantity:2});
  const before = JSON.parse(saved.get('martha-parity-v2-demo-state-1'));
  const api = createDemoApi(catalog, storage);
  assert.equal((await api('/api/catalog')).products.length, 40);
  assert.equal((await api('/api/cart')).lines[0].quantity, 2);
  const after = JSON.parse(saved.get('martha-parity-v2-demo-state-1'));
  assert.equal(Object.keys(after.stock).length, 120);
  assert.deepEqual({...after, stock:before.stock}, before);
  assert.equal(saved.get('martha-parity-v2-demo-state-1-recovery'), undefined);
});
