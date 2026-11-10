// Actual exported Alpha product, real canvas controls and mixed WebAudio output.
// NODE_PATH=<playwright> AUDIO_PRODUCT_URL=http://127.0.0.1:8766 AUDIO_QA_PROFILE=chromium|webkit node tests/audio/product_browser.mjs
import {createRequire} from 'node:module';
import {mkdir,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url);
const {chromium,webkit}=require('playwright');
const profile=process.env.AUDIO_QA_PROFILE||'chromium';
const url=process.env.AUDIO_PRODUCT_URL||'http://127.0.0.1:8766';
const evidence={profile,url,scope:'Actual exported product in browser; no physical device or human listening claim.',checks:[],errors:[],graphicsDiagnostics:[]};
evidence.checks.push = function (...items) {console.error(items.join("; "));return Array.prototype.push.apply(this,items)};
let browser;
const deadline=setTimeout(()=>{console.error('Audio product browser deadline exceeded');process.exit(2)},300000);
try {
  browser=await (profile==='webkit'?webkit:chromium).launch(profile==='webkit'?{headless:true}:{headless:true,channel:'chromium',ignoreDefaultArgs:['--mute-audio'],args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader','--autoplay-policy=user-gesture-required']});
  const context=await browser.newContext({viewport:{width:1100,height:800}});
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
  const page=await context.newPage();
  page.on('pageerror',e=>evidence.errors.push(e.message));
  page.on('console',m=>{
    if(m.type()!=='error'||m.text().includes('favicon.ico'))return;
    if(m.text().includes('glBlitFramebuffer: Read and write color attachments cannot be the same image.'))evidence.graphicsDiagnostics.push(m.text());
    else evidence.errors.push(m.text());
  });
  const state=()=>page.evaluate(()=>window.orafoldQA);
  const settle=()=>page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>setTimeout(resolve,180)))));
  async function load(){await page.goto(`${url}/?qa=1`,{waitUntil:'domcontentloaded',timeout:45000});await page.waitForFunction(()=>window.orafoldQA?.audio?.events===52,null,{timeout:90000});await settle()}
  async function tap(key){
    let s=await state();assert(s.actions[key],`Missing actual action ${key}`);
    for(let attempt=0;attempt<12;attempt++){
      const r=s.actions[key].rect;const v=page.viewportSize();
      const fixed=["settings_back","menu","modal_close"].includes(key);
      if(r[1]>=(fixed?0:55)&&r[1]+r[3]<=v.height-10)break;
      await page.mouse.move(v.width/2,v.height/2);await page.mouse.wheel(0,r[1]<55?-240:240);await settle();s=await state();
    }
    const r=s.actions[key].rect;assert(!s.actions[key].disabled,`Disabled ${key}`);
    await page.mouse.click(r[0]+r[2]/2,r[1]+r[3]/2);await settle();
  }
  async function volume(channel,value){
    await tap(`audio_${channel}`);await page.keyboard.press('Home');
    for(let i=0;i<Math.round(value*100);i++)await page.keyboard.press('ArrowRight');
    await page.waitForFunction(({channel,value})=>Math.abs(window.orafoldQA.audio.settings[channel]-value)<.00001,{channel,value});await settle();
  }
  async function capture(action,duration=650){
    const signal=page.evaluate(ms=>new Promise(resolve=>{
      const started=performance.now();let peak=0,maxRms=0,n=0;
      function tick(){const p=window.__audioQAProbe();peak=Math.max(peak,p.peak);maxRms=Math.max(maxRms,p.rms);n++;if(performance.now()-started>=ms)resolve({peak,maxRms,samples:n,contexts:p.contexts,analysers:p.analysers});else requestAnimationFrame(tick)}tick();
    }),duration);
    if(action)await action();return signal;
  }
  async function settings(){if((await state()).page!=='settings')await tap('settings');await tap('settings_audio')}
  await load();
  evidence.initial=(await state()).audio;
  assert.equal(evidence.initial.unlocked,false);assert.equal(evidence.initial.pool_size,16);assert.equal(evidence.initial.music.players,2);
  assert.equal(evidence.initial.cached_streams,153);
  evidence.checks.push('Packaged52events153effectassets and single bounded owner; locked before gesture');
  await tap('settings');await page.waitForFunction(()=>window.orafoldQA.audio.unlocked);
  await page.waitForFunction(()=>window.__audioQAProbe().rms>0.000001,null,{timeout:15000});
  evidence.audibleMenu=await capture();assert(evidence.audibleMenu.maxRms>0.000001);
  await settings();
  await volume('master',0);evidence.masterZero=await capture();assert(evidence.masterZero.maxRms<1e-7,'Master zero did not silence actual output');
  await volume('master',1);await page.waitForFunction(()=>window.__audioQAProbe().rms>0.000001,null,{timeout:10000});
  await volume('music',0);evidence.musicZero=await capture();assert(evidence.musicZero.maxRms<1e-7,'Music zero did not silence isolated menu music');
  await volume('sfx',0);await volume('ui',1);
  evidence.uiWithEffectsZero=await capture(()=>tap('settings_back'));
  assert(evidence.uiWithEffectsZero.maxRms>0.000001,'Independent UI gain produced no actual UI output with SFX zero');
  evidence.checks.push('Actual master/music zero silence; UI click audible with SFX zero');
  await settings();await volume('ui',0);await volume('sfx',1);await volume('ambience',0);
  await tap('settings_back');await tap('start');await tap('deck_play');
  let s=await state();assert.equal(s.battle.stage,'mulligan');await tap('mulligan_done');
  s=await state();if(s.battle.stage==='origins'){
    const r=s.board.hero0;await page.mouse.click(r[0]+r[2]/2,r[1]+r[3]/2);await settle();
  }
  s=await state();if(s.battle.stage==='second')await tap('opening_done');
  s=await state();assert.equal(s.battle.stage,'battle');assert.equal(s.battle.hero.phase,'draw');
  evidence.effectsWithUiZero=await capture(()=>tap('end'));
  assert(evidence.effectsWithUiZero.maxRms>0.000001,'Real confirmed card draw had no SFX output with UI/music/ambience zero');
  evidence.checks.push('Actual confirmed production draw audible with UI/music/ambience zero');
  await tap('menu');assert.equal((await state()).audio.suspended,true);assert.equal((await state()).audio_paused,true);
  evidence.pausedOutput=await capture();assert(evidence.pausedOutput.maxRms<1e-7);
  await tap('modal_close');assert.equal((await state()).audio.suspended,false);
  await tap('menu');await tap('confirm_menu');await settings();
  await volume('music',.37);await volume('ui',.27);await volume('sfx',.61);
  await tap('audio_reduced');assert.equal((await state()).audio.settings.reduced_intensity,true);
  await tap('audio_mute');assert.equal((await state()).audio.settings.muted,true);
  evidence.checkboxMuted=await capture();assert(evidence.checkboxMuted.maxRms<1e-7);
  evidence.beforeReload=(await state()).audio.settings;
  await page.reload({waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.orafoldQA?.audio?.events===52,null,{timeout:90000});
  evidence.afterReload=(await state()).audio.settings;assert.deepEqual(evidence.afterReload,evidence.beforeReload);
  evidence.checks.push('Actual menu pause/resume, master checkbox and immediate reload preserve all gains/mute/reduced intensity');
  await settings();await tap('audio_mute');
  await page.waitForFunction(()=>window.__audioQAProbe().rms>0.000001,null,{timeout:10000});
  await tap('settings_back');await tap('start');await tap('deck_play');await tap('mulligan_done');
  s=await state();if(s.battle.stage==='origins')await tap('origin_0');
  s=await state();if(s.battle.stage==='second')await tap('opening_done');
  await page.waitForFunction(()=>window.__audioQAProbe().rms>0.000001,null,{timeout:10000});
  evidence.audibleBeforePause=await capture();
  await tap('menu');evidence.audibleMusicPaused=await capture();assert(evidence.audibleMusicPaused.maxRms<1e-7);
  await tap('modal_close');await page.waitForFunction(()=>window.__audioQAProbe().rms>0.000001,null,{timeout:10000});
  evidence.audibleAfterResume=await capture();
  await tap('menu');await tap('confirm_menu');await settings();
  evidence.checks.push('Actual audible battle music becomes zero during menu pause and resumes audibly');
  await page.evaluate(()=>{window.__audioOriginalSet=Storage.prototype.setItem;Storage.prototype.setItem=function(k,v){if(k.startsWith('orafold.audio.'))throw new DOMException('QA quota','QuotaExceededError');return window.__audioOriginalSet.call(this,k,v)}});
  await volume('ui',.31);assert.notEqual((await state()).audio.last_save_error,0);assert((await state()).audio_persistence_note.includes('nicht möglich'));
  await page.evaluate(()=>Storage.prototype.setItem=window.__audioOriginalSet);await volume('ui',.32);assert.equal((await state()).audio.last_save_error,0);
  evidence.checks.push('Real control storage denial visible and recovery succeeds');
  const mirror=await page.evaluate(()=>{const key=Object.keys(localStorage).find(k=>k.startsWith('orafold.audio.v1:'));return {key,value:localStorage.getItem(key)}});
  assert(mirror.key);const future=JSON.stringify({version:99,settings:{preserve:'future'}});
  await page.evaluate(({key,value})=>localStorage.setItem(key,value),{key:mirror.key,value:future});await load();await settings();await volume('ui',.33);
  assert.notEqual((await state()).audio.last_save_error,0);assert.equal(await page.evaluate(key=>localStorage.getItem(key),mirror.key),future);
  await page.evaluate(({key,value})=>localStorage.setItem(key,value),mirror);await load();await settings();
  evidence.checks.push('Unknown future mirror retained unchanged after actual control edit');
  await page.setViewportSize({width:390,height:844});await settle();await tap('settings_audio');
  s=await state();evidence.mobileTargets={};
  for(const key of ['master','music','sfx','ui','ambience']){const r=s.actions[`audio_${key}`].rect;assert(r[2]>=44&&r[3]>=44);evidence.mobileTargets[key]=r}
  for(const key of ['audio_mute','audio_reduced']){const r=s.actions[key].rect;assert(r[2]>=44&&r[3]>=44);evidence.mobileTargets[key]=r}
  await volume('ui',.28);assert.equal((await state()).audio.settings.ui,.28);
  await settle();await mkdir('work/audio/product-browser',{recursive:true});await page.screenshot({path:`work/audio/product-browser/${profile}-mobile.png`});
  evidence.checks.push('Mobile390x844 actual scroll/control editing and44px targets');
  evidence.final=(await state()).audio;assert.equal(evidence.errors.length,0,JSON.stringify(evidence.errors));evidence.result='passed';
} catch(error){evidence.result='failed';evidence.failure=error.stack||String(error);process.exitCode=1}
finally{if(browser)await Promise.race([browser.close(),new Promise(resolve=>setTimeout(resolve,10000))]);clearTimeout(deadline);await mkdir('work/audio/product-browser',{recursive:true});await writeFile(`work/audio/product-browser/${profile}.json`,JSON.stringify(evidence,null,2));console.log(JSON.stringify(evidence,null,2))}
