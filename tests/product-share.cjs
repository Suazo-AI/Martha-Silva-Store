'use strict';
// Focused source-level DOM simulation. Native OS share sheets, layout and browser
// permission UI are not exercised; the parent release check owns built artifacts.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {JSDOM, VirtualConsole} = require(process.env.MARTHA_JSDOM_PATH || './frontend-deps/node_modules/jsdom');
const root = path.resolve(__dirname, '..');
const staticRoot = path.join(root, 'build-inputs/static');
const tick = () => new Promise(resolve => setTimeout(resolve, 10));
const tests = [];
const test = (name, run) => tests.push([name, run]);
const label = element => element.textContent.replace(/\s+/g, ' ').trim();

async function boot({page = 'producto-dorado.html', query = '', language, setup, blockedStorage = false} = {}) {
  const errors = [], vc = new VirtualConsole();
  vc.on('jsdomError', error => errors.push(error.message));
  const dom = new JSDOM(fs.readFileSync(path.join(staticRoot, page), 'utf8'), {
    url: 'https://demo.test/' + page + query,
    runScripts: 'outside-only', pretendToBeVisual: true, virtualConsole: vc,
  });
  const w = dom.window;
  try {
    w.matchMedia = () => ({matches:false, addEventListener(){}});
    w.IntersectionObserver = class { observe(){} disconnect(){} };
    w.CSS = {escape:value => value};
    w.HTMLElement.prototype.scrollIntoView = function(){};
    w.HTMLElement.prototype.scrollTo = function(){};
    w.scrollTo = () => {};
    w.HTMLMediaElement.prototype.pause = function(){};
    w.HTMLDialogElement.prototype.showModal = function(){ this.open = true; this.querySelector('button,input,select')?.focus(); };
    w.HTMLDialogElement.prototype.close = function(){ this.open = false; this.dispatchEvent(new w.Event('close')); };
    if (language) w.localStorage.setItem('martha-language-v1', language);
    if (blockedStorage) Object.defineProperty(w, 'localStorage', {get(){throw new w.DOMException('blocked', 'SecurityError');}});
    for (const file of ['catalog.js', 'locale-en.js', 'i18n.js']) w.eval(fs.readFileSync(path.join(staticRoot, file), 'utf8'));
    for (const file of ['demo-api.js', 'integration-adapters.js']) w.eval(fs.readFileSync(path.join(root, 'src', file), 'utf8'));
    if (setup) setup(w);
    w.eval(fs.readFileSync(path.join(root, 'src/app.js'), 'utf8'));
    await tick(); await tick();
    const d = w.document;
    return {w, d, errors, button:() => d.querySelector('[data-product-share]'), status:() => d.querySelector('[data-product-share-status]'), close:() => w.close()};
  } catch(error) { w.close(); throw error; }
}
async function withPage(options, run) {
  const b = await boot(options);
  try { await run(b); assert.deepEqual(b.errors, []); } finally { b.close(); }
}
function clipboard(w, writeText) { Object.defineProperty(w.navigator, 'clipboard', {value:{writeText}, configurable:true}); }

test('all 40 catalog PDPs mount exactly one named share button and share their own canonical URL', async () => {
  const pages = fs.readdirSync(staticRoot).filter(name => /^producto-.*\.html$/.test(name));
  assert.equal(pages.length, 40);
  for (const page of pages) {
    let payload;
    await withPage({page, query:'?utm_source=test&id=private-order&token=secret#gallery', setup:w => {w.navigator.share = data => {payload = data; return Promise.resolve();};}}, async b => {
      const button = b.button();
      assert.equal(b.d.querySelectorAll('[data-product-share]').length, 1, page);
      assert.equal(button.tagName, 'BUTTON'); assert.equal(button.type, 'button');
      assert.equal(label(button), 'Compartir producto'); assert.equal(button.closest('[hidden]'), null);
      assert.ok(b.d.querySelector('.product-information').contains(button));
      button.click();
      assert.equal(payload.url, `https://demo.test/${page}?lang=es`, page);
      await tick(); assert.equal(button.disabled, false);
      assert.equal(b.status().getAttribute('role'), 'status');
    });
  }
});

test('native share is called during the click, repeated clicks stay locked, and success does not copy', async () => {
  let release, shares = 0, copies = 0, payload;
  await withPage({setup:w => {
    w.navigator.share = data => {shares++; payload = data; return new Promise(resolve => {release = resolve;});};
    clipboard(w, async () => {copies++;});
  }}, async b => {
    b.button().click();
    assert.equal(shares, 1, 'native call must precede the first await/yield');
    assert.equal(payload.title, 'Vestido dorado con drapeado · Martha Silva');
    assert.equal(b.button().disabled, true); b.button().click(); assert.equal(shares, 1);
    release(); await tick();
    assert.equal(b.button().disabled, false); assert.equal(copies, 0); assert.equal(label(b.status()), '');
  });
});

test('native cancellation is quiet and never copies', async () => {
  let copies = 0;
  await withPage({setup:w => {
    w.navigator.share = () => Promise.reject(new w.DOMException('cancelled', 'AbortError'));
    clipboard(w, async () => {copies++;});
  }}, async b => {
    b.button().click(); await tick();
    assert.equal(copies, 0); assert.equal(label(b.status()), ''); assert.equal(b.button().disabled, false);
    assert.equal(b.d.querySelector('[data-product-share-manual]').hidden, true);
  });
});

test('clipboard fallback only reports success after writeText resolves', async () => {
  let release, copied;
  await withPage({query:'?lang=es&utm_campaign=sale&id=order#private', setup:w => {
    clipboard(w, url => {copied = url; return new Promise(resolve => {release = resolve;});});
  }}, async b => {
    b.button().click();
    assert.equal(copied, 'https://demo.test/producto-dorado.html?lang=es');
    assert.equal(label(b.status()), ''); assert.equal(b.button().disabled, true);
    release(); await tick();
    assert.equal(label(b.status()), 'Enlace copiado. Ya podés compartirlo.');
    assert.equal(b.button().disabled, false);
  });
});

test('non-cancellation native errors fall back to copying', async () => {
  for (const synchronous of [false, true]) {
    let copied;
    await withPage({setup:w => {
      w.navigator.share = () => {const error = new w.DOMException('denied', 'NotAllowedError'); if(synchronous) throw error; return Promise.reject(error);};
      clipboard(w, async url => {copied = url;});
    }}, async b => {
      b.button().click(); await tick();
      assert.equal(copied, 'https://demo.test/producto-dorado.html?lang=es');
      assert.match(label(b.status()), /^Enlace copiado/);
    });
  }
});

test('denied or missing clipboard exposes an honestly labelled, selected manual link', async () => {
  for (const unavailable of [false, true]) {
    await withPage({setup:w => {if (!unavailable) clipboard(w, () => Promise.reject(new w.DOMException('denied', 'NotAllowedError')));}}, async b => {
      b.button().click(); await tick();
      assert.equal(label(b.status()), 'No pudimos copiar el enlace. Copialo manualmente.');
      const input = b.d.querySelector('[data-product-share-url]');
      assert.equal(input.value, 'https://demo.test/producto-dorado.html?lang=es');
      assert.equal(input.readOnly, true); assert.equal(input.closest('label').hidden, false);
      assert.equal(label(input.closest('label').querySelector('span')), 'Enlace del producto');
      assert.equal(b.d.activeElement, input); assert.equal(input.selectionStart, 0); assert.equal(input.selectionEnd, input.value.length);
      assert.equal(b.button().disabled, false);
    });
  }
});

test('English preference controls native title and clean URL; explicit Spanish overrides it', async () => {
  for (const query of ['?utm_source=mail', '?lang=es&id=private']) {
    let payload;
    await withPage({language:'en', query, setup:w => {w.navigator.share = data => {payload = data; return Promise.resolve();};}}, async b => {
      b.button().click(); await tick();
      const english = !query.includes('lang=es');
      assert.equal(label(b.button()), english ? 'Share product' : 'Compartir producto');
      assert.equal(payload.url, 'https://demo.test/producto-dorado.html?lang=' + (english ? 'en' : 'es'));
      assert.equal(payload.title, (english ? 'Draped gold dress' : 'Vestido dorado con drapeado') + ' · Martha Silva');
    });
  }
});

test('English fallback copy success and manual failure are localized, including language toggles', async () => {
  for (const denied of [false, true]) {
    await withPage({query:'?lang=en', setup:w => {clipboard(w, async () => {if(denied) throw new Error('denied');});}}, async b => {
      b.button().click(); await tick();
      assert.equal(label(b.status()), denied ? 'We could not copy the link. Copy it manually.' : 'Link copied. You can now share it.');
      if (denied) {
        const input = b.d.querySelector('[data-product-share-url]');
        assert.equal(label(input.closest('label').querySelector('span')), 'Product link');
        assert.equal(b.d.getElementById(input.getAttribute('aria-describedby')).textContent, 'Select and copy this link to share it.');
        b.w.MarthaI18n.setLanguage('es'); await tick();
        assert.equal(label(b.button()), 'Compartir producto'); assert.equal(input.value, 'https://demo.test/producto-dorado.html?lang=es');
        b.w.MarthaI18n.setLanguage('en'); await tick();
        assert.equal(label(b.button()), 'Share product'); assert.equal(input.value, 'https://demo.test/producto-dorado.html?lang=en');
      }
    });
  }
});

test('explicit English survives unavailable storage and ignores canonical-tag injection', async () => {
  let copied;
  await withPage({blockedStorage:true, query:'?lang=en&redirect=https://evil.test&id=order#token', setup:w => {
    const tag = w.document.createElement('link'); tag.rel = 'canonical'; tag.href = 'https://evil.test/product'; w.document.head.append(tag);
    clipboard(w, async url => {copied = url;});
  }}, async b => {
    b.button().click(); await tick();
    assert.equal(copied, 'https://demo.test/producto-dorado.html?lang=en');
    assert.equal(label(b.status()), 'Link copied. You can now share it.');
  });
});

test('remounts do not duplicate sharing, and favorites, bag and zoom still work', async () => {
  await withPage({setup:w => clipboard(w, async () => {})}, async b => {
    b.w.dispatchEvent(new b.w.PageTransitionEvent('pageshow', {persisted:true})); await tick();
    assert.equal(b.d.querySelectorAll('[data-product-share]').length, 1);
    b.button().click(); await tick();
    const favorite = b.d.querySelector('.product-save'); favorite.click();
    assert.equal(favorite.getAttribute('aria-pressed'), 'true');
    b.d.querySelector('[name=variant]:not(:disabled)').checked = true;
    b.d.querySelector('[data-add]').click(); await tick();
    assert.equal(b.d.querySelector('[data-bag-count]').textContent, '1');
    b.d.querySelector('#mini-bag [data-close-dialog]').click();
    const zoom = b.d.querySelector('[data-zoom]'); zoom.focus(); zoom.click();
    assert.equal(b.d.querySelector('#image-dialog').open, true);
    b.d.querySelector('#image-dialog [data-close-dialog]').click(); assert.equal(b.d.activeElement, zoom);
  });
});

test('sharing remains independent of unavailable commerce; other pages and unknown products have no button', async () => {
  await withPage({setup:w => {delete w.MarthaIntegrations; clipboard(w, async () => {});}}, async b => {
    assert.equal(b.d.querySelector('[data-add]').disabled, true);
    b.button().click(); await tick(); assert.match(label(b.status()), /^Enlace copiado/);
  });
  await withPage({page:'catalogo.html'}, async b => {assert.equal(b.button(), null);});
  await withPage({setup:w => {w.document.querySelector('main').dataset.productId = '../../evil';}}, async b => {assert.equal(b.button(), null);});
});

(async () => {
  let failures = 0;
  for (const [name, run] of tests) {
    try { await run(); console.log('PASS ' + name); }
    catch (error) { failures++; console.error('FAIL ' + name + '\n' + error.stack); }
  }
  console.log(`${tests.length - failures}/${tests.length} product-share DOM checks passed`);
  process.exitCode = failures ? 1 : 0;
})();
