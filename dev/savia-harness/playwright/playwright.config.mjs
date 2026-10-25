import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';

const pkg = process.env.SAVIA_PLAYWRIGHT_PACKAGE;
if (!pkg) throw new Error('Set SAVIA_PLAYWRIGHT_PACKAGE to an installed official playwright package; no automatic installation.');
const {defineConfig} = await import(pathToFileURL(path.join(pkg, 'test.mjs')).href);
const origin = process.env.SAVIA_QA_ORIGIN;
if (!/^http:\/\/127\.0\.0\.1:\d{2,5}$/.test(origin || '')) throw new Error('SAVIA_QA_ORIGIN must be an explicit loopback HTTP origin.');
const port = Number(new URL(origin).port);
if (port < 1024 || port > 65535) throw new Error('Use an unprivileged loopback port.');
const here = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  testDir: here,
  testMatch: '**/*.spec.mjs',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  forbidOnly: true,
  timeout: 30_000,
  globalTimeout: 90_000,
  reporter: 'list',
  outputDir: process.env.SAVIA_QA_OUTPUT || path.join(here, 'results'),
  use: {
    baseURL: origin,
    channel: 'chrome',
    headless: true,
    trace: 'on',
    launchOptions: {args: ['--disable-background-networking']},
  },
});
