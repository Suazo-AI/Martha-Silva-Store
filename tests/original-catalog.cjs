'use strict';
// Captured commercial data and historical photos remain independently checked.
// Current media is authorized by the preserved luxury publication, not by itself.
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
const publication = require('./fixtures/published-catalog-contract.json');
const release = require('../evidence/releases/20261030/current-runtime-sha256.json');
const selected = require('../evidence/releases/20261030/luxury-selected-assets.json');
const root = path.resolve(__dirname, '..');
const context = {window:{}};
const catalogSource = fs.readFileSync(path.join(root, 'build-inputs/static/catalog.js'));
vm.runInNewContext(catalogSource.toString('utf8'), context);
const catalog = JSON.parse(JSON.stringify(context.window.DEMO_CATALOG));
const media = JSON.parse(JSON.stringify(context.window.STORE_MEDIA));
const dimensions = JSON.parse(JSON.stringify(context.window.STORE_IMAGE_DIMENSIONS));
const allowed = new Set(evidence.sources.flatMap(source => source.media_paths));
const localMedia = /^\/(?:research\/assets|generated-luxury)\/[A-Za-z0-9_./-]+\.(?:jpg|jpeg|png|webp|mp4|webm)$/;
const referencePattern = /\/(?:research\/assets|generated-luxury)\/[A-Za-z0-9_./-]+\.(?:jpg|jpeg|png|webp|mp4|webm)/g;

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
const publishedMedia = {};
const selectedImages = new Map();
for (const product of original.products) {
  const records = selected.selected_assets.filter(record => record.product_id === product.id)
    .sort((left, right) => left.runtime_destination.localeCompare(right.runtime_destination));
  assert.ok(records.length, 'No published image selection for ' + product.id);
  for (const record of records) {
    const reference = '/' + record.runtime_destination;
    assert.ok(!selectedImages.has(reference), 'Duplicate product image selection: ' + reference);
    selectedImages.set(reference, record);
  }
  const images = records.map(record => '/' + record.runtime_destination);
  const sets = records.map(record => '/' + record.runtime_destination + ' ' + record.dimensions[0] + 'w');
  publishedMedia[product.id] = {...originalMedia[product.id], images, jpeg_images: images,
    image_sets: sets, jpeg_sets: sets,
    image_labels: images.map(() => 'Imagen generada con IA · vista completa'),
    video_poster: images[0]};
}
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
  assert.ok(allowed.has(reference) || approvedPaths.has(reference) || selectedImages.has(reference),
    'unrecorded/unapproved reference: ' + reference);
}

function assertProducts(actual) {
  assert.equal(actual.mode, 'local_test');
  assert.equal(actual.brand.commercial_status, 'sample');
  assert.equal(actual.products.length, 40);
  assert.equal(new Set(actual.products.map(product => product.id)).size, 40);
  assert.equal(actual.products.reduce((count, product) => count + product.variants.length, 0), 120);
  assert.deepEqual(actual.products.map(product => product.id), original.products.map(product => product.id));
  for (const [index, product] of actual.products.entries()) {
    const overrides = publication.copy_overrides[product.id] || {};
    assert.ok(Object.keys(overrides).every(key => ['name', 'description'].includes(key)),
      'Copy exceptions must not override commerce: ' + product.id);
    for (const [key, value] of Object.entries(original.products[index])) {
      if (key !== 'images') assert.deepEqual(product[key], overrides[key] ?? value, product.id + ':' + key);
    }
    assert.equal(product.commercial_status, 'sample');
    assert.deepEqual(product.images, publishedMedia[product.id].images);
    for (const [key, value] of Object.entries(publishedMedia[product.id]))
      assert.deepEqual(product[key], value, product.id + ':' + key);
  }
}

test('all 40 products retain captured prices, variants and stock plus explicit published copy/media changes', () => {
  assert.equal(hash(catalogSource), publication.source_catalog_sha256, 'published catalog pin');
  assert.equal(publication.source_catalog_sha256, release['catalog.js'].sha256);
  assertProducts(catalog);
});

function assertPublishedMedia(actual) {
  assert.deepEqual(actual, publishedMedia, 'media must match the independent published selection');
  assert.equal(Object.keys(actual).length, 40);
  assert.equal(Object.values(actual).reduce((count, item) => count + item.images.length, 0), 152);
  assert.equal(selectedImages.size, 152);
  const candidateReferences = new Set();
  for (const product of catalog.products) {
    const item = actual[product.id];
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
        if (selectedImages.has(reference)) {
          assert.equal(width,selectedImages.get(reference).dimensions[0]+'w','false descriptor: '+reference);
          candidateReferences.add(reference);
        }
      }
    }
    for (const key of ['video', 'video_webm', 'video_poster']) if (item[key]) assertReference(item[key]);
  }
  assert.deepEqual([...candidateReferences].sort(), [...selectedImages.keys()].sort(),
    'every published product image must be referenced');
}

test('all 40 current media records match the 152 independently recorded product-image selections', () => {
  assertPublishedMedia(media);
});

test('every rendered gallery, responsive image and product-video file exists locally without symlinks', () => {
  const references = new Set(JSON.stringify(media).match(referencePattern));
  const expected = new Set(JSON.stringify(publishedMedia).match(referencePattern));
  assert.equal(references.size, 202, '152 selected PNGs and 50 retained product-video files');
  assert.deepEqual([...references].sort(), [...expected].sort());
  for (const reference of references) { assertReference(reference); regularFile(reference); }
  for (const [reference, record] of selectedImages) {
    const bytes = fs.readFileSync(regularFile(reference));
    assert.equal(bytes.length, record.bytes, reference);
    assert.equal(hash(bytes), record.sha256, reference);
    assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a', reference);
    const size = [bytes.readUInt32BE(16), bytes.readUInt32BE(20)];
    assert.deepEqual(size, record.dimensions, reference);
    assert.deepEqual(dimensions[reference], size, reference);
  }
});

test('all 774 historical media references remain available separately from the current selection', () => {
  const references = new Set(JSON.stringify(originalMedia).match(referencePattern));
  assert.equal(references.size, 774);
  for (const reference of references) { assertReference(reference); regularFile(reference); }
  // The previous 169-photo Green stage remains a separate, internally consistent contract.
  assert.equal(Object.values(expectedMedia).reduce((count, item) => count + item.images.length, 0), 169);
  for (const [id, item] of Object.entries(expectedMedia)) {
    if (id !== GREEN) assert.deepEqual(item, originalMedia[id], id);
    for (const reference of new Set(JSON.stringify(item).match(referencePattern))) {
      assertReference(reference); regularFile(reference);
    }
  }
});

test('commerce checks reject price, stock and variant mutations despite published media exceptions', () => {
  for (const field of ['price', 'stock', 'variant']) {
    const changed = structuredClone(catalog);
    if (field === 'price') changed.products[0].price_minor++;
    if (field === 'stock') changed.products[0].variants[0].stock++;
    if (field === 'variant') changed.products[0].variants[0].id = 'unapproved';
    assert.throws(() => assertProducts(changed), assert.AssertionError, field);
  }
});

test('current media checks reject missing, cross-product and false-width references', () => {
  for (const mutation of ['missing', 'cross-product', 'width']) {
    const changed = structuredClone(media);
    const ids = Object.keys(changed);
    if (mutation === 'missing') changed[ids[0]].images.pop();
    if (mutation === 'cross-product') changed[ids[0]].images[0] = changed[ids[1]].images[0];
    if (mutation === 'width') changed[ids[0]].image_sets[0] = changed[ids[0]].images[0] + ' 1w';
    assert.throws(() => assertPublishedMedia(changed), assert.AssertionError, mutation);
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
