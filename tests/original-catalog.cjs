'use strict';
// Focused Green media exception; captured fixtures remain historical and intact.
// Historical capture fixtures remain intact; one independently reviewed Green exception.
// Captured public demo data and observed media, never commercial inventory.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const crypto = require('node:crypto');
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
const dimensions = JSON.parse(JSON.stringify(context.window.STORE_IMAGE_DIMENSIONS));
const allowed = new Set(evidence.sources.flatMap(source => source.media_paths));
const localMedia = /^\/research\/assets\/[A-Za-z0-9_./-]+\.(?:jpg|jpeg|png|webp|mp4|webm)$/;

const selection = require('../evidence/green-photo-borders/selection.json');
const GREEN = 'verde-brillo-cuello-cruzado';
const PREFIX = `/research/assets/store-media/${GREEN}/cropped-v1/`;
const ACTIVE = [1, 3, 4, 5];
const GREEN_FIELDS = ['images', 'jpeg_images', 'image_sets', 'jpeg_sets', 'image_labels', 'video_poster'];
const FAMILIES = ['01-front-full-length', '03-side-full-length', '04-back-full-length', '05-detail-crop'];
// This finite allowlist is the approved delivery contract, NOT catalog-derived output.
const approvedGrid = FAMILIES.flatMap((family, index) =>
  (index === 3 ? [[320,296],[432,399]] : [[320,569],[480,854],[570,1014]])
    .flatMap(([width,height]) => ['jpg','webp'].map(extension =>
      ({path:`${PREFIX}${family}-${width}.${extension}`,width,height}))));
const approvedPaths = new Set(approvedGrid.map(value => value.path));
const reviewedVariants = new Map(selection.variants.map(value => [value.path, value]));
const expectedMedia = JSON.parse(JSON.stringify(originalMedia));
expectedMedia[GREEN] = selection.expected_media;
const staticRoot = path.join(root, 'build-inputs/static');
function hash(bytes) { return crypto.createHash('sha256').update(bytes).digest('hex'); }
function regularFile(reference) {
  assert.match(reference, localMedia);
  assert.ok(!reference.split('/').includes('..'), reference);
  const relative = reference.slice(1);
  let current = staticRoot;
  for (const part of relative.split('/')) {
    current = path.join(current, part);
    assert.ok(!fs.lstatSync(current).isSymbolicLink(), 'symlink: ' + reference);
  }
  assert.ok(fs.statSync(current).isFile(), reference);
  assert.ok(fs.statSync(current).size > 0, 'empty media: ' + reference);
  return current;
}
function walkFiles(directory, prefix = '') {
  return fs.readdirSync(directory, {withFileTypes:true}).flatMap(entry => {
    assert.ok(!entry.isSymbolicLink(), 'symlink in candidate namespace: ' + entry.name);
    const name = prefix + entry.name;
    if (entry.isDirectory()) return walkFiles(path.join(directory, entry.name), name + '/');
    assert.ok(entry.isFile(), 'not a regular candidate file: ' + name);
    return [PREFIX + name];
  });
}

test('the independent Green selection authorizes exactly four photos, six fields and 22 variants', () => {
  assert.equal(selection.schema, 1);
  assert.equal(selection.scope, 'green-photo-crop-v1');
  assert.equal(selection.base_source, 'e2a475961a0056ac6609a86e34a2a58c05e37707');
  assert.equal(selection.product_id, GREEN);
  assert.deepEqual(selection.active_positions, ACTIVE);
  assert.deepEqual(selection.excluded_positions, [2]);
  assert.equal(selection.rows.length, 4);
  assert.deepEqual(selection.rows.map(row => row.position), ACTIVE);
  assert.equal(Object.values(originalMedia).reduce((count,item) => count + item.images.length,0),170,
    'historical 170-photo capture is preserved, not rewritten');
  assert.deepEqual(Object.keys(selection.expected_media).sort(), Object.keys(originalMedia[GREEN]).sort());
  const changed = Object.keys(originalMedia[GREEN]).filter(key =>
    JSON.stringify(selection.expected_media[key]) !== JSON.stringify(originalMedia[GREEN][key]));
  assert.deepEqual(changed.sort(), [...GREEN_FIELDS].sort(), 'the exception must be exactly six Green media fields');
  for (const key of Object.keys(originalMedia[GREEN]))
    if (!GREEN_FIELDS.includes(key)) assert.deepEqual(selection.expected_media[key], originalMedia[GREEN][key],key);
  assert.deepEqual(selection.expected_media.image_labels, ACTIVE.map(position => originalMedia[GREEN].image_labels[position-1]));
  for (const [index,family] of FAMILIES.entries()) {
    const maximum = index === 3 ? 432 : 570;
    assert.equal(selection.expected_media.images[index],`${PREFIX}${family}-${maximum}.webp`);
    assert.equal(selection.expected_media.jpeg_images[index],`${PREFIX}${family}-${maximum}.jpg`);
    for (const key of ['image_sets','jpeg_sets']) {
      const entries=selection.expected_media[key][index].split(',').map(value=>value.trim().split(/\s+/));
      assert.equal(entries.length,index===3?2:3);
      const extension=key==='image_sets'?'webp':'jpg';
      const exact=approvedGrid.filter(value=>value.path.startsWith(PREFIX+family+'-') && value.path.endsWith('.'+extension))
        .map(value=>`${value.path} ${value.width}w`).join(', ');
      assert.equal(selection.expected_media[key][index],exact,'exact family/encoding/width contract: '+key);
    }
  }
  assert.equal(selection.expected_media.video_poster,`${PREFIX}01-front-full-length-480.webp`);
  assert.equal(selection.variants.length,22);
  assert.equal(reviewedVariants.size,22,'no duplicate declared paths');
  assert.equal(new Set(selection.variants.map(value => value.path.toLowerCase())).size,22,'no case aliases');
  assert.deepEqual([...reviewedVariants.keys()].sort(), [...approvedPaths].sort());
  for (const expected of approvedGrid) {
    const declared = reviewedVariants.get(expected.path);
    assert.equal(declared.width,expected.width,expected.path);
    assert.equal(declared.height,expected.height,expected.path);
    assert.match(declared.sha256,/^[a-f0-9]{64}$/);
    assert.deepEqual(dimensions[expected.path],[expected.width,expected.height],expected.path);
    assert.equal(hash(fs.readFileSync(regularFile(expected.path))),declared.sha256,expected.path);
  }
  // The dedicated new namespace may contain exactly the reviewed files, no extras.
  assert.deepEqual(walkFiles(path.join(staticRoot,PREFIX.slice(1))).sort(),[...approvedPaths].sort());
});

test('the 18 original Green raster files remain byte-identical and available', () => {
  const originals = [...new Set(JSON.stringify(originalMedia[GREEN]).match(/\/research\/assets\/[A-Za-z0-9_./-]+\.(?:jpg|webp)/g))];
  assert.equal(originals.length,18);
  assert.equal(selection.preserved_originals.length,18);
  assert.equal(new Set(selection.preserved_originals.map(value => value.path)).size,18);
  assert.deepEqual(selection.preserved_originals.map(value => value.path).sort(),originals.sort());
  for (const original of selection.preserved_originals) {
    assert.match(original.sha256,/^[a-f0-9]{64}$/);
    const bytes=fs.readFileSync(regularFile(original.path));
    assert.equal(bytes.length,original.bytes,original.path);
    assert.equal(hash(bytes),original.sha256,original.path);
    assert.deepEqual(dimensions[original.path],[original.width,original.height],original.path);
  }
});


function assertReference(reference) {
  assert.match(reference, localMedia);
  assert.ok(!reference.split('/').includes('..'), reference);
  assert.ok(allowed.has(reference) || approvedPaths.has(reference), 'unrecorded/unapproved reference: ' + reference);
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
    assert.deepEqual(product.images, expectedMedia[product.id].images);
  }
});

test('other 39 products remain exact; Green alone uses its independently approved media selection', () => {
  assert.deepEqual(media, expectedMedia);
  for (const id of Object.keys(originalMedia)) if (id !== GREEN) assert.deepEqual(media[id], originalMedia[id],id);
  assert.equal(Object.keys(media).length, 40);
  assert.equal(Object.values(media).reduce((count, item) => count + item.images.length, 0), 169);
  const candidateReferences = new Set();
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
        if (approvedPaths.has(reference)) {
          assert.equal(width,reviewedVariants.get(reference).width+'w','false descriptor: '+reference);
          candidateReferences.add(reference);
        }
      }
    }
    for (const key of ['video', 'video_webm', 'video_poster']) if (item[key]) assertReference(item[key]);
  }
  assert.deepEqual([...candidateReferences].sort(),[...approvedPaths].sort(),'every approved responsive variant must be referenced');
});

test('every rendered gallery, responsive image and product-video file exists locally without symlinks', () => {
  const references = new Set(JSON.stringify(media).match(/\/research\/assets\/[A-Za-z0-9_./-]+\.(?:jpg|jpeg|png|webp|mp4|webm)/g));
  assert.ok(references.size > 700);
  for (const reference of references) { assertReference(reference); regularFile(reference); }
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
