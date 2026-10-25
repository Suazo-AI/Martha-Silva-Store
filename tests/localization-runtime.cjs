'use strict';
// Serial DOM simulation only. This does not establish browser layout or image decoding.
// Reuse an existing locked installation with MARTHA_JSDOM_PATH when needed.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {JSDOM, VirtualConsole} = require(process.env.MARTHA_JSDOM_PATH || './frontend-deps/node_modules/jsdom');
const root = path.resolve(__dirname, '../dist');
const tick = () => new Promise(resolve => setTimeout(resolve, 12));
const text = element => element?.textContent.replace(/\s+/g, ' ').trim();
const tests = [];
const test = (name, run) => tests.push([name, run]);

async function boot(page, {language, query = '', stored, app = true, setup, beforeLocale} = {}) {
  const errors = [];
  const vc = new VirtualConsole();
  vc.on('jsdomError', error => errors.push(error.message));
  const dom = new JSDOM(fs.readFileSync(path.join(root, page), 'utf8'), {
    url: 'https://demo.test/' + page + query, runScripts: 'outside-only',
    pretendToBeVisual: true, virtualConsole: vc,
  });
  const w = dom.window;
  try {
    w.matchMedia = () => ({matches: false, addEventListener() {}});
    w.IntersectionObserver = class { observe() {} disconnect() {} };
    w.CSS = {escape: value => value};
    w.HTMLElement.prototype.scrollIntoView = function () {};
    w.HTMLElement.prototype.scrollTo = function () {};
    w.scrollTo = () => {};
    w.HTMLMediaElement.prototype.pause = function () {};
    w.HTMLDialogElement.prototype.showModal = function () {
      this.open = true; this.querySelector('button,input,select')?.focus();
    };
    w.HTMLDialogElement.prototype.close = function () {
      this.open = false; this.dispatchEvent(new w.Event('close'));
    };
    for (const [key, value] of Object.entries(stored || {})) w.localStorage.setItem(key, value);
    if (language) w.localStorage.setItem('martha-language-v1', language);
    if (beforeLocale) beforeLocale(w);
    for (const file of ['catalog.js', 'locale-en.js', 'i18n.js']) w.eval(fs.readFileSync(path.join(root, file), 'utf8'));
    if (app) {
      for (const file of ['demo-api.js', 'integration-adapters.js']) w.eval(fs.readFileSync(path.join(root, file), 'utf8'));
    }
    if (setup) await setup(w);
    if (app) w.eval(fs.readFileSync(path.join(root, 'app.js'), 'utf8'));
    await tick(); await tick();
    return {dom, w, d: w.document, errors, close: () => w.close()};
  } catch (error) { w.close(); throw error; }
}

async function withPage(page, options, run) {
  const b = await boot(page, options);
  try { await run(b); assert.deepEqual(b.errors, []); }
  finally { b.close(); }
}

async function seedBag(w) {
  const api = w.MarthaIntegrations.createDemoAdapter({
    mode: 'savia', catalog: w.DEMO_CATALOG, storage: w.localStorage, createDemoApi: w.createMarthaDemoApi,
  });
  await api('/api/cart/items', {variant_id: 'dorado-S', quantity: 1});
}

test('Spanish remains the default and both language controls are accessible', async () => {
  await withPage('index.html', {}, async b => {
    assert.match(b.d.documentElement.lang, /^es(?:-|$)/);
    assert.equal(text(b.d.querySelector('.editorial-campaign h2')), 'El edit de novias');
    for (const lang of ['es', 'en']) assert.ok(b.d.querySelector(`[data-language="${lang}"]`));
    assert.equal(b.d.querySelector('[data-language="es"]').getAttribute('aria-pressed'), 'true');
  });
});

test('an explicit English URL overrides a saved Spanish preference without losing filters', async () => {
  await withPage('catalogo.html', {language: 'es', query: '?category=Novias&lang=en'}, async b => {
    assert.equal(b.d.documentElement.lang, 'en');
    assert.equal(b.w.MarthaI18n.language, 'en');
    assert.equal(b.d.querySelector('[name=category]').value, 'Novias');
    assert.equal(new URL(b.w.location.href).searchParams.get('category'), 'Novias');
    assert.equal(b.d.querySelectorAll('[data-catalog-grid] .product-card').length,
      b.w.DEMO_CATALOG.products.filter(product => product.category === 'Novias').length);
    assert.equal(b.d.querySelector('[data-filter-chips]')?.textContent.includes('lang'), false);
    const category = b.d.querySelector('[name=category]');
    assert.equal(category.selectedOptions[0].value, 'Novias');
    assert.match(category.selectedOptions[0].textContent, /bridal/i);
    b.w.MarthaI18n.setLanguage('es'); await tick();
    assert.equal(category.value, 'Novias');
    assert.equal(category.selectedOptions[0].textContent, 'Novias');
    b.w.MarthaI18n.setLanguage('en'); await tick();
    assert.equal(category.value, 'Novias');
    category.value = 'Gala'; category.dispatchEvent(new b.w.Event('change', {bubbles: true})); await tick();
    assert.equal(new URL(b.w.location.href).searchParams.get('category'), 'Gala');
    assert.equal(b.d.querySelectorAll('[data-catalog-grid] .product-card').length,
      b.w.DEMO_CATALOG.products.filter(product => product.category === 'Gala').length);
    b.w.history.back(); await tick(); await tick();
    assert.equal(category.value, 'Novias');
    assert.equal(b.w.MarthaI18n.language, 'en');
    b.d.querySelector('[data-clear-filters]').click(); await tick();
    assert.equal(new URL(b.w.location.href).searchParams.get('category'), null);
    assert.equal(new URL(b.w.location.href).searchParams.get('lang'), 'en');
    assert.equal(b.d.querySelectorAll('[data-catalog-grid] .product-card').length, 40);
    assert.equal(b.d.querySelector('.catalog-status').classList.contains('has-filters'), false);
  });
});

test('an explicit Spanish URL replaces a saved English preference for subsequent pages', async () => {
  let saved;
  await withPage('index.html', {language: 'en', query: '?lang=es'}, async b => {
    assert.match(b.d.documentElement.lang, /^es(?:-|$)/);
    assert.equal(text(b.d.querySelector('.editorial-campaign h2')), 'El edit de novias');
    saved = b.w.localStorage.getItem('martha-language-v1');
    assert.equal(saved, 'es');
  });
  await withPage('ayuda.html', {stored: {'martha-language-v1': saved}}, async b => {
    assert.match(b.d.documentElement.lang, /^es(?:-|$)/);
    assert.match(text(b.d.querySelector('main')), /Estamos para ayudarte/);
  });
});

test('language switching persists, restores Spanish, and leaves catalog data untouched', async () => {
  await withPage('index.html', {}, async b => {
    const before = JSON.stringify(b.w.DEMO_CATALOG);
    b.d.querySelector('[data-language="en"]').click(); await tick();
    assert.equal(b.d.documentElement.lang, 'en');
    assert.equal(b.w.localStorage.getItem('martha-language-v1'), 'en');
    assert.match(text(b.d.querySelector('.editorial-campaign h2')), /bridal edit/i);
    b.d.querySelector('[data-language="es"]').click(); await tick();
    assert.equal(text(b.d.querySelector('.editorial-campaign h2')), 'El edit de novias');
    assert.equal(b.w.localStorage.getItem('martha-language-v1'), 'es');
    assert.equal(JSON.stringify(b.w.DEMO_CATALOG), before);
  });
  await withPage('ayuda.html', {language: 'en'}, async b => {
    assert.equal(b.d.documentElement.lang, 'en');
    assert.doesNotMatch(text(b.d.querySelector('main')), /Estamos para ayudarte|Entrega, devoluciones|datos ficticios/);
  });
});

test('all 47 templates expose the language controls and English navigation', async () => {
  const pages = fs.readdirSync(root).filter(name => name.endsWith('.html')).sort();
  assert.equal(pages.length, 47);
  for (const page of pages) {
    await withPage(page, {language: 'en', app: false}, async b => {
      assert.equal(b.d.documentElement.lang, 'en', page);
      const scripts = [...b.d.scripts].map(script => script.getAttribute('src'));
      for (const script of ['/locale-en.js', '/i18n.js', '/app.js']) {
        assert.equal(scripts.filter(src => src === script).length, 1, page + ': ' + script);
      }
      assert.ok(scripts.indexOf('/locale-en.js') < scripts.indexOf('/i18n.js'), page);
      assert.ok(scripts.indexOf('/i18n.js') < scripts.indexOf('/app.js'), page);
      assert.equal(b.d.querySelectorAll('.language-bar').length, 1, page);
      assert.ok(b.d.querySelector('[data-language="en"]'), page);
      const nav = b.d.querySelector('.desktop-nav');
      if (nav) {
        assert.doesNotMatch(text(nav), /Todas las prendas|Vestidos de fiesta|Moda femenina|Novias/, page);
        assert.match(text(nav), /Bridal/i, page);
        assert.doesNotMatch(b.d.querySelector('[data-search-open]').getAttribute('aria-label'), /Buscar/, page);
      } else {
        assert.equal(page, 'checkout.html', 'only checkout intentionally uses the compact header');
        assert.ok(b.d.querySelector('.checkout-header'));
        assert.match(text(b.d.querySelector('.checkout-back')), /back to (?:your )?bag/i);
        assert.doesNotMatch(text(b.d.querySelector('.checkout-back')), /Volver|bolsa/);
        assert.match(text(b.d.querySelector('.site-footer')), /bridal/i);
      }
      assert.doesNotMatch(b.d.querySelector('#search-dialog input').getAttribute('placeholder'), /Buscar por/, page);
      const description = b.d.querySelector('meta[name=description]').getAttribute('content');
      assert.doesNotMatch(description, /Vestidos de gala|novias|moda femenina/, page);
    });
  }
});

test('Back restores the English URL language after switching a filtered page to Spanish', async () => {
  await withPage('catalogo.html', {query: '?category=Novias&lang=en'}, async b => {
    const category = b.d.querySelector('[name=category]');
    category.value = 'Gala'; category.dispatchEvent(new b.w.Event('change', {bubbles: true})); await tick();
    b.w.MarthaI18n.setLanguage('es'); await tick();
    assert.match(b.d.documentElement.lang, /^es(?:-|$)/);
    assert.equal(new URL(b.w.location.href).searchParams.get('lang'), 'es');
    b.w.history.back(); await tick(); await tick();
    assert.equal(new URL(b.w.location.href).searchParams.get('lang'), 'en');
    assert.equal(b.d.documentElement.lang, 'en');
    assert.equal(b.w.MarthaI18n.language, 'en');
    assert.equal(b.w.localStorage.getItem('martha-language-v1'), 'en');
    assert.equal(category.value, 'Novias');
    assert.match(category.selectedOptions[0].textContent, /bridal/i);
  });
});

test('mixed text fragments and running totals remain English after dynamic insertion', async () => {
  await withPage('index.html', {language: 'en', app: false}, async b => {
    const status = b.d.createElement('p');
    status.innerHTML = '<span translate="no">Rosa</span> · Solicitud recibida';
    const summary = b.d.createElement('strong'); summary.textContent = 'Total sin entrega USD 185.00';
    b.d.querySelector('main').append(status, summary); await tick();
    assert.match(text(status), /^Rosa · /);
    assert.doesNotMatch(text(status), /Solicitud recibida|Pink/);
    assert.match(text(status), /request received/i);
    assert.match(text(summary), /total before delivery/i);
    assert.ok(text(summary).includes('USD 185.00'));
  });
});

test('English URLs still work when browser storage is unavailable', async () => {
  await withPage('index.html', {query: '?lang=en', app: false, beforeLocale(w) {
    Object.defineProperty(w, 'localStorage', {configurable: true, get() { throw new Error('Storage unavailable in test'); }});
  }}, async b => {
    assert.equal(b.d.documentElement.lang, 'en');
    assert.match(text(b.d.querySelector('.editorial-campaign h2')), /bridal edit/i);
    b.w.MarthaI18n.setLanguage('es'); await tick();
    assert.match(b.d.documentElement.lang, /^es(?:-|$)/);
  });
});

test('an explicit Spanish choice survives reload and navigation when saved English cannot be overwritten', async () => {
  const blockWrites = w => {
    w.Storage.prototype.setItem = function () { throw new Error('Storage writes unavailable in test'); };
  };
  let reloadQuery, navigationQuery;
  await withPage('index.html', {language: 'en', app: false, beforeLocale: blockWrites}, async b => {
    assert.equal(b.w.localStorage.getItem('martha-language-v1'), 'en');
    assert.equal(b.d.documentElement.lang, 'en');
    b.w.MarthaI18n.setLanguage('es'); await tick();
    assert.match(b.d.documentElement.lang, /^es(?:-|$)/);
    assert.equal(b.w.localStorage.getItem('martha-language-v1'), 'en', 'old readable value should remain when writes fail');
    assert.equal(new URL(b.w.location.href).searchParams.get('lang'), 'es');
    reloadQuery = new URL(b.w.location.href).search;
    const link = b.d.querySelector('.desktop-nav a[href*="category=Novias"]');
    assert.ok(link);
    // Run the real capture handler while suppressing jsdom's unsupported navigation.
    link.addEventListener('click', event => event.preventDefault());
    link.click(); await tick();
    const destination = new URL(link.href);
    assert.equal(destination.searchParams.get('category'), 'Novias');
    assert.equal(destination.searchParams.get('lang'), 'es');
    navigationQuery = destination.search;
  });
  for (const [page, query] of [['index.html', reloadQuery], ['catalogo.html', navigationQuery]]) {
    await withPage(page, {language: 'en', app: false, query, beforeLocale: blockWrites}, async b => {
      assert.match(b.d.documentElement.lang, /^es(?:-|$)/, page);
      assert.equal(b.w.MarthaI18n.language, 'es', page);
    });
  }
});

test('all 40 catalog names and descriptions have English translations and product pages use them', async () => {
  let products;
  await withPage('index.html', {language: 'en', app: false}, async b => {
    products = JSON.parse(JSON.stringify(b.w.DEMO_CATALOG.products));
    assert.equal(products.length, 40);
    for (const product of products) {
      assert.notEqual(b.w.MarthaI18n.english(product.name), product.name, product.id + ' name');
      assert.notEqual(b.w.MarthaI18n.english(product.description), product.description, product.id + ' description');
    }
  });
  for (const product of products) {
    await withPage('producto-' + product.id + '.html', {language: 'en', app: false}, async b => {
      assert.equal(text(b.d.querySelector('.product-information h1')), b.w.MarthaI18n.english(product.name), product.id);
      assert.ok(text(b.d.querySelector('main')).includes(b.w.MarthaI18n.english(product.description)), product.id);
      assert.equal(b.d.querySelector('input[name=variant]').value, product.variants[0].id, product.id);
    });
  }
});

test('English product search and color filters retain Spanish data keys', async () => {
  await withPage('catalogo.html', {language: 'en', query: '?q=gold'}, async b => {
    const cards = [...b.d.querySelectorAll('[data-catalog-grid] .product-card')];
    assert.ok(cards.some(card => card.dataset.id === 'dorado'), 'gold search should find dorado');
    const color = b.d.querySelector('[name=color]');
    color.value = 'Dorado';
    assert.equal(color.selectedOptions[0].value, 'Dorado');
    assert.doesNotMatch(color.selectedOptions[0].textContent, /Dorado/);
    color.dispatchEvent(new b.w.Event('change', {bubbles: true})); await tick();
    assert.equal(new URL(b.w.location.href).searchParams.get('color'), 'Dorado');
    for (const card of b.d.querySelectorAll('[data-catalog-grid] .product-card')) {
      assert.equal(b.w.DEMO_CATALOG.products.find(product => product.id === card.dataset.id).color, 'Dorado');
      for (const img of card.querySelectorAll('img[src]')) {
        const dimensions = b.w.STORE_IMAGE_DIMENSIONS[img.getAttribute('src')];
        assert.ok(dimensions);
        assert.equal(Number(img.getAttribute('width')), dimensions[0]);
        assert.equal(Number(img.getAttribute('height')), dimensions[1]);
      }
    }
    assert.match(text(b.d.querySelector('[data-result-count]')), /item|garment|piece/i);
  });
});

test('English favorites, validation, bag updates and stock errors stay translated after mutations', async () => {
  await withPage('producto-dorado.html', {language: 'en'}, async b => {
    const favorite = b.d.querySelector('[data-favorite="dorado"]');
    favorite.click(); await tick();
    assert.match(text(b.d.querySelector('#toast')), /favorite/i);
    assert.doesNotMatch(favorite.getAttribute('aria-label'), /Guardar|Quitar|favoritos/);
    b.d.querySelector('[data-add]').click(); await tick();
    assert.match(text(b.d.querySelector('[data-product-error]')), /size/i);
    assert.doesNotMatch(text(b.d.querySelector('[data-product-error]')), /Elegí|talla|prenda/);
    const size = b.d.querySelector('input[name=variant]:not(:disabled)');
    size.checked = true; size.dispatchEvent(new b.w.Event('change', {bubbles: true}));
    b.d.querySelector('[data-add]').click(); await tick();
    const bag = b.d.querySelector('#mini-bag');
    assert.ok(bag.open);
    assert.match(text(bag.querySelector('#mini-bag-title')), /bag/i);
    const quantity = bag.querySelector('[data-quantity]');
    quantity.value = '10'; quantity.dispatchEvent(new b.w.Event('change', {bubbles: true})); await tick();
    const error = bag.querySelector('[data-error]:not([hidden])');
    assert.ok(error);
    assert.doesNotMatch(text(error), /No hay|unidades|talla/);
    assert.match(text(error), /enough|stock|available/i);
    assert.match(text(b.d.querySelector('[data-stock-note]')), /sample/i);
  });
});

test('a language-qualified checkout link hides when the mini-bag becomes empty and restores on add', async () => {
  await withPage('producto-dorado.html', {language: 'en'}, async b => {
    const add = b.d.querySelector('[data-add]');
    b.d.querySelector('input[name=variant]:not(:disabled)').checked = true;
    add.click(); await tick();
    const bag = b.d.querySelector('#mini-bag');
    const checkout = bag.querySelector('a.button.secondary.full');
    assert.ok(checkout); assert.equal(checkout.hidden, false);
    // The navigation handler adds this query before a visit/Back to the same page.
    checkout.href = '/checkout.html?lang=en';
    bag.querySelector('[data-remove-item]').click(); await tick();
    assert.equal(bag.querySelectorAll('.cart-line').length, 0);
    assert.equal(checkout.hidden, true);
    assert.equal(checkout.getAttribute('aria-disabled'), 'true');
    assert.equal(bag.querySelector('[data-mini-bag-total]').hidden, true);
    bag.querySelector('[data-close-dialog]').click();
    add.click(); await tick();
    assert.equal(bag.querySelectorAll('.cart-line').length, 1);
    assert.equal(checkout.hidden, false);
    assert.equal(checkout.hasAttribute('aria-disabled'), false);
    assert.equal(bag.querySelector('[data-mini-bag-total]').hidden, false);
    assert.equal(new URL(checkout.href).searchParams.get('lang'), 'en');
  });
});

test('English checkout preserves customer text and never translates form values', async () => {
  await withPage('checkout.html', {language: 'en', setup: seedBag}, async b => {
    const original = {name: 'Rosa', email: 'rosatest@example.test', phone: '88888888'};
    for (const [key, value] of Object.entries(original)) b.d.querySelector(`[name=${key}]`).value = value;
    b.d.querySelector('[data-checkout-form=contact]').dispatchEvent(new b.w.Event('submit', {bubbles: true, cancelable: true}));
    await tick();
    assert.match(text(b.d.querySelector('#checkout-stage-title')), /delivery/i);
    for (const [key, value] of Object.entries({line1: 'Calle Rosa', city: 'Rosa', department: 'Managua'})) {
      b.d.querySelector(`[name=${key}]`).value = value;
    }
    b.d.querySelector('[data-checkout-form=delivery]').dispatchEvent(new b.w.Event('submit', {bubbles: true, cancelable: true}));
    await tick();
    const review = b.d.querySelector('.review-block');
    assert.ok(text(review).includes('Calle Rosa'));
    assert.ok(text(review).includes('Rosa'));
    assert.ok(!text(review).includes('Calle Pink'));
    assert.match(text(b.d.querySelector('[data-create-order]')), /(?:test|demo) payment/i);
    assert.doesNotMatch(text(b.d.querySelector('.steps')), /Contacto|Entrega|Revisión|Pago/);
    assert.match(text(b.d.querySelector('.checkout-panel')), /test|sample|simulat/i);
    assert.doesNotMatch(text(b.d.querySelector('.checkout-panel')), /Revisá|Todos los importes|No se cobra/);
    b.w.MarthaI18n.setLanguage('es'); await tick();
    b.w.MarthaI18n.setLanguage('en'); await tick();
    assert.ok(text(b.d.querySelector('.review-block')).includes('Calle Rosa'));
    const saved = JSON.parse(b.w.sessionStorage.getItem('martha-savia-checkout-v1'));
    assert.equal(saved.name, original.name); assert.equal(saved.city, 'Rosa');
  });
});

test('English order views preserve customer-entered return reasons and tracking text', async () => {
  await withPage('pedido.html', {language: 'en', async setup(w) {
    const api = w.MarthaIntegrations.createDemoAdapter({
      mode: 'savia', catalog: w.DEMO_CATALOG, storage: w.localStorage, createDemoApi: w.createMarthaDemoApi,
    });
    await api('/api/cart/items', {variant_id: 'dorado-S', quantity: 1});
    const quote = await api('/api/quote', {delivery_zone: 'managua'});
    const order = (await api('/api/orders', {
      quote_id: quote.id, idempotency_key: 'localization-return-fixture',
      contact: {name: 'Rosa', email: 'rosatest@example.test', phone: '88888888'},
      address: {line1: 'Calle Rosa', city: 'Rosa', department: 'Managua'},
    })).order;
    await api(`/api/orders/${order.id}/test-payment`, {outcome: 'approved'});
    await api('/api/admin/login', {});
    for (const status of ['preparing', 'shipped', 'delivered']) {
      await api(`/api/admin/orders/${order.id}/fulfill`, {status, tracking: 'Rosa'});
    }
    await api(`/api/orders/${order.id}/returns`, {reason: 'Rosa', lines: [{variant_id: 'dorado-S', quantity: 1}]});
    w.history.replaceState(null, '', '/pedido.html?id=' + encodeURIComponent(order.id));
  }}, async b => {
    assert.match(text(b.d.querySelector('.return-card')), /Rosa/);
    assert.doesNotMatch(text(b.d.querySelector('.return-card')), /Pink|Solicitud recibida/);
    assert.match(text(b.d.querySelector('.review-block')), /Calle Rosa/);
    assert.doesNotMatch(text(b.d.querySelector('.review-block')), /Calle Pink/);
  });
});

test('the observer translates newly inserted UI but preserves excluded data and settles', async () => {
  await withPage('index.html', {language: 'en', app: false}, async b => {
    const ui = b.d.createElement('p'); ui.textContent = 'Ver la colección'; b.d.querySelector('main').append(ui);
    const data = b.d.createElement('div'); data.setAttribute('translate', 'no');
    data.innerHTML = '<span>Rosa</span><span>Contacto</span><input value="Rosa">';
    b.d.querySelector('main').append(data); await tick();
    assert.notEqual(text(ui), 'Ver la colección');
    assert.equal(text(data), 'RosaContacto');
    assert.equal(data.querySelector('input').value, 'Rosa');
    b.w.MarthaI18n.apply(); await tick();
    let mutations = 0;
    const observer = new b.w.MutationObserver(records => { mutations += records.length; });
    observer.observe(b.d.documentElement, {subtree: true, characterData: true, childList: true, attributes: true});
    await tick(); await tick(); observer.disconnect();
    assert.equal(mutations, 0, 'translation observer must not keep mutating a settled document');
  });
});

test('static photo dimensions match the independent image-header inventory', async () => {
  const pages = fs.readdirSync(root).filter(name => name.endsWith('.html')).sort();
  let checked = 0;
  for (const page of pages) {
    await withPage(page, {app: false}, async b => {
      const dimensions = b.w.STORE_IMAGE_DIMENSIONS;
      assert.ok(dimensions && Object.keys(dimensions).length > 700, 'full image-header dimension inventory');
      for (const img of b.d.querySelectorAll('img[src]')) {
        const src = img.getAttribute('src'); if (!src) continue;
        const expected = dimensions[src]; if (!expected) continue;
        assert.equal(Number(img.getAttribute('width')), expected[0], page + ': ' + src + ' width');
        assert.equal(Number(img.getAttribute('height')), expected[1], page + ': ' + src + ' height');
        checked++;
      }
    });
  }
  assert.ok(checked > 1000, 'shared templates and product galleries should all be checked');
});

(async () => {
  let failed = 0;
  for (const [name, run] of tests) {
    try { await run(); console.log('PASS', name); }
    catch (error) { failed++; console.error('FAIL', name, error.stack); }
  }
  console.log(`${tests.length - failed}/${tests.length} localization DOM simulations passed (no browser layout/decoding claim)`);
  process.exitCode = failed ? 1 : 0;
})();
