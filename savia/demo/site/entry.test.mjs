import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../../../', import.meta.url));
const frozen = '2c96904f49d2df913850bc13cf53b3b03ceebacf';
test('real staff login and etiqueta entry remain frozen', () => {
  // Navigation and sale/API changes are authorized in the parallel UX increment.
  // Their behavior is covered by the staff-web suite, not an obsolete whole-file pin.
  for (const path of ['savia/web/screens/login.mjs', 'savia/web/etiqueta/etiqueta.mjs']) {
    assert.deepEqual(readFileSync(root + path), execFileSync('git', ['show', `${frozen}:${path}`], { cwd: root }));
  }
});
test('built fictional demo ships no tests and keeps same-origin CSP', () => {
  const output = root + 'savia/.out/demo-site/';
  const files = readdirSync(output, { recursive: true }).map(String);
  assert.ok(!files.some(path => path.includes('.test.') || /(^|[\\/])tests([\\/]|$)/.test(path)));
  assert.match(readFileSync(output + '_headers', 'utf8'), /connect-src 'self'/);
  assert.match(readFileSync(output + 'demo/api/index.mjs', 'utf8'), /savia.demo.v1/);
});
test('invented API entry, persistence, reset, expiry and role boundaries in real browser', () => {
  const result = execFileSync('python', ['docs/savia-ux-20261116/demo/real_browser.py'], { cwd: root, timeout: 240000, encoding: 'utf8' });
  assert.match(result, /"pass": true/);
});
