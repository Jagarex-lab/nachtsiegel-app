// Actual exported Alpha product, real canvas controls and mixed WebAudio output.
// NODE_PATH=<playwright> AUDIO_PRODUCT_URL=http://127.0.0.1:8766 AUDIO_QA_PROFILE=chromium|webkit node tests/audio/product_browser.mjs
import {createRequire} from 'node:module';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url);
const {chromium,webkit}=require('playwright');
const {freshPcmReady,silencePcmReady}=require('./pcm_readiness.cjs');
const {audioTargetVisible}=require('./product_geometry.cjs');
const profile=process.env.AUDIO_QA_PROFILE||'chromium';
const url=process.env.AUDIO_PRODUCT_URL||'http://127.0.0.1:8766';
const evidence={profile,url,scope:'Actual exported product in browser; no physical device or human listening claim.',checks:[],errors:[],graphicsDiagnostics:[]};
evidence.focus=process.env.AUDIO_QA_FOCUS||'full';
evidence.checks.push = function (...items) {console.error(items.join("; "));return Array.prototype.push.apply(this,items)};
evidence.harnessSha256=createHash('sha256').update(await readFile(new URL(import.meta.url))).digest('hex');
evidence.playwrightVersion=require('playwright/package.json').version;
evidence.nodeVersion=process.version;
let browser;
let page;
const deadline=setTimeout(()=>{console.error('Audio product browser deadline exceeded');process.exit(2)},600000);
try {
  browser=await (profile==='webkit'?webkit:chromium).launch(profile==='webkit'?{headless:true}:{headless:true,channel:'chromium',ignoreDefaultArgs:['--mute-audio'],args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader','--autoplay-policy=user-gesture-required']});
  evidence.browserVersion=browser.version();
  evidence.build=await (await fetch(`${url}/build-info.json`)).json();
  const context=await browser.newContext({viewport:{width:1100,height:800}});
  await context.addInitScript(() => {
    const contexts=[],meterMessages=[],meterErrors=[],routing=[];
    const records=new WeakMap();
    const connect=AudioNode.prototype.connect,disconnect=AudioNode.prototype.disconnect;
    const meterModule=URL.createObjectURL(new Blob([`
      class OrafoldQAMeter extends AudioWorkletProcessor {
        constructor(){super();this.generation=0;this.reset();this.port.onmessage=event=>{if(typeof event.data.reset==='number'){this.generation=event.data.reset;this.reset();}};}
        reset(){this.energy=0;this.samples=0;this.peak=0;this.maxRms=0;}
        process(inputs){
          let energy=0,n=0;
          for(const channel of inputs[0]||[])for(const value of channel){this.peak=Math.max(this.peak,Math.abs(value));energy+=value*value;n++;}
          this.energy+=energy;this.samples+=n;this.maxRms=Math.max(this.maxRms,n?Math.sqrt(energy/n):0);
          if(this.samples>=4096){this.port.postMessage({generation:this.generation,at:currentTime,peak:this.peak,rms:Math.sqrt(this.energy/this.samples),maxRms:this.maxRms});this.reset();}
          return true;
        }
      }
      registerProcessor('orafold-qa-meter',OrafoldQAMeter);
    `],{type:'text/javascript'}));
    function advance(record){
      record.generation++;record.epoch=record.ctx.currentTime;
      record.meter?.port.postMessage({reset:record.generation});
    }
    function observeContext(ctx){
      const record={ctx,sources:new Map(),generation:1,epoch:ctx.currentTime,meter:null};
      records.set(ctx,record);contexts.push(record);
      // All real destination sources feed this one parallel summing point.
      // The original audible edges remain untouched. Observation outputs zero.
      record.sum=ctx.createGain();record.sum.gain.value=1;
      record.sum.channelCount=ctx.destination.channelCount;
      record.sum.channelCountMode='explicit';
      record.analyser=ctx.createAnalyser();record.analyser.fftSize=2048;
      record.silent=ctx.createGain();record.silent.gain.value=0;
      connect.call(record.sum,record.analyser);connect.call(record.analyser,record.silent);
      connect.call(record.silent,ctx.destination);
      ctx.audioWorklet.addModule(meterModule).then(()=>{
        if(ctx.state==='closed')return;
        const meter=new AudioWorkletNode(ctx,'orafold-qa-meter');record.meter=meter;
        meter.port.onmessage=event=>{
          if(event.data.generation!==record.generation)return;
          meterMessages.push({context:contexts.indexOf(record),...event.data});
          if(meterMessages.length>512)meterMessages.splice(0,meterMessages.length-512);
        };
        connect.call(record.sum,meter);connect.call(meter,record.silent);
        meter.port.postMessage({reset:record.generation});
        routing.push({action:'summed_meter_attached',context:contexts.indexOf(record),at:performance.now()});
      }).catch(error=>meterErrors.push(String(error)));
    }
    for(const key of ['AudioContext','webkitAudioContext']){
      const Native=window[key];if(!Native)continue;
      window[key]=new Proxy(Native,{construct(target,args){const instance=Reflect.construct(target,args);observeContext(instance);return instance;}});
    }
    AudioNode.prototype.connect=function(...args){
      const result=connect.apply(this,args);
      if(args[0]===this.context.destination){
        const record=records.get(this.context),output=typeof args[1]==='number'?args[1]:0;
        if(record){
          let outputs=record.sources.get(this);
          if(!outputs){outputs=new Set();record.sources.set(this,outputs);}
          if(!outputs.has(output)){
            outputs.add(output);connect.call(this,record.sum,output);advance(record);
            routing.push({action:'real_destination_connected',source:this.constructor.name,output,generation:record.generation,at:performance.now()});
          }
        }
      }
      return result;
    };
    AudioNode.prototype.disconnect=function(...args){
      const result=disconnect.apply(this,args),record=records.get(this.context);
      if(record&&(args.length===0||typeof args[0]==='number'||args[0]===this.context.destination)){
        const outputs=record.sources.get(this);
        if(outputs){
          const selected=typeof args[0]==='number'?args[0]:typeof args[1]==='number'?args[1]:null;
          for(const output of [...outputs])if(selected===null||selected===output){
            try{disconnect.call(this,record.sum,output)}catch{}
            outputs.delete(output);
          }
          if(!outputs.size)record.sources.delete(this);
          advance(record);
          routing.push({action:'real_destination_disconnected_observer_detached',source:this.constructor.name,generation:record.generation,at:performance.now()});
        }
      }
      return result;
    };
    window.__audioQAProbe=()=>{
      let peak=0,energy=0,samples=0;
      for(const record of contexts){
        if(!record.sources.size||record.ctx.state!=='running')continue;
        const values=new Float32Array(record.analyser.fftSize);record.analyser.getFloatTimeDomainData(values);
        for(const value of values){peak=Math.max(peak,Math.abs(value));energy+=value*value;samples++;}
      }
      return {contexts:contexts.map(record=>({state:record.ctx.state,sample_rate:record.ctx.sampleRate,current_time:record.ctx.currentTime,generation:record.generation,epoch:record.epoch,destination_sources:record.sources.size})),
        routing:routing.slice(-32),meterErrors:meterErrors.slice(),meterMessages:meterMessages.slice(),peak,rms:samples?Math.sqrt(energy/samples):0};
    };
  });
  page=await context.newPage();
  page.on('pageerror',e=>evidence.errors.push(e.message));
  page.on('console',m=>{
    if(m.type()==='debug'&&m.text().startsWith('ORAFOLD_PCM_BASELINE ')){
      try{const report=JSON.parse(m.text().slice('ORAFOLD_PCM_BASELINE '.length));(evidence.silenceBaselineProgress||=[]).push(report);console.error('Actual PCM baseline '+JSON.stringify(report));}catch(error){evidence.errors.push('PCM baseline diagnostic failed: '+String(error));}
      return;
    }
    if(m.type()!=='error'||m.text().includes('favicon.ico'))return;
    if(m.text().includes('glBlitFramebuffer: Read and write color attachments cannot be the same image.'))evidence.graphicsDiagnostics.push(m.text());
    else evidence.errors.push(m.text());
  });
  const state=()=>page.evaluate(()=>window.orafoldQA);
  const settle=()=>page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>setTimeout(resolve,180)))));
  async function load(){await page.goto(`${url}/?qa=1`,{waitUntil:'domcontentloaded',timeout:45000});await page.waitForFunction(()=>window.orafoldQA?.audio?.events===52,null,{timeout:90000});await settle()}
  async function tap(key){
    console.error(`Actual tap ${key}`);
    let s=await state();assert(s.actions[key],`Missing actual action ${key}`);
    for(let attempt=0;attempt<12;attempt++){
      const r=s.actions[key].rect;const v=page.viewportSize();
      if(audioTargetVisible(s,key,v))break;
      const clip=s.action_visibility?.[key]?.clip_rect;
      if(!clip||r[1]>=clip[1]&&r[1]+r[3]<=clip[1]+clip[3])break;
      // This desktop test uses a real wheel only when the actual ancestor
      // clips vertically. Hover its scrollbar, not an editable gain slider.
      await page.mouse.move(Math.min(v.width-1,clip[0]+clip[2]-2),Math.max(1,Math.min(v.height-1,clip[1]+clip[3]/2)));
      await page.mouse.wheel(0,r[1]<clip[1]?-240:240);await settle();s=await state();
    }
    const r=s.actions[key].rect;
    (evidence.touchTargets||=[]).push({key,rect:r,visibility:s.action_visibility?.[key],disabled:s.actions[key].disabled,stage:s.battle?.stage,phase:s.battle?.hero?.phase});
    assert(audioTargetVisible(s,key,page.viewportSize()),`Clipped or smaller than44px ${key}: ${JSON.stringify(evidence.touchTargets.at(-1))}`);assert(!s.actions[key].disabled,`Disabled ${key}`);
    await page.mouse.click(r[0]+r[2]/2,r[1]+r[3]/2);await settle();
  }
  async function volume(channel,value){
    await tap(`audio_${channel}`);
    if(value===0||value===1)await page.keyboard.press(value===0?'Home':'End');
    else{
      const r=(await state()).actions[`audio_${channel}`].rect;
      await page.mouse.click(r[0]+r[2]*value,r[1]+r[3]/2);await settle();
      const current=(await state()).audio.settings[channel];
      const steps=Math.round((value-current)*100);
      for(let i=0;i<Math.abs(steps);i++)await page.keyboard.press(steps>0?'ArrowRight':'ArrowLeft');
    }
    await page.waitForFunction(({channel,value})=>Math.abs(window.orafoldQA.audio.settings[channel]-value)<.00001,{channel,value});await settle();
  }
  async function capture(action,duration=2500){
    if(action){
      const since=await page.evaluate(()=>window.__audioQAProbe().contexts.map(context=>context.current_time));
      await page.waitForFunction(silencePcmReady,{since,last:0},{timeout:10000});
    }
    const signal=page.evaluate(({ms,waitForClick})=>new Promise((resolve,reject)=>{
      function start(){
        const started=performance.now(),base=window.__audioQAProbe();let n=0;
        const cutoffs=base.contexts.map(context=>context.current_time+0.1);
        function tick(){
          const p=window.__audioQAProbe();n++;
          // Only fresh, current-generation summed audio-thread blocks prove sound.
          const meter=p.meterMessages.filter(message=>{
            const current=p.contexts[message.context];
            return current?.state==='running'&&current.destination_sources>0&&message.generation===current.generation&&message.at>Math.max(cutoffs[message.context],current.epoch+0.1);
          });
          const positive=meter.filter(message=>message.maxRms>0.000001);
          const peak=Math.max(0,...meter.map(message=>message.peak)),maxRms=Math.max(0,...meter.map(message=>message.maxRms));
          const positiveSpan=positive.length?positive.at(-1).at-positive[0].at:0;
          if(performance.now()-started>=ms){
            const windowMeta={requested_wall_ms:ms,started_performance_ms:started,finished_performance_ms:performance.now(),elapsed_wall_ms:performance.now()-started,contexts:p.contexts.map((current,index)=>{
              const observed=meter.filter(block=>block.context===index),baseContext=base.contexts[index];
              const targetEnd=baseContext?baseContext.current_time+ms/1000:null;
              return {context:index,base:baseContext,end:current,cutoff:cutoffs[index],target_audio_end:targetEnd,first_fresh_block:observed[0]?.at??null,last_fresh_block:observed.at(-1)?.at??null,fresh_blocks:observed.length,blocks_after_target_end:targetEnd===null?null:observed.filter(block=>block.at>targetEnd).length};
            })};
            resolve({peak,maxRms,positiveSpan,samples:n,meterBlocks:meter.length,nonzeroMeterBlocks:positive.length,meterErrors:p.meterErrors,routing:p.routing,contexts:p.contexts,window_meta:windowMeta,analyserDiagnostic:{peak:p.peak,rms:p.rms},audio:window.orafoldQA?.audio});
          }
          else setTimeout(tick,25);
        }tick();
      }
      if(waitForClick){
        // Start at the actual trusted button release, after tap() scrolls/moves.
        // Earlier cue tails cannot satisfy an action's measurement window.
        const timeout=setTimeout(()=>{window.removeEventListener('mouseup',onClick,true);reject(new Error('No trusted action release reached the PCM window'))},30000);
        function onClick(event){if(!event.isTrusted||event.button!==0)return;clearTimeout(timeout);window.removeEventListener('mouseup',onClick,true);start();}
        window.addEventListener('mouseup',onClick,true);
      }else start();
    }),{ms:duration,waitForClick:!!action});
    // Attach both handlers immediately: a rejected action or the unchanged
    // trusted-release deadline must reach the outer diagnostic/cleanup path,
    // even while the other branch is still pending.
    const [measurement]=await Promise.all([signal,Promise.resolve().then(()=>action?.())]);
    assert.equal(measurement.meterErrors.length,0,JSON.stringify(measurement.meterErrors));
    const graphSilent=measurement.contexts.every(context=>context.state!=='running'||context.destination_sources===0);
    assert(measurement.meterBlocks>0||graphSilent,'Missing fresh PCM measurement from an active destination graph');
    return measurement;
  }
  async function freshAudibleAfter(action,timeout,label){
    const snapshot=()=>page.evaluate(()=>window.__audioQAProbe().contexts.map(context=>({current_time:context.current_time,generation:context.generation,epoch:context.epoch})));
    const before=await snapshot();
    if(action)await action();
    // Retain the actual pre-action cutoff, but require audio after the action
    // has finished as well. Earlier opening/click tails cannot prove readiness.
    const cutoffs=await snapshot();
    for(let i=0;i<cutoffs.length;i++)if(before[i])cutoffs[i].current_time=Math.max(cutoffs[i].current_time,before[i].current_time);
    const handle=await page.waitForFunction(freshPcmReady,{before,cutoffs},{timeout});
    let result;try{result=await handle.jsonValue();}finally{await handle.dispose();}
    (evidence.freshPcmReadiness||=[]).push({label,timeout,before_action:result.before_action,cutoffs:result.cutoffs,quiescent_cutoffs:result.quiescent_cutoffs,observations:result.observations});
    return result.probe;
  }
  async function isolateOpeningMusicThroughMenu(){
    // Establish this measurement precondition through actual product controls.
    // Finite opening effects can outlive the model transition on a starved
    // software renderer; their PCM must not be misidentified as battle music.
    await page.waitForFunction(()=>{
      const q=window.orafoldQA;
      return q?.page==='battle'&&!q.modal&&q.battle?.stage==='battle'&&q.battle.active==='hero'&&q.actions?.end&&!q.actions.end.disabled;
    },null,{timeout:30000});
    const before=await state();
    await tap('menu');const paused=await state();
    assert(paused.audio_paused&&paused.audio.suspended,'Normal menu pauses the real mixer during opening-music setup');
    assert.deepEqual(paused.battle,before.battle,'Opening-music setup pauses only presentation, not the battle');
    assert.equal(paused.command_count,before.command_count,'Opening-music setup issues no battle command');
    const silence=await capture();assert(silence.maxRms<1e-7,'Opening-music setup must produce actual paused silence');
    await tap('modal_close');await page.mouse.move(1,1);
    const after=await state();
    assert(!after.audio_paused&&!after.audio.suspended,'Normal close resumes the mixer during opening-music setup');
    assert.deepEqual(after.battle,before.battle,'Opening-music setup preserves every observed battle field');
    assert.equal(after.command_count,before.command_count,'Opening-music setup leaves the command journal unchanged');
    assert.deepEqual(after.audio.settings,before.audio.settings,'Opening-music setup changes no gain, mute or intensity setting');
    (evidence.openingMusicIsolation||=[]).push({scope:'Actual menu pause/resume establishes isolated music; not a battle command or direct mixer mutation.',before_battle:before.battle,after_battle:after.battle,commands_before:before.command_count,commands_after:after.command_count,settings_before:before.audio.settings,settings_after:after.audio.settings,paused_pcm:silence,rng_scope:'This browser channel exposes full battle snapshots and command counts, not a separate RNG-state observer.'});
  }
  async function settings(){if((await state()).page!=='settings')await tap('settings');await tap('settings_audio')}
  await load();
  evidence.initial=(await state()).audio;
  assert.equal(evidence.initial.unlocked,false);assert.equal(evidence.initial.pool_size,16);assert.equal(evidence.initial.music.players,2);
  assert.equal(evidence.initial.cached_streams,153);
  evidence.checks.push('Packaged52events153effectassets and single bounded owner; locked before gesture');
  evidence.firstMixedSignal=await freshAudibleAfter(()=>tap('settings'),15000,'initial menu unlock');
  await page.waitForFunction(()=>window.orafoldQA.audio.unlocked);
  await page.waitForFunction(()=>window.orafoldQA.audio.music.playing>0&&!window.orafoldQA.audio.music.transitioning,null,{timeout:15000});
  evidence.afterGesture=(await state()).audio;
  evidence.audibleMenu=await capture();assert(evidence.audibleMenu.maxRms>0.000001);
  assert.equal(evidence.audibleMenu.meterErrors.length,0,JSON.stringify(evidence.audibleMenu.meterErrors));
  assert(evidence.audibleMenu.meterBlocks>0,"Independent audio-thread observer did not report real mixer blocks");
  assert.equal(evidence.audibleMenu.contexts.length,1,"Product must use one audio context");
  assert(evidence.audibleMenu.positiveSpan>=1,"Menu music did not span one second of fresh positive PCM blocks");
  if(process.env.AUDIO_QA_FOCUS==='resume'){
    await settings();await volume('sfx',0);await volume('ui',0);await volume('ambience',0);
    await freshAudibleAfter(async()=>{
      await tap('settings_back');await tap('start');await tap('deck_play');await tap('mulligan_done');
      let opening=await state();if(opening.battle.stage==='origins')await tap('origin_0');
      opening=await state();if(opening.battle.stage==='second')await tap('opening_done');
    },15000,'focused duel opening');
    evidence.duelBeforePause=(await state()).audio;
    evidence.audibleBeforePause=await capture();assert(evidence.audibleBeforePause.maxRms>0.000001);
    for(let repeat=0;repeat<2;repeat++){
      await tap('menu');const paused=await capture();evidence[`paused${repeat}`]=paused;assert(paused.maxRms<1e-7);assert.equal((await state()).audio.suspended,true);
      await freshAudibleAfter(async()=>{await tap('modal_close');evidence.resumeState=(await state()).audio;},15000,'focused duel resume '+repeat);
      evidence[`audibleResume${repeat}`]=await capture();assert(evidence[`audibleResume${repeat}`].maxRms>0.000001);assert(evidence[`audibleResume${repeat}`].positiveSpan>=1,"Resumed music did not persist across fresh PCM blocks for one second");
    }
    evidence.checks.push('Two actual audible duel pause/resume cycles restore stream transport');
    evidence.final=(await state()).audio;assert.equal(evidence.errors.length,0,JSON.stringify(evidence.errors));evidence.result='passed';
  }else{
  await settings();
  await volume('master',0);evidence.masterZero=await capture();assert(evidence.masterZero.maxRms<1e-7,'Master zero did not silence actual output');
  await freshAudibleAfter(()=>volume('master',1),10000,'master restored');
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
  await settings();await freshAudibleAfter(()=>tap('audio_mute'),10000,'mute disabled after reload');
  await freshAudibleAfter(async()=>{
    await tap('settings_back');await tap('start');await tap('deck_play');await tap('mulligan_done');
    s=await state();if(s.battle.stage==='origins')await tap('origin_0');
    s=await state();if(s.battle.stage==='second')await tap('opening_done');
    await isolateOpeningMusicThroughMenu();
  },10000,'duel opening after reload');
  evidence.audibleBeforePause=await capture();
  await tap('menu');evidence.audibleMusicPaused=await capture();assert(evidence.audibleMusicPaused.maxRms<1e-7);
  await freshAudibleAfter(async()=>{await tap('modal_close');evidence.resumeState=(await state()).audio;},10000,'audible duel resumed');
  evidence.audibleAfterResume=await capture();assert(evidence.audibleAfterResume.positiveSpan>=1,"Resumed music did not persist across fresh PCM blocks for one second");
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
  evidence.checks.push('Responsive390x844 viewport: actual scroll/control editing and44px targets');
  evidence.final=(await state()).audio;assert.equal(evidence.errors.length,0,JSON.stringify(evidence.errors));evidence.result='passed';
  }
 } catch(error){
  evidence.result='failed';evidence.failure=error.stack||String(error);process.exitCode=1;
  if(page)try{evidence.failureState=await Promise.race([
    page.evaluate(()=>({page:window.orafoldQA?.page,modal:window.orafoldQA?.modal,audio_paused:window.orafoldQA?.audio_paused,stage:window.orafoldQA?.battle?.stage,audio:window.orafoldQA?.audio,visibility:document.visibilityState,probe:window.__audioQAProbe?.()})),
    new Promise(resolve=>setTimeout(()=>resolve('unavailable after timeout'),3000))
  ])}catch(diagnostic){evidence.failureState=String(diagnostic)}
}finally{
  evidence.finishedAt=new Date().toISOString();
  await mkdir('work/audio/product-browser',{recursive:true});
  const suffix=process.env.AUDIO_QA_FOCUS?'-'+process.env.AUDIO_QA_FOCUS:'';
  const encoded=JSON.stringify(evidence,null,2);
  await writeFile(`work/audio/product-browser/${profile}${suffix}.json`,encoded);
  await writeFile(`work/audio/product-browser/${profile}${suffix}-${evidence.finishedAt.replaceAll(/[^0-9]/g,'')}.json`,encoded);
  console.log(encoded);
  if(browser)await Promise.race([browser.close(),new Promise(resolve=>setTimeout(resolve,10000))]);
  clearTimeout(deadline);
}
