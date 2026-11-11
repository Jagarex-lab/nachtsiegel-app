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
const launch = {headless: true, ignoreDefaultArgs: ['--mute-audio']};
if (profile === 'webkit' && process.env.WEBKIT_PATH) launch.executablePath = process.env.WEBKIT_PATH;
if (profile !== 'webkit') {
  launch.executablePath = process.env.CHROMIUM_PATH || '/usr/bin/chromium';
  launch.args = ['--no-sandbox', '--autoplay-policy=user-gesture-required'];
}
const errors = [];
const graphicsDiagnostics = [];
const evidence = {profile, url, checked: [], errors, graphicsDiagnostics};
let browser;
try {
  browser = await browserType.launch(launch);
  const device = profile === 'android' ? devices['Pixel 7'] : profile === 'webkit' ? devices['iPhone 13'] : {viewport: {width: 1100, height: 720}};
  const context = await browser.newContext(device);
  // Tee the actual destination connection into analysers. The original output
  // remains connected; this observes the exported engine's mixed audio graph.
  await context.addInitScript(() => {
    const contexts = [];
    const analysers = [];
    const attached = new WeakSet();
    for (const key of ['AudioContext', 'webkitAudioContext']) {
      const Native = window[key];
      if (!Native) continue;
      window[key] = new Proxy(Native, {
        construct(target, args) {
          const instance = Reflect.construct(target, args);
          contexts.push(instance);
          return instance;
        },
      });
    }
    const connect = AudioNode.prototype.connect;
    AudioNode.prototype.connect = function (...args) {
      const result = connect.apply(this, args);
      if (args[0] === this.context.destination && !attached.has(this)) {
        attached.add(this);
        const analyser = this.context.createAnalyser();
        analyser.fftSize = 2048;
        connect.call(this, analyser, typeof args[1] === 'number' ? args[1] : 0);
        // Keep the observation branch in the rendering graph without doubling
        // the audible output. Some engines prune a dangling analyser output.
        const silent = this.context.createGain();
        silent.gain.value = 0;
        connect.call(analyser, silent);
        connect.call(silent, this.context.destination);
        analysers.push(analyser);
      }
      return result;
    };
    window.__audioQAProbe = () => {
      let peak = 0;
      let energy = 0;
      let samples = 0;
      for (const analyser of analysers) {
        const values = new Float32Array(analyser.fftSize);
        analyser.getFloatTimeDomainData(values);
        for (const value of values) {
          peak = Math.max(peak, Math.abs(value));
          energy += value * value;
          samples++;
        }
      }
      return {contexts: contexts.map(item => ({state: item.state, sample_rate: item.sampleRate})),
        analysers: analysers.length, peak, rms: samples ? Math.sqrt(energy / samples) : 0};
    };
  });
  const page = await context.newPage();
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => {
    if (message.type() !== 'error' || message.text().includes('favicon.ico')) return;
    // Record Godot/WebGL framebuffer diagnostics separately from audio failures.
    // Do not discard them: graphics QA must investigate these independently.
    if (message.text().includes('WebGL: INVALID_OPERATION: glBlitFramebuffer: Read and write color attachments cannot be the same image.')) {
      graphicsDiagnostics.push(message.text());
    } else {
      errors.push(message.text());
    }
  });
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
  evidence.audio_before_gesture = await page.evaluate(() => window.__audioQAProbe());
  assert.equal((await snapshot()).snapshot.unlocked, false);
  assert.equal((await command({action: 'event', event: 'card.draw'})).last_result, false);
  evidence.checked.push('locked-before-gesture');
  if (profile === 'android' || profile === 'webkit') await page.touchscreen.tap(90, 60);
  else await page.mouse.click(90, 60);
  await page.waitForFunction(() => window.audioQA?.snapshot.unlocked, null, {timeout: 10000});
  assert.equal((await command({action: 'event', event: 'card.draw'})).last_result, true);
  assert.equal((await command({action: 'event', event: 'qa.unknown'})).last_result, false);
  evidence.checked.push('gesture-unlock-and-safe-invalid-event');
  evidence.after_unlock_snapshot = (await snapshot()).snapshot;
  let measured = {peak: 0, rms: 0, contexts: [], analysers: 0};
  for (let attempt = 0; attempt < 20; attempt++) {
    const probe = await page.evaluate(() => window.__audioQAProbe());
    if (probe.peak >= measured.peak) measured = probe;
    if (probe.rms > 0.000001) break;
    await page.waitForTimeout(100);
  }
  evidence.audio_after_gesture = measured;
  assert.ok(measured.contexts.some(item => item.state === 'running'), 'No running browser AudioContext after gesture');
  assert.ok(measured.analysers > 0 && measured.rms > 0.000001, 'Exported audio graph produced no measurable signal');
  evidence.checked.push('running-audio-context-and-nonzero-mixed-signal');
  for (const contextName of ['duel', 'tense', 'convergence', 'menu']) {
    assert.equal((await command({action: 'music', context: contextName, fade: 0.15})).last_result, true);
  }
  await page.waitForFunction(() => !window.audioQA.snapshot.music.transitioning, null, {timeout: 10000});
  evidence.checked.push('rapid-music-crossfades');
  const dispatchStart = performance.now();
  const burst = await command({action: 'burst'});
  evidence.burst_roundtrip_ms = performance.now() - dispatchStart;
  assert.ok(burst.snapshot.peak_voices <= 16);
  assert.ok(burst.snapshot.pool_size === 16);
  evidence.checked.push('pool-bound-under-burst');
  await command({action: 'suspend', value: true});
  assert.equal((await command({action: 'event', event: 'card.draw'})).last_result, false);
  await command({action: 'suspend', value: false});
  evidence.checked.push('explicit-suspend-resume');
  await command({action: 'mute', value: true});
  await page.waitForTimeout(500);
  evidence.audio_muted = await page.evaluate(() => window.__audioQAProbe());
  assert.ok(evidence.audio_muted.rms < 0.0000001, 'Mute left an audible graph signal');
  await command({action: 'mute', value: false});
  await page.waitForFunction(() => window.__audioQAProbe().rms > 0.000001, null, {timeout: 10000});
  evidence.checked.push('master-mute-silences-real-output-and-recovers');
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
  // Refused browser storage must be visible and recover without gameplay errors.
  await page.evaluate(() => {
    window.__originalAudioSetItem = Storage.prototype.setItem;
    Storage.prototype.setItem = function () {throw new DOMException('QA quota', 'QuotaExceededError');};
  });
  assert.equal((await command({action: 'save'})).last_result, false);
  assert.notEqual((await snapshot()).snapshot.last_save_error, 0);
  await page.evaluate(() => {Storage.prototype.setItem = window.__originalAudioSetItem;});
  assert.equal((await command({action: 'save'})).last_result, true);
  evidence.checked.push('storage-denial-is-observable-and-recovers');
  const mirror = await page.evaluate(() => {
    const key = Object.keys(localStorage).find(item => item.startsWith('orafold.audio.v1:'));
    return {key, value: localStorage.getItem(key)};
  });
  assert.ok(mirror.key, 'No dedicated audio mirror found');
  const future = JSON.stringify({version: 2, settings: {future: 'preserve'}});
  await page.evaluate(({key, value}) => localStorage.setItem(key, value), {key: mirror.key, value: future});
  await page.reload({waitUntil: 'domcontentloaded'});
  await page.waitForFunction(() => window.audioQA?.ready, null, {timeout: 60000});
  assert.equal((await command({action: 'save'})).last_result, false);
  assert.equal(await page.evaluate(key => localStorage.getItem(key), mirror.key), future);
  await page.evaluate(({key, value}) => localStorage.setItem(key, value), mirror);
  await page.reload({waitUntil: 'domcontentloaded'});
  await page.waitForFunction(() => window.audioQA?.ready, null, {timeout: 60000});
  assert.equal((await command({action: 'save'})).last_result, true);
  evidence.checked.push('future-mirror-schema-preserved-until-explicit-recovery');
  assert.equal(errors.length, 0, JSON.stringify(errors));
  evidence.graphics_diagnostics_count = graphicsDiagnostics.length;
  evidence.checked.push('graphics-diagnostics-reported-separately-from-audio-errors');
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
