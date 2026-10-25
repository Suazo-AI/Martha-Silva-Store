/* Storefront presentation only: catalog identifiers and entered customer data stay unchanged. */
(() => {
  'use strict';
  const messages = window.MARTHA_EN || {};
  const key = 'martha-language-v1';
  const records = new WeakMap();
  const attributes = ['alt', 'aria-label', 'placeholder', 'title', 'content'];
  const skip = 'script,style,svg,input,textarea,[translate="no"],[data-no-translate]';
  const params = new URLSearchParams(location.search);
  let saved;
  try { saved = localStorage.getItem(key); } catch {}
  let language = ['es', 'en'].includes(params.get('lang')) ? params.get('lang') : saved === 'en' ? 'en' : 'es';
  if (['es', 'en'].includes(params.get('lang'))) {
    try { localStorage.setItem(key, language); } catch {}
  }
  const productNames = (window.DEMO_CATALOG?.products || []).map(product => [product.name, window.MARTHA_PRODUCT_EN?.[product.id]?.name || product.name]);
  const normalized = value => String(value ?? '').replace(/\s+/g, ' ').trim();
  function english(value) {
    const source = String(value ?? '');
    const text = normalized(source);
    if (!text) return source;
    let result = Object.prototype.hasOwnProperty.call(messages, text) ? messages[text] : undefined;
    if (result === undefined) {
      result = text;
      const prefixes = [
        [/^Guardar (.+) en favoritos$/, name => `Save ${english(name)} to favorites`],
        [/^Guardar en favoritos (.+), talla (.+)$/, (name, size) => `Save ${english(name)}, size ${size}, to favorites`],
        [/^Guardar en favoritos:? (.+)$/, name => `Save to favorites: ${english(name)}`],
        [/^Quitar de favoritos:? (.+)$/, name => `Remove from favorites: ${english(name)}`],
        [/^Ver (.+)$/, name => `View ${english(name)}`],
        [/^Video de (.+)$/, name => `Video of ${english(name)}`],
        [/^Ampliar (.+)$/, name => `Enlarge ${english(name)}`],
        [/^Color: (.+)$/, name => `Color: ${english(name)}`],
        [/^Referencia: (.+)$/, name => `Reference: ${name}`],
        [/^Cantidad de (.+), talla (.+)$/, (name, size) => `Quantity for ${english(name)}, size ${size}`],
        [/^Retirar (.+), talla (.+)$/, (name, size) => `Remove ${english(name)}, size ${size}`],
        [/^Nuevo stock de (.+)$/, name => `New stock for ${english(name)}`],
        [/^Nuevo stock (.+)$/, name => `New stock for ${english(name)}`],
        [/^Motivo del ajuste (.+)$/, name => `Reason for adjusting ${english(name)}`],
        [/^(\d+) (prenda|prendas)( en favoritos)?$/, (n, noun, favorites) => `${n} ${n === '1' ? 'item' : 'items'}${favorites ? ' in favorites' : ''}`],
        [/^La cantidad debe ser un número entero entre (\d+) y (\d+)\.$/, (min, max) => `Quantity must be a whole number between ${min} and ${max}.`],
        [/^Pedidos \((\d+)\)$/, n => `Orders (${n})`],
        [/^PEDIDO (.+)$/, code => `ORDER ${code}`],
        [/^Devolución (.+)$/, code => `Return ${code}`],
        [/^Seguimiento: (.+)$/, code => `Tracking: ${code}`],
        [/^Reembolsado en prueba: (.+)$/, amount => `Test refund: ${amount}`]
        ,[/^(\d+)\. (Contacto|Entrega|Revisión|Pago)$/, (n, label) => `${n}. ${english(label)}`]
        ,[/^Desde (.+)$/, amount => `From ${amount}`]
        ,[/^Seguimiento:$/, () => 'Tracking:']
        ,[/^fotografía (\d+)$/, n => `photo ${n}`]
        ,[/^(Total sin entrega|Total|Entrega estimada|Entrega|Subtotal|Impuestos de prueba|Descuento) ((?:USD|US\$|\$).+)$/, (label, amount) => `${english(label)} ${amount}`]
      ];
      let matched = false;
      for (const [pattern, render] of prefixes) {
        const match = text.match(pattern);
        if (match) { result = render(...match.slice(1)); matched = true; break; }
      }
      if (!matched) {
        // A dynamic label may start with a separator after a protected data span.
        // Preserve separator tokens while translating every surrounding label.
        const parts = text.split(/(\s*·\s*|\s+-\s+|\s+\/\s+)/);
        if (parts.length > 1) result = parts.map((part, index) => index % 2 ? part : english(part)).join('');
        else {
          result = text.replace(/Talla ([SML]|\d+)/g, 'Size $1').replace(/Cantidad:? (\d+)/g, 'Quantity: $1');
          for (const [spanish, translated] of productNames) result = result.split(spanish).join(translated);
        }
      }
    }
    return source.slice(0, source.indexOf(source.trimStart())) + result + source.slice(source.trimEnd().length);
  }
  function transform(node, field, current, write) {
    let fields = records.get(node);
    if (!fields) { fields = new Map(); records.set(node, fields); }
    let record = fields.get(field);
    if (!record || current !== record.written) record = { original: current, written: current };
    const next = language === 'en' ? english(record.original) : record.original;
    record.written = next;
    fields.set(field, record);
    if (current !== next) write(next);
  }
  function apply(root = document) {
    if (root.nodeType === Node.TEXT_NODE) {
      if (!root.parentElement?.closest(skip)) transform(root, 'text', root.nodeValue, value => { root.nodeValue = value; });
      return;
    }
    if (root.nodeType === Node.ELEMENT_NODE && root.closest('script,style,svg,[translate="no"],[data-no-translate]')) return;
    const elements = root.nodeType === Node.ELEMENT_NODE ? [root, ...root.querySelectorAll('*')] : [...root.querySelectorAll('*')];
    for (const element of elements) {
      if (element.closest('script,style,svg,[translate="no"],[data-no-translate]')) continue;
      // An option without a value attribute inherits its label as the submitted value.
      // Preserve the original catalog/filter key before translating that label.
      if (element.matches('option') && !element.hasAttribute('value')) element.setAttribute('value', element.value);
      for (const attribute of attributes) {
        if (element.hasAttribute(attribute)) transform(element, attribute, element.getAttribute(attribute), value => element.setAttribute(attribute, value));
      }
      if (element.matches('input,textarea')) continue;
      for (const node of element.childNodes) if (node.nodeType === Node.TEXT_NODE) apply(node);
    }
  }
  function refreshControls() {
    document.documentElement.lang = language === 'en' ? 'en' : 'es-NI';
    document.querySelectorAll('[data-language]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.language === language)));
  }
  function setLanguage(next) {
    if (!['es', 'en'].includes(next)) return;
    language = next;
    try { localStorage.setItem(key, language); } catch {}
    const url = new URL(location.href);
    if (language === 'en') url.searchParams.set('lang', 'en'); else url.searchParams.delete('lang');
    history.replaceState(history.state, '', url.pathname + url.search + url.hash);
    refreshControls();
    apply();
    window.dispatchEvent(new CustomEvent('martha:languagechange', { detail: { language } }));
  }
  function syncHistoryLanguage() {
    const choice = new URLSearchParams(location.search).get('lang');
    // An explicit language in a restored URL takes precedence over the latest preference.
    if (!['es', 'en'].includes(choice) || choice === language) return;
    language = choice;
    try { localStorage.setItem(key, language); } catch {}
    refreshControls();
    apply();
    window.dispatchEvent(new CustomEvent('martha:languagechange', { detail: { language } }));
  }
  window.addEventListener('popstate', syncHistoryLanguage);
  window.addEventListener('pageshow', syncHistoryLanguage);
  window.MarthaI18n = {
    get language() { return language; },
    translate: value => language === 'en' ? english(value) : String(value ?? ''),
    english, apply, setLanguage,
    originalText: node => records.get(node)?.get('text')?.original ?? node.textContent,
    originalAttribute: (element, attribute) => records.get(element)?.get(attribute)?.original ?? element?.getAttribute(attribute)
  };
  document.addEventListener('click', event => {
    const button = event.target.closest('[data-language]');
    if (button) { event.preventDefault(); setLanguage(button.dataset.language); }
  });
  // Keep a shareable language choice on navigation, including restricted-storage browsers.
  document.addEventListener('click', event => {
    const link = event.target.closest('a[href]');
    if (!link || event.defaultPrevented || event.button !== 0 || link.hasAttribute('download') || link.target === '_blank') return;
    const url = new URL(link.href, location.href);
    if (url.origin !== location.origin || !/^\/(?:[a-z0-9-]+\.html)?$/.test(url.pathname) || link.getAttribute('href').startsWith('#')) return;
    if (language === 'en') url.searchParams.set('lang', 'en'); else url.searchParams.delete('lang');
    if (link.href !== url.href) link.href = url.href;
  }, true);
  document.addEventListener('submit', event => {
    const form = event.target;
    if (!form.matches('#search-dialog form')) return;
    let choice = form.querySelector('input[name="lang"]');
    if (language === 'en') {
      if (!choice) { choice = document.createElement('input'); choice.type = 'hidden'; choice.name = 'lang'; form.append(choice); }
      choice.value = 'en';
    } else choice?.remove();
  }, true);
  new MutationObserver(mutations => {
    const roots = new Set();
    for (const mutation of mutations) {
      if (mutation.type === 'characterData' || mutation.type === 'attributes') roots.add(mutation.target);
      else mutation.addedNodes.forEach(node => roots.add(node));
    }
    roots.forEach(root => { if (root.isConnected) apply(root); });
    refreshControls();
  }).observe(document.documentElement, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: attributes });
  refreshControls();
  apply();
})();
