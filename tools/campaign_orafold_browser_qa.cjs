'use strict';
// Read-only QA telemetry locates real rendered controls. All game actions use
// real pointer/touch input; no state or result is injected through JavaScript.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
let playwright;
try { playwright = require('playwright'); }
catch { playwright = require('playwright-core'); }
const out = 'work/campaign_orafold';
fs.mkdirSync(out, {recursive: true});

(async () => {
  const profiles = [
    {name: 'desktop', viewport: {width: 1280, height: 900}, deviceScaleFactor: 1, hasTouch: false},
    {name: 'portrait', viewport: {width: 390, height: 844}, deviceScaleFactor: 2, hasTouch: true, isMobile: true},
  ];
  const records = [];
  const browser = await playwright.chromium.launch({
    headless: true,
    ...(process.env.CAMPAIGN_CHROMIUM ? {executablePath: process.env.CAMPAIGN_CHROMIUM} : {}),
    args: ['--no-sandbox', '--disable-dev-shm-usage', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  });
  try {
    for (const profile of profiles) {
      const {name, ...options} = profile;
      const context = await browser.newContext(options);
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', error => errors.push(String(error)));
      page.on('console', message => {if (message.type() === 'error') errors.push(message.text());});
      const snapshot = () => page.evaluate(() => window.orafoldCampaignQA);
      const wait = condition => page.waitForFunction(condition, undefined, {timeout: 90000});
      const url = new URL(process.env.GAME_URL || 'http://127.0.0.1:8791/');
      url.searchParams.set('qa', '1');
      const started = Date.now();
      try {
        const metadata = await context.request.get(new URL('build-info.json', url).href);
        assert(metadata.ok(), 'QA metadata loads');
        const info = await metadata.json();
        assert.equal(info.channel, 'isolated-campaign-qa');
        assert.equal(info.production_release, false);
        await page.goto(url.href, {waitUntil: 'networkidle'});
        await wait(() => window.orafoldCampaignQA?.screen === 'overview');
        assert.match((await snapshot()).title, /Die unbeschriebene Zeile|The Unwritten Line/);
        const bootMs = Date.now() - started;
        const canvas = await page.locator('canvas').boundingBox();
        assert(canvas && canvas.width >= profile.viewport.width - 1 && canvas.height >= profile.viewport.height - 1, 'canvas fills viewport');

        // Scroll with genuine browser input until an off-screen control is visible.
        const locate = async id => {
          await page.waitForFunction(id => window.orafoldCampaignQA?.actions?.[id], id, {timeout: 30000});
          for (let attempt = 0; attempt < 16; attempt++) {
            const state = await snapshot();
            const action = state.actions[id];
            assert(!action.disabled, `${id}: enabled`);
            const [x, y, w, h] = action.rect;
            if (x >= -1 && y >= 0 && x + w <= profile.viewport.width + 1 && y + h <= profile.viewport.height - 1) {
              assert(w >= 43.9 && h >= 43.9, `${id}: touch target >=44px`);
              return {x: x + w / 2, y: y + h / 2};
            }
            const direction = y < 120 ? -1 : 1;
            await page.mouse.move(profile.viewport.width / 2, profile.viewport.height * .65);
            if (profile.hasTouch) {
              const cdp = await context.newCDPSession(page);
              const begin = direction > 0 ? profile.viewport.height * .78 : profile.viewport.height * .40;
              const end = direction > 0 ? profile.viewport.height * .35 : profile.viewport.height * .78;
              await cdp.send('Input.dispatchTouchEvent', {type: 'touchStart', touchPoints: [{x: profile.viewport.width / 2, y: begin}]});
              for (let step = 1; step <= 8; step++) {
                await cdp.send('Input.dispatchTouchEvent', {type: 'touchMove', touchPoints: [{x: profile.viewport.width / 2, y: begin + (end - begin) * step / 8}]});
                await page.waitForTimeout(18);
              }
              await cdp.send('Input.dispatchTouchEvent', {type: 'touchEnd', touchPoints: []});
              await cdp.detach();
            } else await page.mouse.wheel(0, direction * 350);
            await page.waitForTimeout(350);
          }
          throw new Error(`${id}: could not scroll the rendered control into view`);
        };
        const action = async id => {
          const point = await locate(id);
          if (profile.hasTouch) await page.touchscreen.tap(point.x, point.y);
          else await page.mouse.click(point.x, point.y);
          await page.waitForTimeout(250);
        };
        const shot = async suffix => {
          const buffer = await page.screenshot({path: path.join(out, `${name}-${suffix}.png`)});
          assert(buffer.length > 12000, 'rendered screenshot has substantive content');
          assert.equal(buffer.readUInt32BE(16), profile.viewport.width * profile.deviceScaleFactor);
          assert.equal(buffer.readUInt32BE(20), profile.viewport.height * profile.deviceScaleFactor);
        };
        await shot('overview');
        await action('chapter_cp01');
        await wait(() => window.orafoldCampaignQA.scene_id === 'threshold');
        await shot('dialogue');
        await action('next');
        await action('next');
        await shot('dialogue-portrait');
        // Next may first reveal the remaining characters. Both operations use UI input.
        for (let step = 0; step < 16 && (await snapshot()).scene_id !== 'first_question'; step++) await action('next');
        assert.equal((await snapshot()).scene_id, 'first_question');
        for (let step = 0; step < 8 && !(await snapshot()).actions.choice_preserve; step++) await action('next');
        await action('choice_preserve');
        await wait(() => window.orafoldCampaignQA.flags?.approach === 'preserve');
        assert.equal((await snapshot()).scene_id, 'preserve');
        const savedScene = (await snapshot()).scene_id;
        const localMirror = await page.evaluate(() => Object.keys(localStorage).filter(key => key.includes('orafold') && key.includes('campaign')));
        assert(localMirror.length > 0, 'isolated campaign mirror written to localStorage');
        await page.reload({waitUntil: 'networkidle'});
        await wait(() => window.orafoldCampaignQA?.screen === 'overview');
        assert.equal((await snapshot()).flags.approach, 'preserve', 'choice persists across reload');
        assert.equal((await snapshot()).scene_id, savedScene, 'safe scene persists across reload');
        await action('resume');
        await wait(() => window.orafoldCampaignQA?.screen === 'dialogue');
        assert.equal((await snapshot()).scene_id, 'preserve');
        await shot('resumed');
        assert.equal((await snapshot()).save_error, '', 'no save error');
        assert.equal(errors.length, 0, errors.join('\n'));
        records.push({profile: name, viewport: profile.viewport, dpr: profile.deviceScaleFactor, boot_ms: bootMs, checks: ['isolated QA metadata', 'correct campaign title', 'rendered full viewport canvas', 'real pointer/touch chapter start and choice', '44px controls', 'choice and safe scene reload persistence', 'real UI resume'], errors});
        console.log(`CAMPAIGN WEB ${name}: PASS`);
      } catch (error) {
        const state = await snapshot().catch(() => null);
        fs.writeFileSync(path.join(out, `${name}-browser-error.json`), JSON.stringify({error: String(error), errors, state}, null, 2));
        await page.screenshot({path: path.join(out, `${name}-browser-error.png`)}).catch(() => {});
        throw error;
      } finally { await context.close(); }
    }
  } finally { await browser.close(); }
  fs.writeFileSync(path.join(out, 'browser-results.json'), JSON.stringify(records, null, 2) + '\n');
  console.log(`CAMPAIGN WEB: ${records.length} profiles, 0 failures`);
})().catch(error => {console.error(error); process.exitCode = 1;});
