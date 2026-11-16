// Mounted real sale module, executed by the isolated fictional browser fixture.
export async function runSaleUX() {
  const results = [];
  const pause = () => new Promise(r => setTimeout(r, 25));
  const $ = s => document.querySelector(s);
  const check = (condition, message) => {
    if (!condition) throw Error(message);
    results.push(message);
  };
  const key = 'savia.sale.pending.v1';
  const original = { ...ctx.me };
  const reset = async (mode = 'ok') => {
    handle?.unmount();
    localStorage.removeItem(key);
    Object.assign(ctx.me, original);
    ctx.isApprover = true;
    fixture.mode = mode;
    fixture.posts = [];
    fixture.calls = [];
    fixture.committed = null;
    await remount();
    await pause();
  };
  const input = (selector, value, type = 'input') => {
    $(selector).value = value;
    $(selector).dispatchEvent(new Event(type, { bubbles: true }));
  };
  const prepare = async () => {
    $('.product').click();
    await pause();
    input('#received', '100');
  };
  const post = async mode => {
    await reset();
    await prepare();
    fixture.mode = mode;
    $('#pay').click();
    await pause();
  };
  await reset();
  check($('#sale-seller').value === fixture.id(1), 'canonical actor default, not first row');
  ctx.me.staffId = fixture.id(10);
  await remount();
  await pause();
  check($('#sale-seller').value === '', 'unmatched actor requires selection');
  $('.product').click();
  await pause();
  check(!$('.tline') && $('#pay').disabled, 'no add or charge without seller');
  for (const mode of ['sellerfail', 'sellersEmpty']) {
    await reset(mode);
    $('.product').click();
    await pause();
    check(!$('.tline') && $('#pay').disabled, `${mode} blocks selling`);
  }
  await reset();
  await prepare();
  check(!$('#sale-advanced').open, 'advanced options initially closed');
  $('#sale-advanced').open = true;
  input('#ticket-discount', '10', 'change');
  $('#sale-advanced').open = false;
  check($('#total').textContent.includes('90.00'), 'disclosure retains discount total');
  $('#pay').click();
  await pause();
  check($('#sale-advanced').open && document.activeElement.id === 'discount-reason', 'missing reason reveals and focuses field');
  input('#discount-reason', 'Demo');
  input('#ticket-discount', '100', 'change');
  $('#pay').click();
  await pause();
  check(
    fixture.posts.length === 1 && fixture.posts[0].lines[0].discountMinor === 10000 && fixture.posts[0].tenders.length === 0,
    '100% discount keeps zero total request',
  );
  await reset();
  await prepare();
  fixture.mode = 'hold';
  $('#pay').click();
  await pause();
  await handle.handleScan('DEMO-1');
  check(
    $('#pay').disabled && $('#received').disabled && $('#park-ticket').disabled && fixture.posts.length === 1,
    'sending locks edits, park and second POST',
  );
  fixture.release();
  await pause();
  check($('#receipt') && !$('#receipt').hidden, 'held first attempt confirms');
  for (const mode of ['loss', 'preloss', 'bad', 'empty', '500']) {
    await post(mode);
    check(!!$('#consult-receipt') && fixture.posts.length === 1, `${mode} stays pending without retransmission`);
    fixture.calls = [];
    await remount();
    await pause();
    check(fixture.calls.length === 0 && !!$('#consult-receipt'), `${mode} remount recovery precedes till/catalog/FX`);
  }
  fixture.mode = '404';
  $('#consult-receipt').click();
  await pause();
  check(localStorage.getItem(key) !== null && fixture.posts.length === 1, 'GET 404 never releases pending sale');
  fixture.mode = '403';
  $('#consult-receipt').click();
  await pause();
  check(localStorage.getItem(key) !== null, 'changed permission retains pending sale');
  ctx.me.staffId = fixture.id(10);
  await remount();
  await pause();
  check(!$('#consult-receipt') && localStorage.getItem(key) !== null, 'account switch quarantines marker');
  await post('loss');
  fixture.mode = 'ok';
  $('#consult-receipt').click();
  await pause();
  check(
    !!$('#finish-recovery') && $('#screen').textContent.includes('Venta registrada'),
    'matching original cashier/till receipt confirms',
  );
  $('#finish-recovery').click();
  await pause();
  check(!!$('#pay') && !localStorage.getItem(key), 'confirmed recovery can continue on original mount');
  await post('ancillary');
  check(!!$('#receipt') && !$('#receipt').hidden && !localStorage.getItem(key), 'confirmed response survives ancillary receipt failure');
  await post('reject');
  check(!localStorage.getItem(key) && !$('#received').disabled, 'definitive first domain rejection releases lock');
  await reset();
  localStorage.setItem(key, '{');
  fixture.calls = [];
  await remount();
  check(fixture.calls.length === 0 && !$('#pay'), 'corrupt marker blocks before dependencies');
  await reset();
  await prepare();
  const set = Storage.prototype.setItem;
  Storage.prototype.setItem = function (k, v) {
    if (k === key) throw Error('storage denied');
    return set.call(this, k, v);
  };
  try {
    $('#pay').click();
    await pause();
    check(fixture.posts.length === 0, 'denied durability blocks POST');
  } finally {
    Storage.prototype.setItem = set;
  }
  await reset();
  await prepare();
  fixture.mode = 'hold';
  $('#pay').click();
  await pause();
  ctx.me = { ...original, staffId: fixture.id(10) };
  await remount();
  fixture.release();
  await pause();
  check(!$('#receipt') && $('#screen').textContent.includes('otra cuenta'), 'stale completion cannot replace new account quarantine');
  await reset();
  const savedLines = [
    {
      itemId: fixture.id(8),
      name: 'Blusa demo',
      sku: 'DEMO-1',
      quantity: 1,
      unitPriceMinor: 10000,
      sellerId: fixture.id(1),
      ticketKey: 'one',
    },
    {
      itemId: fixture.id(8),
      name: 'Blusa demo',
      sku: 'DEMO-1',
      quantity: 1,
      unitPriceMinor: 10000,
      sellerId: fixture.id(11),
      ticketKey: 'two',
    },
  ];
  localStorage.setItem(
    'savia.device.parkedTickets',
    JSON.stringify({
      tillId: fixture.id(5),
      tickets: [{ id: 'saved', name: 'Demo', lines: savedLines, sellers: [fixture.id(1), fixture.id(11)], ticketPercent: 0 }],
    }),
  );
  $('#sale-advanced').open = true;
  $('#saved-tickets').click();
  $('.restore-ticket').click();
  await pause();
  input('#received', '200');
  check(
    $('.tline') && document.querySelectorAll('.tline').length === 2 && $('#pay').disabled,
    'restored duplicate garment keeps invalid assignment blocked',
  );
  input('#sale-seller-2', fixture.id(6), 'change');
  check(!$('#pay').disabled && document.querySelectorAll('.tline').length === 2, 'deliberate reassignment preserves separate lines');
  $('#shared-sale').click();
  input('#sale-seller-3', fixture.id(12), 'change');
  check(!$('#shared-sale'), 'maximum three sellers');
  await reset();
  await prepare();
  ctx.isApprover = false;
  $('#sale-advanced').open = true;
  input('#ticket-discount', '10', 'change');
  $('#pay').click();
  await pause();
  [...document.querySelectorAll('#modal button')].find(b => b.textContent === 'Cancelar').click();
  await pause();
  check(fixture.posts.length === 0 && !$('#received').disabled, 'supervisor cancel releases unsent draft');
  $('#pay').click();
  await pause();
  input('#approval-user', 'Fictional');
  input('#approval-pass', 'Fictional');
  input('#approval-reason', 'Demo');
  input('#approval-discount-0', '20');
  fixture.mode = 'expiry';
  document.querySelector('#modal form').dispatchEvent(new Event('submit', { cancelable: true, bubbles: true }));
  await pause();
  check(
    fixture.posts.length === 1 && fixture.posts[0].lines[0].discountMinor === 2000 && !localStorage.getItem(key),
    'approval recomputes final body and first expiry rejection releases',
  );
  check(
    fixture.auth['X-Savia-Approval'] === 'fictional-supervisor' && !fixture.auth.Authorization,
    'supervisor token stays in distinct approval header',
  );
  check(
    !!$('#screen .error button[aria-expanded]') && !document.querySelector('p details'),
    'diagnostic disclosure uses valid inline HTML',
  );
  await reset();
  await prepare();
  ctx.isApprover = false;
  $('#sale-advanced').open = true;
  input('#ticket-discount', '10', 'change');
  $('#pay').click();
  await pause();
  input('#approval-user', 'Fictional');
  input('#approval-pass', 'Fictional');
  input('#approval-reason', 'Demo');
  input('#approval-discount-0', '20');
  fixture.mode = 'hold';
  document.querySelector('#modal form').dispatchEvent(new Event('submit', { cancelable: true, bubbles: true }));
  await pause();
  check(
    [...document.querySelectorAll('#ticket-lines input, #ticket-lines select, #ticket-lines button')].every(el => el.disabled) &&
      $('#received').disabled &&
      $('#pay').disabled,
    'supervisor redraw keeps every recreated ticket control disabled during POST',
  );
  const heldBody = JSON.stringify(fixture.posts[0]);
  const heldMarker = localStorage.getItem(key);
  await handle.handleScan('DEMO-1');
  input('.qty-input', '2', 'change');
  check(
    fixture.posts.length === 1 &&
      JSON.stringify(fixture.posts[0]) === heldBody &&
      fixture.posts[0].lines[0].discountMinor === 2000 &&
      fixture.posts[0].lines[0].quantity === 1 &&
      localStorage.getItem(key) === heldMarker,
    'supervised held request keeps final body and pending bytes without another POST',
  );
  fixture.release();
  await pause();
  check(!!$('#receipt') && !$('#receipt').hidden && !localStorage.getItem(key), 'supervised held attempt confirms once');
  await reset();
  return results;
}
