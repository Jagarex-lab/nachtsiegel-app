const assert = require('node:assert/strict');
const { test } = require('node:test');
const http = require('node:http');
const { spawnSync } = require('node:child_process');
const { chromium } = require('playwright');

test('actual SaveAdapter browser scripts persist and fail atomically', async (t) => {
  const exported = spawnSync(process.env.GODOT_BIN || 'godot',
    ['--headless', '--path', '.', '--script', 'tests/economy_web_scripts.gd'],
    { encoding: 'utf8', timeout: 30000 });
  assert.equal(exported.status, 0, exported.stdout + exported.stderr);
  assert.doesNotMatch(exported.stdout + exported.stderr, /SCRIPT ERROR|^ERROR:/m);
  const line = exported.stdout.split('\n').find(s => s.startsWith('ECONOMY_WEB_SCRIPTS='));
  assert.ok(line, 'Godot exported the exact expressions used by SaveAdapter');
  const scripts = JSON.parse(line.slice('ECONOMY_WEB_SCRIPTS='.length));
  const server = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end('<!doctype html><title>Economy storage integration test</title>');
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_BIN || '/usr/bin/chromium',
    headless: true, args: ['--no-sandbox'] });
  t.after(() => browser.close());
  const page = await browser.newPage();
  await page.goto(`http://127.0.0.1:${server.address().port}/`);
  const evaluate = script => page.evaluate(source => window.eval(source), script);
  assert.deepEqual(JSON.parse(await evaluate(scripts.read)), { status: 'missing' });
  assert.equal(await evaluate(scripts.first), true);
  await page.reload();
  let read = JSON.parse(await evaluate(scripts.read));
  assert.equal(read.status, 'present');
  assert.equal(JSON.parse(read.raw).primary.wallet.gold, 100);
  assert.equal(await evaluate(scripts.second), true);
  await page.reload();
  read = JSON.parse(await evaluate(scripts.read));
  const envelope = JSON.parse(read.raw);
  assert.equal(envelope.primary.wallet.gold, 0);
  assert.equal(envelope.primary.receipts.purchase, true);
  assert.equal(envelope.backup.wallet.gold, 100);

  const unchanged = read.raw;
  await page.evaluate(() => {
    window.originalSetItem = Storage.prototype.setItem;
    Storage.prototype.setItem = () => { throw new DOMException('Full', 'QuotaExceededError'); };
  });
  assert.equal(await evaluate(scripts.first), false, 'quota failure never commits');
  assert.equal(JSON.parse(await evaluate(scripts.read)).raw, unchanged, 'balances and receipt remain paired');
  await page.evaluate(() => { Storage.prototype.setItem = window.originalSetItem; });
  await page.evaluate(() => {
    window.originalGetItem = Storage.prototype.getItem;
    Storage.prototype.getItem = () => { throw new DOMException('Denied', 'SecurityError'); };
  });
  assert.deepEqual(JSON.parse(await evaluate(scripts.read)), { status: 'error' }, 'denied storage differs from first launch');
  await page.evaluate(() => { Storage.prototype.getItem = window.originalGetItem; });

  for (const invalid of ['', 'null', '[]', '{}', 'malformed']) {
    await page.evaluate(({ key, raw }) => localStorage.setItem(key, raw), { key: scripts.key, raw: invalid });
    read = JSON.parse(await evaluate(scripts.read));
    assert.equal(read.status, 'present', `present ${JSON.stringify(invalid)} cannot look like new storage`);
    assert.equal(read.raw, invalid);
  }
});
