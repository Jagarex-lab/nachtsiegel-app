// Optional actual browser transport smoke; not a Godot Web export/device test.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const playwright = require(process.env.PLAYWRIGHT_MODULE ?? 'playwright');
const api = process.env.API_BASE ?? 'http://127.0.0.1:8787';
if (!/^http:\/\/(127\.0\.0\.1|localhost):\d+$/.test(api)) throw new Error('LOCAL_API_ONLY');
const results = [];
for (const engine of ['chromium', 'webkit']) {
  let browser;
  try {
    browser = await playwright[engine].launch(engine === 'chromium' ? { ...(process.env.CHROMIUM_EXECUTABLE ? {executablePath:process.env.CHROMIUM_EXECUTABLE} : {}), headless: true, args: ['--no-sandbox'] } : { headless: true });
  } catch (error) {
    results.push({ engine, status: 'unavailable', reason: String(error.message).split('\n')[0] });
    continue;
  }
  try {
    const context = await browser.newContext();
    // The intercepted local HTML fixture has no resolved address-space metadata.
    // Grant Chromium's normal loopback permission for this local-only test origin.
    if (engine === 'chromium') await context.grantPermissions(['local-network-access'], {origin:api});
    const page = await context.newPage();
    await page.route(`${api}/browser-fixture`, route => route.fulfill({ contentType: 'text/html', body: '<!doctype html><title>Local online transport test</title>' }));
    await page.goto(`${api}/browser-fixture`);
    const username = `browser_${randomUUID().replaceAll('-', '').slice(0, 16)}`;
    const password = randomUUID();
    const output = await page.evaluate(async ({ username, password }) => {
      const post = async (path, body, csrf) => fetch(path, { method: 'POST', credentials: 'same-origin', headers: { 'Content-Type': 'application/json', ...(csrf ? { 'X-CSRF-Token': csrf } : {}) }, body: JSON.stringify(body) });
      const registration = await post('/auth/register', { username, password, display_name: 'Browser Smoke' });
      if (registration.status !== 202) throw new Error(`registration status ${registration.status}`);
      const login = await post('/auth/login', { username, password });
      const session = await login.json();
      if (login.status !== 200 || 'token' in session || !session.csrf_token) throw new Error('cookie login contract');
      const visibleCookie = document.cookie;
      const csrfDenied = (await post('/transport/ticket', {})).status;
      const resumed = await (await fetch('/auth/session', { credentials: 'same-origin' })).json();
      if (resumed.csrf_token !== session.csrf_token) throw new Error('cookie session resume failed');
      const ticketResponse = await post('/transport/ticket', {}, resumed.csrf_token);
      const ticketBody = await ticketResponse.json();
      if (ticketResponse.status !== 200 || typeof ticketBody.ticket !== 'string') throw new Error(`ticket status ${ticketResponse.status} code ${ticketBody.code ?? 'missing_ticket'}`);
      const { ticket } = ticketBody;
      const protocol = await new Promise((resolve, reject) => {
        const socket = new WebSocket(`${location.origin.replace('http:', 'ws:')}/ws?ticket=${encodeURIComponent(ticket)}`);
        const deadline = setTimeout(() => { socket.close(); reject(new Error('websocket timeout')); }, 5000);
        socket.onopen = () => socket.send(JSON.stringify({ protocol_version: 1, type: 'session.resume', request_id: 'browser_smoke' }));
        socket.onerror = () => { clearTimeout(deadline); reject(new Error('websocket failed')); };
        socket.onmessage = event => { clearTimeout(deadline); socket.close(); resolve(JSON.parse(event.data).protocol_version); };
      });
      return { visibleCookie, csrfDenied, protocol, tokenReadable: 'token' in session };
    }, { username, password });
    assert.equal(output.visibleCookie, '');
    assert.equal(output.csrfDenied, 403);
    assert.equal(output.protocol, 1);
    assert.equal(output.tokenReadable, false);
    const sessionCookie = (await context.cookies()).find(cookie => cookie.name === 'orafold_session');
    assert.ok(sessionCookie?.httpOnly);
    assert.equal(sessionCookie.sameSite, 'Strict');
    const logout = await page.evaluate(async () => {
      const session = await (await fetch('/auth/session')).json();
      return (await fetch('/auth/logout', { method: 'POST', headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': session.csrf_token }, body: '{}' })).status;
    });
    assert.equal(logout, 200);
    assert.equal((await context.cookies()).some(cookie => cookie.name === 'orafold_session'), false);
    results.push({ engine, status: 'passed', checks: ['registration', 'HttpOnly SameSite cookie login', 'no script-readable bearer', 'CSRF rejection', 'cookie session bootstrap', 'ticket WebSocket protocol', 'logout cookie removal'] });
    await context.close();
  } catch (error) {
    results.push({ engine, status: 'failed', reason: String(error.message) });
    process.exitCode = 1;
  } finally { await browser.close(); }
}
if (!results.some(result => result.status === 'passed')) process.exitCode = 1;
console.log(JSON.stringify({ browser_transport_smoke: results, godot_web_export_tested: false }, null, 2));
