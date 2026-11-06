// C6 only. All UI/API responses come from the real HTTPS API. No mock data or response fulfillments.
// Private stdin carries credentials; stdout is a strict, sanitized checkpoint protocol, never a log.
import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {createInterface} from 'node:readline';

const input = createInterface({input: process.stdin, crlfDelay: Infinity});
const incoming = input[Symbol.asyncIterator]();
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const uuid = value => typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
const check = (condition, code) => { if (!condition) throw new Error(code); };
let context;
let failed = false;
let failurePhase = 'c6_browser_failed';
try {
  const first = await incoming.next();
  check(!first.done, 'c6_config_missing');
  const config = JSON.parse(first.value);
  const origin = new URL(config.base_url);
  check(origin.protocol === 'https:' && origin.hostname === '127.0.0.1' && origin.port
    && origin.href === `${origin.origin}/` && /^[A-Za-z0-9+/]{43}=$/.test(config.spki), 'c6_origin_or_pin_invalid');
  const {chromium} = await import(pathToFileURL(path.join(config.playwright_directory, 'index.mjs')).href);
  const {expect: baseExpect} = await import(pathToFileURL(path.join(config.playwright_directory, 'test.mjs')).href);
  const expect = baseExpect.configure({timeout: 15000});
  const playwright = JSON.parse(await readFile(path.join(config.playwright_directory, 'package.json'), 'utf8')).version;
  const localHashes = {};
  for (const name of Object.keys(config.source_hashes)) localHashes[name] = sha(await readFile(path.join(root, name)));
  check(JSON.stringify(localHashes) === JSON.stringify(config.source_hashes), 'c6_local_source_mismatch');
  context = await chromium.launchPersistentContext(config.profile, {
    channel: 'chrome', headless: true, serviceWorkers: 'block',
    viewport: {width: 1440, height: 1000},
    args: ['--disable-background-networking', `--ignore-certificate-errors-spki-list=${config.spki}`],
  });
  failurePhase = 'c6_browser_process_identity';
  const ownershipSession = await context.browser().newBrowserCDPSession();
  const {processInfo} = await ownershipSession.send('SystemInfo.getProcessInfo');
  const browserProcesses = processInfo.filter(entry => entry.type === 'browser');
  check(browserProcesses.length === 1 && Number.isSafeInteger(browserProcesses[0].id)
    && browserProcesses[0].id > 1, 'c6_browser_process_identity');
  process.stdout.write(`${JSON.stringify({owned_browser_pid: browserProcesses[0].id})}\n`);
  const ownershipAck = await incoming.next();
  check(!ownershipAck.done && JSON.parse(ownershipAck.value).ok === true, 'c6_sql_checkpoint_refused');
  await ownershipSession.detach();
  failurePhase = 'c6_browser_failed';
  const page = context.pages()[0] || await context.newPage();
  const runtimeSession = await context.newCDPSession(page);
  const chromeRuntime = await runtimeSession.send('Browser.getVersion');
  await runtimeSession.detach();
  page.setDefaultTimeout(15000);
  page.setDefaultNavigationTimeout(20000);
  let externalRequests = 0, runtimeErrors = 0, posts = 0;
  let network = [];
  const requestEntries = new WeakMap(), responses = new Set(), secrets = new Set();
  const servedHashes = {};
  const staticPaths = new Map([
    ['/internal/login', 'login.html'], ['/internal/', 'index.html'],
    ...['app.mjs', 'client.mjs', 'login.mjs', 'styles.css', 'supply.mjs'].map(name => [`/internal/${name}`, name]),
  ]);
  const allowed = new Set([...staticPaths.keys(), ...[
    'security/csrf', 'security/login', 'security/me', 'security/logout',
    'directory/items', 'directory/locations', 'commerce/inventory', 'commerce/sales',
    'operations/commerce.sale.record', 'operations/supply.receipt.create', 'supply/purchase-orders',
  ].map(value => `/internal/api/${value}`)]);
  const permittedPath = pathname => allowed.has(pathname)
    || (pathname.startsWith('/internal/api/commerce/sales/') && uuid(pathname.split('/').at(-1)))
    || /^\/internal\/api\/commerce\/sales\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/stock-reviews$/.test(pathname)
    || /^\/internal\/api\/supply\/purchase-orders\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(?:\/receipts)?$/.test(pathname);
  await context.route('**/*', async route => {
    const url = new URL(route.request().url());
    if (url.origin !== origin.origin) { externalRequests++; await route.abort(); return; }
    // Chrome may request the optional favicon. It is not an application/API request.
    if (url.pathname === '/favicon.ico') { await route.abort(); return; }
    if (!permittedPath(url.pathname)) { runtimeErrors++; await route.abort(); return; }
    await route.continue();
  });
  page.on('pageerror', () => { runtimeErrors++; });
  page.on('request', request => {
    const url = new URL(request.url());
    if (url.origin !== origin.origin || !permittedPath(url.pathname)) return;
    const headers = request.headers();
    if (headers['x-csrf-token']) secrets.add(headers['x-csrf-token']);
    const key = headers['idempotency-key'] || null;
    const record = {method: request.method(), path: url.pathname, status: null, key, response_lost: false};
    network.push(record); requestEntries.set(request, record);
    if (record.method === 'POST' && record.path === '/internal/api/commerce/sales') {
      posts++;
      // The UI sends only identity and quantity. No client price or total enters the API.
      try {
        const body = request.postDataJSON();
        if(config.stock_exception && posts===3) {
          check(uuid(key) && Object.keys(body).sort().join(',')==='customerId,lines,locationId' && body.customerId===null && body.locationId===config.location_id && Object.keys(body.lines[0]).sort().join(',')==='exceptionReason,itemId,quantity,size' && body.lines.length===1 && body.lines[0].itemId===config.exception_item_id && body.lines[0].quantity===1 && body.lines[0].size==='S' && body.lines[0].exceptionReason==='SINTETICO physical garment present','c6_stock_sale_invalid');
          return;
        }
        check(uuid(key) && posts <= 2 && Object.keys(body).sort().join(',') === 'customerId,lines,locationId'
          && body.locationId === config.location_id && body.customerId === null && body.lines.length === 2
          && body.lines.every(line => Object.keys(line).sort().join(',') === 'itemId,quantity')
          && body.lines[0].itemId === config.item_id && body.lines[0].quantity === (posts === 1 ? 2 : 1)
          && body.lines[1].itemId === config.second_item_id && body.lines[1].quantity === 1,
        'c6_sale_request_invalid');
      } catch { runtimeErrors++; }
    }
  });
  page.on('response', response => {
    const promise = (async () => {
      const record = requestEntries.get(response.request());
      if (record) record.status = response.status();
      const url = new URL(response.url());
      if (url.origin !== origin.origin || response.status() !== 200) return;
      if (staticPaths.has(url.pathname)) {
        servedHashes[`dev/savia-staff-ui/${staticPaths.get(url.pathname)}`] = sha(await response.body());
      } else if (url.pathname === '/internal/api/security/csrf') {
        const value = await response.json();
        if (typeof value.token === 'string') secrets.add(value.token);
      }
    })().catch(() => { runtimeErrors++; });
    responses.add(promise); void promise.finally(() => responses.delete(promise));
  });
  async function checkpoint(step, notes = {}) {
    await page.waitForLoadState('networkidle');
    await Promise.all([...responses]);
    for (const cookie of await context.cookies()) secrets.add(cookie.value);
    check(externalRequests === 0 && runtimeErrors === 0, 'c6_browser_runtime_guard');
    const payload = {step, notes: {dom: [], ...notes, network, sale_posts: posts,
      external_requests: externalRequests, runtime_errors: runtimeErrors}, secrets: [...secrets]};
    process.stdout.write(`${JSON.stringify(payload)}\n`);
    network = []; secrets.clear();
    const ack = await incoming.next();
    check(!ack.done && JSON.parse(ack.value).ok === true, 'c6_sql_checkpoint_refused');
  }
  const nav = async view => page.locator(`[data-target="${view}"][data-action="nav"]`).click();
  const stored = () => page.evaluate(() => {
    const pendingKeys = Object.keys(sessionStorage).filter(key => key.startsWith('savia.sale.pending.'));
    const receiptKeys = Object.keys(sessionStorage).filter(key => key.startsWith('savia.sale.receipt.'));
    return {pending: pendingKeys.length, key: pendingKeys.length === 1 ? JSON.parse(sessionStorage.getItem(pendingKeys[0])).key : null,
      saleId: receiptKeys.length === 1 ? sessionStorage.getItem(receiptKeys[0]) : null};
  });
  function receipt(value, quantity, saleId = null) {
    check(value && uuid(value.saleId) && (!saleId || value.saleId === saleId) && value.locationId === config.location_id
      && value.state === 'recorded' && value.paymentStatus === 'not_processed' && value.currency === 'USD'
      && value.totalMinor === config.unit_price_minor * quantity + config.second_unit_price_minor && value.lines.length === 2,
      'c6_server_receipt_invalid');
    const first=value.lines.find(line=>line.itemId===config.item_id),second=value.lines.find(line=>line.itemId===config.second_item_id);
    check(first?.sku === config.sku && first.quantity === quantity && first.unitPriceMinor === config.unit_price_minor
      && first.totalMinor === quantity * config.unit_price_minor
      && second?.sku === config.second_sku && second.quantity === 1 && second.unitPriceMinor === config.second_unit_price_minor
      && second.totalMinor === config.second_unit_price_minor, 'c6_server_receipt_invalid');
    return value;
  }
  async function receiptDom(value) {
    await expect(page.locator('#sale-receipt')).toBeVisible();
    await expect(page.locator('#sale-receipt')).toContainText(`Venta: ${value.saleId}`);
    for(const line of value.lines) await expect(page.locator('#sale-receipt')).toContainText(`${line.sku} · ${line.name} · ${line.quantity} ×`);
    await expect(page.locator('#sale-receipt strong')).toHaveText(`Total: ${new Intl.NumberFormat('es-NI', {style: 'currency', currency: 'USD'}).format(value.totalMinor / 100)}`);
    const state = await stored();
    check(state.pending === 0 && state.saleId === value.saleId, 'c6_confirmed_storage_invalid');
    await expect(page.locator('#sale-submit')).toBeEnabled();
  }
  async function stock(total, firstItem, secondItem) {
    await nav('inventario');
    await expect(page.locator('#stock-refresh')).toBeEnabled();
    await page.locator('#stock-refresh').click();
    await expect(page.locator('#stock-status')).toHaveText('3 saldos confirmados por el servidor.');
    const rows = await page.locator('#stock-table tbody tr').evaluateAll(elements => elements.map(row =>
      [...row.cells].map(cell => cell.textContent)));
    check(rows.length === 3 && rows.reduce((sum, row) => sum + Number(row[2]), 0) === total
      && rows.reduce((sum, row) => sum + Number(row[4]), 0) === total
      && rows.every(row => Number(row[3]) === 0)
      && Number(rows.find(row => row[0] === config.sku)?.[2]) === firstItem
      && Number(rows.find(row => row[0] === config.second_sku)?.[2]) === secondItem, 'c6_dom_stock_invalid');
    return {dom: ['inventory', 'stock_current'], stock_rows: rows.length, stock_total: total};
  }
  async function reloadReceipt(value, recover = false) {
    let response;
    const wait = page.waitForResponse(result => new URL(result.url()).pathname === (recover
      ? '/internal/api/operations/commerce.sale.record' : `/internal/api/commerce/sales/${value.saleId}`)
      && result.request().method() === 'GET');
    await page.reload();
    await expect(page.locator('#staff-shell')).toBeVisible();
    await nav('ventas');
    response = await wait;
    check(response.status() === 200, 'c6_receipt_reload_http');
    const body = await response.json();
    if (recover) {
      check(body.status === 'completed' && body.result.success === true && body.result.error === null, 'c6_recovery_not_completed');
      receipt(body.result.value, value.lines.find(line=>line.itemId===config.item_id).quantity, value.saleId);
    } else receipt(body, value.lines.find(line=>line.itemId===config.item_id).quantity, value.saleId);
    await receiptDom(value);
  }

  await page.goto(`${origin.origin}/internal/login`);
  await expect(page.locator('#login-submit')).toBeEnabled();
  await checkpoint('browser.start', {dom: ['login_ready'], source_hashes: localHashes,
    runtime: {chrome: chromeRuntime.product, node: process.version, playwright}});

  await page.locator('#login-name').fill(config.cashier.loginName);
  await page.locator('#login-password').fill(config.cashier.password);
  await page.locator('#login-submit').click();
  await expect(page.locator('#staff-shell')).toBeVisible();
  await expect(page.locator('[data-session-role]')).toHaveText('Cashier');
  await nav('ventas');
  await expect(page.locator('#sale-submit')).toBeEnabled();
  await Promise.all([...responses]);
  for (const [name, hash] of Object.entries(localHashes)) check(servedHashes[name] === hash, 'c6_served_source_mismatch');
  const cookies = await context.cookies();
  check(cookies.some(cookie => cookie.name === '__Host-Savia.Session' && cookie.httpOnly && cookie.secure
    && cookie.sameSite === 'Strict' && cookie.path === '/' && cookie.domain === '127.0.0.1'), 'c6_session_cookie_flags');
  await checkpoint('browser.cashier_login', {dom: ['shell', 'cashier', 'sale_enabled'], source_hashes: servedHashes});

  await checkpoint('browser.inventory', await stock(30, 10, 10));
  await nav('ventas');
  await page.locator('#sale-location').selectOption(config.location_id);
  await page.locator('#sale-item').selectOption(config.item_id);
  await page.locator('#sale-quantity').fill('2');
  await page.locator('#sale-add').click();
  await page.locator('#sale-item-2').selectOption(config.second_item_id);
  const normalResponse = page.waitForResponse(result => new URL(result.url()).pathname === '/internal/api/commerce/sales'
    && result.request().method() === 'POST');
  await page.locator('#sale-submit').click();
  const response = await normalResponse;
  check(response.status() === 200, 'c6_sale_http');
  const normal = receipt(await response.json(), 2);
  const normalKey = response.request().headers()['idempotency-key'];
  await receiptDom(normal);
  await checkpoint('browser.sale_confirmed', {dom: ['receipt', 'sale_enabled'], sale_id: normal.saleId,
    key: normalKey, quantity: 2, total_minor: normal.totalMinor});

  await reloadReceipt(normal);
  await checkpoint('browser.receipt_reload', {dom: ['receipt', 'same_receipt', 'sale_enabled'], sale_id: normal.saleId});
  await checkpoint('browser.stock_after_sale', await stock(27, 8, 9));

  // Pause the REAL Chrome POST at response stage. A received 200 + authoritative receipt means
  // the handler committed before we discard it. There is no replay, synthetic receipt or route.fetch.
  const cdp = await context.newCDPSession(page);
  let lossError, lostReceipt, lostKey, lostRecord;
  let lossResolve;
  const lossDone = new Promise(resolve => { lossResolve = resolve; });
  cdp.on('Fetch.requestPaused', async event => {
    try {
      check(!lostReceipt && event.request.method === 'POST' && event.responseStatusCode === 200,
        'c6_loss_requires_committed_http_200');
      const raw = await cdp.send('Fetch.getResponseBody', {requestId: event.requestId});
      const bytes = raw.base64Encoded ? Buffer.from(raw.body, 'base64').toString('utf8') : raw.body;
      lostReceipt = receipt(JSON.parse(bytes), 1);
      lostKey = Object.entries(event.request.headers).find(([name]) => name.toLowerCase() === 'idempotency-key')?.[1];
      check(uuid(lostKey) && lostKey !== normalKey && lostReceipt.saleId !== normal.saleId, 'c6_loss_identity_invalid');
      lostRecord = network.findLast(entry => entry.method === 'POST' && entry.path === '/internal/api/commerce/sales');
      check(lostRecord?.key === lostKey, 'c6_loss_request_not_observed');
      lostRecord.status = event.responseStatusCode; lostRecord.response_lost = true;
      await cdp.send('Fetch.failRequest', {requestId: event.requestId, errorReason: 'Failed'});
    } catch { lossError = true; }
    finally { lossResolve(); }
  });
  await cdp.send('Fetch.enable', {patterns: [{urlPattern: `${origin.origin}/internal/api/commerce/sales`, requestStage: 'Response'}]});
  await nav('ventas');
  await page.locator('#sale-item').selectOption(config.item_id);
  await page.locator('#sale-quantity').fill('1');
  await page.locator('#sale-add').click();
  await page.locator('#sale-item-2').selectOption(config.second_item_id);
  await page.locator('#sale-submit').click();
  await lossDone;
  check(!lossError && lostReceipt, 'c6_loss_interception_failed');
  await cdp.send('Fetch.disable');
  await cdp.detach();
  await expect(page.locator('#sale-status')).toContainText('La venta sigue sin confirmar.');
  await expect(page.locator('#sale-submit')).toBeDisabled();
  await expect(page.locator('#sale-receipt')).toBeHidden();
  const pending = await stored();
  check(pending.pending === 1 && pending.key === lostKey, 'c6_pending_key_lost');
  await checkpoint('browser.response_loss_committed', {dom: ['pending', 'pending_key_preserved'],
    sale_id: lostReceipt.saleId, key: lostKey, quantity: 1, total_minor: lostReceipt.totalMinor});

  // SQL independently proved two sales, four lines, four debits and stock 25 before recovery.
  // Reload uses the same pending key via GET operations; no POST is allowed to appear again.
  await reloadReceipt(lostReceipt, true);
  check(posts === 2 && network.some(entry => entry.path === '/internal/api/operations/commerce.sale.record'
    && entry.method === 'GET' && entry.key === lostKey && entry.status === 200), 'c6_recovery_key_or_post_count');
  await checkpoint('browser.recover_after_reload', {dom: ['receipt', 'same_receipt', 'sale_enabled'],
    sale_id: lostReceipt.saleId, key: lostKey});
  await reloadReceipt(lostReceipt);
  await checkpoint('browser.repeated_reload', {dom: ['receipt', 'same_receipt', 'sale_enabled'], sale_id: lostReceipt.saleId});
  await checkpoint('browser.stock_after_recovery', await stock(25, 7, 8));

  // Observe the real 204 separately from navigation and login preparation.
  failurePhase = 'c6_logout_click';
  const logoutResponse = page.waitForResponse(result => new URL(result.url()).pathname === '/internal/api/security/logout'
    && result.request().method() === 'POST', {timeout: 15000});
  logoutResponse.catch(() => {}); // Keep the observer handled if the click fails first.
  await page.locator('[data-action="logout"]').click({noWaitAfter: true});
  failurePhase = 'c6_logout_response';
  check((await logoutResponse).status() === 204, 'c6_logout_http');
  failurePhase = 'c6_logout_navigation';
  await page.waitForURL(url => url.href === `${origin.origin}/internal/login`, {waitUntil: 'commit', timeout: 20000});
  failurePhase = 'c6_logout_form';
  await expect(page.locator('#login-submit')).toBeEnabled();
  failurePhase = 'c6_logout_me';
  // Consume the 401 body before the networkidle checkpoint.
  const meStatus = await page.evaluate(async () => {
    const response = await fetch('/internal/api/security/me', {credentials: 'same-origin'});
    await response.arrayBuffer();
    return response.status;
  });
  check(meStatus === 401 && posts === 2, 'c6_logout_or_post_count');
  await checkpoint('browser.logout', {dom: ['logged_out']});

  if (config.supply) {
    const fixture = config.supply;
    const receiptPath = `/internal/api/supply/purchase-orders/${fixture.id}/receipts`;
    const lineId = fixture.lines[0].id;
    let receiptPosts = 0, delivery, deliveryKey;
    const readPending = () => page.evaluate(() => JSON.parse(sessionStorage.getItem('savia.supply.pending.v1')));
    const identity = value => {
      check(value && uuid(value.id) && value.purchaseOrderId === fixture.id
        && value.locationId === config.location_id && value.receivedBy === fixture.actor
        && value.currency === 'USD' && value.lines.length === 1
        && value.lines[0].purchaseOrderLineId === lineId && value.lines[0].itemId === config.item_id
        && value.lines[0].unitCostMinor === 700, 'c6_supply_identity_invalid');
      return value;
    };
    page.on('request', request => {
      if (request.method() !== 'POST' || new URL(request.url()).pathname !== receiptPath) return;
      receiptPosts++;
      try {
        const body = request.postDataJSON();
        check(receiptPosts <= 2 && Object.keys(body).sort().join() === 'lines,receiptId'
          && uuid(body.receiptId) && body.lines.length === 1 && body.lines[0].purchaseOrderLineId === lineId
          && body.lines[0].quantity === (receiptPosts === 1 ? 2 : 3), 'c6_supply_request_invalid');
      } catch { runtimeErrors++; }
    });
    const supplyCheckpoint = async step => checkpoint(step, {dom: step.endsWith('logout') ? ['logged_out'] : ['shell'],
      receipt_posts: receiptPosts, order_id: fixture.id, actor_id: fixture.actor, location_id: config.location_id,
      ...(delivery ? {receipt_id: delivery.id, key: deliveryKey} : {})});
    await page.locator('#login-name').fill(config.inventory.loginName);
    await page.locator('#login-password').fill(config.inventory.password);
    await page.locator('#login-submit').click();
    await expect(page.locator('[data-session-role]')).toHaveText('Inventory');
    await nav('abastecimiento');
    await page.locator(`[data-order-id="${fixture.id}"]`).click();
    await expect(page.locator('#supply-detail')).toContainText('open');
    await supplyCheckpoint('browser.supply_login');
    await page.locator(`[data-line-id="${lineId}"]`).fill('2');
    const partialResponse = page.waitForResponse(r => new URL(r.url()).pathname === receiptPath && r.request().method() === 'POST');
    await page.locator('#supply-submit').click();
    const partial = await partialResponse;
    check(partial.status() === 200, 'c6_supply_partial_http');
    delivery = identity(await partial.json()); deliveryKey = partial.request().headers()['idempotency-key'];
    check(uuid(deliveryKey) && delivery.totalMinor === 1400 && delivery.orderStatusAfter === 'partially_received'
      && delivery.lines[0].quantity === 2, 'c6_supply_partial_invalid');
    await expect(page.locator('#supply-result')).toContainText(delivery.id);
    await expect(page.locator('#supply-detail')).toContainText('partially_received');
    await expect(page.locator(`[data-line-id="${lineId}"]`)).toHaveAttribute('max', '3');
    check(await readPending() === null, 'c6_supply_pending_not_cleared');
    await supplyCheckpoint('browser.supply_partial');

    const partialId = delivery.id, partialKey = deliveryKey;
    const loss = await context.newCDPSession(page);
    let lossFailure = false, resolveLoss;
    const lossDone = new Promise(resolve => { resolveLoss = resolve; });
    loss.on('Fetch.requestPaused', async event => {
      try {
        check(event.request.method === 'POST' && event.responseStatusCode === 200, 'c6_supply_loss_requires_commit');
        const raw = await loss.send('Fetch.getResponseBody', {requestId: event.requestId});
        delivery = identity(JSON.parse(raw.base64Encoded ? Buffer.from(raw.body, 'base64').toString('utf8') : raw.body));
        deliveryKey = Object.entries(event.request.headers).find(([k]) => k.toLowerCase() === 'idempotency-key')?.[1];
        check(uuid(deliveryKey) && deliveryKey !== partialKey && delivery.id !== partialId
          && delivery.totalMinor === 2100 && delivery.orderStatusAfter === 'received' && delivery.lines[0].quantity === 3,
        'c6_supply_complete_invalid');
        const record = network.findLast(r => r.method === 'POST' && r.path === receiptPath);
        check(record?.key === deliveryKey, 'c6_supply_loss_request_missing');
        record.status = 200; record.response_lost = true;
        await loss.send('Fetch.failRequest', {requestId: event.requestId, errorReason: 'Failed'});
      } catch { lossFailure = true; }
      finally { resolveLoss(); }
    });
    await loss.send('Fetch.enable', {patterns: [{urlPattern: `${origin.origin}${receiptPath}`, requestStage: 'Response'}]});
    await page.locator(`[data-line-id="${lineId}"]`).fill('3');
    await page.locator('#supply-submit').click();
    await lossDone;
    check(!lossFailure, 'c6_supply_loss_failed');
    await loss.send('Fetch.disable'); await loss.detach();
    await expect(page.locator('#supply-recover')).toBeEnabled();
    await expect(page.locator('#supply-submit')).toBeDisabled();
    const pending = await readPending();
    check(pending?.key === deliveryKey && pending.body.receiptId === delivery.id && pending.actorId === fixture.actor
      && pending.order.id === fixture.id && pending.body.lines[0].quantity === 3, 'c6_supply_pending_identity_invalid');
    await supplyCheckpoint('browser.supply_loss');

    await page.reload();
    await nav('abastecimiento');
    await expect(page.locator('#supply-recover')).toBeEnabled();
    const restored = await readPending();
    check(JSON.stringify(restored) === JSON.stringify(pending), 'c6_supply_pending_changed');
    await page.locator('#supply-recover').click();
    await expect(page.locator('#supply-result')).toContainText(delivery.id);
    await expect(page.locator('#supply-detail')).toContainText('received');
    await expect(page.locator(`[data-line-id="${lineId}"]`)).toHaveAttribute('max', '0');
    check(await readPending() === null && receiptPosts === 2, 'c6_supply_recovery_invalid');
    await supplyCheckpoint('browser.supply_recovered');
    await page.reload(); await nav('abastecimiento');
    await page.locator(`[data-order-id="${fixture.id}"]`).click();
    await expect(page.locator('#supply-detail')).toContainText('received');
    await expect(page.locator(`[data-line-id="${lineId}"]`)).toHaveAttribute('max', '0');
    await expect(page.locator('#supply-receipts')).toContainText(delivery.id);
    await expect(page.locator('#supply-receipts')).toContainText(partialId);
    await expect(page.locator('#supply-submit')).toBeDisabled();
    check(await readPending() === null && receiptPosts === 2, 'c6_supply_reload_invalid');
    await supplyCheckpoint('browser.supply_reload');
    const finalLogout = page.waitForResponse(r => new URL(r.url()).pathname === '/internal/api/security/logout');
    await page.locator('[data-action="logout"]').click({noWaitAfter: true});
    check((await finalLogout).status() === 204, 'c6_supply_logout_invalid');
    await page.waitForURL(`${origin.origin}/internal/login`);
    await expect(page.locator('#login-submit')).toBeEnabled();
    await supplyCheckpoint('browser.supply_logout');
  }
  if(config.stock_exception) {
    let exceptional, saleKey, reviewKey, review;
    const login=async user=>{await page.locator('#login-name').fill(user.loginName);await page.locator('#login-password').fill(user.password);await page.locator('#login-submit').click();await nav('ventas');};
    const logout=async()=>{await page.locator('[data-action="logout"]').click({noWaitAfter:true});await page.waitForURL(`${origin.origin}/internal/login`);};
    const cp=step=>checkpoint(step,{dom:step.endsWith('logout')?['logged_out']:['shell'],sale_id:exceptional.saleId,key:saleKey,
      ...(review?{review_id:review.id,review_key:reviewKey}: {})});
    await login(config.cashier);
    await page.locator('#sale-item').selectOption(config.exception_item_id);
    await page.locator('#sale-quantity').fill('1');
    await page.locator('[data-exception]').check();
    await page.locator('[data-exception-reason]').fill('SINTETICO physical garment present');
    await page.locator('[data-exception-size]').fill('S');
    const sold=page.waitForResponse(r=>new URL(r.url()).pathname==='/internal/api/commerce/sales'&&r.request().method()==='POST');
    await page.locator('#sale-submit').click();const response=await sold;
    check(response.status()===200,'c6_stock_sale_invalid');exceptional=await response.json();saleKey=response.request().headers()['idempotency-key'];
    check(exceptional.lines.length===1 && exceptional.lines[0].exceptionReason==='SINTETICO physical garment present' && exceptional.totalMinor===1250,'c6_stock_sale_invalid');
    await expect(page.locator('#sale-receipt')).toContainText(exceptional.saleId);await cp('browser.stock_sale');
    await page.reload();await nav('ventas');await expect(page.locator('#sale-receipt')).toContainText(exceptional.saleId);await cp('browser.stock_reload');
    await logout();await login(config.manager);
    await page.locator('#stock-review-load input').fill(exceptional.saleId);await page.locator('#stock-review-load button').click();
    await expect(page.locator('#stock-review-form select')).toHaveValue(exceptional.lines[0].saleLineId);
    await page.locator('[name="evidence"]').fill('SINTETICO sale and physical count examined');
    await page.locator('[name="outcome"]').fill('SINTETICO cause unproven; follow up');
    await page.locator('[name="responsibleActorId"]').fill(config.manager.id);
    await page.locator('[name="nextReviewAt"]').fill('2099-11-07T17:00');
    const reviewed=page.waitForResponse(r=>new URL(r.url()).pathname.endsWith('/stock-reviews')&&r.request().method()==='POST');
    await page.locator('#stock-review-form button').click();const rr=await reviewed;check(rr.status()===200,'c6_stock_review_invalid');
    review=await rr.json();reviewKey=rr.request().headers()['idempotency-key'];
    check(review.reviewerId===config.manager.id && review.reviewerId!==exceptional.actorId && review.causeState==='open','c6_stock_review_invalid');
    await expect(page.locator('#stock-review-status')).toContainText('confirmada');await cp('browser.stock_review');
    await page.reload();await nav('ventas');await page.locator('#stock-review-load input').fill(exceptional.saleId);await page.locator('#stock-review-load button').click();
    await expect(page.locator('#stock-review-evidence')).toContainText(review.id);await cp('browser.stock_review_reload');
    await logout();await cp('browser.stock_logout');
  }


} catch (error) {
  failed = true;
  // Never print Playwright, CDP, network or assertion exception text (it may contain secrets).
  const safe = /^c6_[a-z_]{1,80}$/.test(error?.message) ? error.message : failurePhase;
  process.stdout.write(`${JSON.stringify({error: safe})}\n`);
} finally {
  try { await context?.close(); } catch { failed = true; }
  input.close();
  process.stdin.destroy();
}
process.exitCode = failed ? 1 : 0;
