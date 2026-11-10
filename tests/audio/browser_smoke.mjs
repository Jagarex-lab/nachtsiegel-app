// Run against an HTTP-served work/audio/fixture/build/web export.
// AUDIO_QA_URL=http://127.0.0.1:8765 AUDIO_QA_PROFILE=chromium|android|webkit node tests/audio/browser_smoke.mjs
import {createRequire} from 'node:module';
import {mkdir, writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const require = createRequire(import.meta.url);
const {chromium, webkit, devices} = require('playwright');
const profile = process.env.AUDIO_QA_PROFILE || 'chromium';
const url = process.env.AUDIO_QA_URL || 'http://127.0.0.1:8765';
const browserType = profile === 'webkit' ? webkit : chromium;
const launch = {headless: true};
if (profile !== 'webkit') {
  launch.executablePath = process.env.CHROMIUM_PATH || '/usr/bin/chromium';
  launch.args = ['--no-sandbox', '--autoplay-policy=user-gesture-required'];
}
const errors = [];
const evidence = {profile, url, checked: [], errors};
let browser;
try {
  browser = await browserType.launch(launch);
  const device = profile === 'android' ? devices['Pixel 7'] : profile === 'webkit' ? devices['iPhone 13'] : {viewport: {width: 1100, height: 720}};
  const context = await browser.newContext(device);
  const page = await context.newPage();
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {if (message.type() === 'error' && !message.text().includes('favicon.ico')) errors.push(message.text());});
  if (profile === 'android') {
    const cdp = await context.newCDPSession(page);
    await cdp.send('Emulation.setCPUThrottlingRate', {rate: 4});
    evidence.cpu_throttle = 4;
  }
  let id = 0;
  const snapshot = () => page.evaluate(() => window.audioQA);
  const command = async data => {
    const current = ++id;
    await page.evaluate(value => window.audioQACommand(JSON.stringify(value)), {...data, id: current});
    await page.waitForFunction(value => window.audioQA?.last_id === value, current, {timeout: 10000});
    return snapshot();
  };
  const load = async () => {
    await page.goto(url, {waitUntil: 'domcontentloaded', timeout: 30000});
    await page.waitForFunction(() => window.audioQA?.ready, null, {timeout: 60000});
  };
  await load();
  assert.equal((await snapshot()).snapshot.unlocked, false);
  assert.equal((await command({action: 'event', event: 'card.draw'})).last_result, false);
  evidence.checked.push('locked-before-gesture');
  if (profile === 'android' || profile === 'webkit') await page.touchscreen.tap(90, 60);
  else await page.mouse.click(90, 60);
  await page.waitForFunction(() => window.audioQA?.snapshot.unlocked, null, {timeout: 10000});
  assert.equal((await command({action: 'event', event: 'card.draw'})).last_result, true);
  assert.equal((await command({action: 'event', event: 'qa.unknown'})).last_result, false);
  evidence.checked.push('gesture-unlock-and-safe-invalid-event');
  for (const contextName of ['duel', 'tense', 'convergence', 'menu']) {
    assert.equal((await command({action: 'music', context: contextName, fade: 0.15})).last_result, true);
  }
  await page.waitForFunction(() => !window.audioQA.snapshot.music.transitioning, null, {timeout: 10000});
  evidence.checked.push('rapid-music-crossfades');
  const burst = await command({action: 'burst'});
  assert.ok(burst.snapshot.peak_voices <= 16);
  assert.ok(burst.snapshot.pool_size === 16);
  evidence.checked.push('pool-bound-under-burst');
  await command({action: 'suspend', value: true});
  assert.equal((await command({action: 'event', event: 'card.draw'})).last_result, false);
  await command({action: 'suspend', value: false});
  evidence.checked.push('explicit-suspend-resume');
  assert.equal((await command({action: 'volume', channel: 'music', value: 0.37})).last_result, true);
  await command({action: 'reduced', value: true});
  assert.equal((await command({action: 'save'})).last_result, true);
  evidence.before_reload = (await snapshot()).snapshot.settings;
  await page.reload({waitUntil: 'domcontentloaded'});
  await page.waitForFunction(() => window.audioQA?.ready, null, {timeout: 60000});
  const reloaded = await snapshot();
  evidence.after_reload = reloaded.snapshot.settings;
  assert.ok(Math.abs(reloaded.snapshot.settings.music - 0.37) < 0.0001);
  assert.equal(reloaded.snapshot.settings.reduced_intensity, true);
  evidence.checked.push('persisted-settings-after-immediate-reload');
  assert.equal(errors.length, 0, JSON.stringify(errors));
  evidence.result = 'passed';
  await mkdir('work/audio/browser', {recursive: true});
  await page.screenshot({path: `work/audio/browser/${profile}.png`});
  evidence.final_snapshot = (await snapshot()).snapshot;
} catch (error) {
  evidence.result = 'failed';
  evidence.failure = error.stack || String(error);
  process.exitCode = 1;
} finally {
  if (browser) await browser.close();
  await mkdir('work/audio/browser', {recursive: true});
  await writeFile(`work/audio/browser/${profile}.json`, JSON.stringify(evidence, null, 2));
  console.log(JSON.stringify(evidence, null, 2));
}
