'use strict';
// Runs the exported game through real canvas taps and read-only QA reports.
// No model injection, forced winners, DOM gameplay callbacks or fake assets.
const {chromium,webkit,devices}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {performance}=require('node:perf_hooks');
const {encloses,clearTouchPoint,scrollGesture,battleGeometry,artReady,fullArtReady,premiumArt,playability}=require('./browser_contract.cjs');
const output=path.resolve(process.env.PREMIUM_BROWSER_OUTPUT||'work/premium-mobile/browser');
const expectedCommit=process.env.EXPECTED_COMMIT;
assert(/^[0-9a-f]{40}$/.test(expectedCommit||''),'EXPECTED_COMMIT must name the exact exported candidate');
const gameURL=new URL(process.env.GAME_URL||'http://127.0.0.1:8893/');gameURL.searchParams.set('qa','1');
const variants=[{width:844,height:390},{width:852,height:393},{width:932,height:430},{width:1024,height:768},{width:1600,height:900}];
const catalog=JSON.parse(fs.readFileSync('data/production/cards.json','utf8')).cards;
const by=Object.fromEntries(catalog.map(card=>[card.id,card]));
const geometry=Object.fromEntries(Object.entries(JSON.parse(fs.readFileSync('data/production/art_preview_delivery.json','utf8')).entries).map(([id,entry])=>[id,[entry.width,entry.height]]));
const fullGeometry=Object.fromEntries(Object.entries(JSON.parse(fs.readFileSync('data/production/art_delivery.json','utf8')).entries).map(([id,entry])=>[id,[entry.width,entry.height]]));
const hash=value=>crypto.createHash('sha256').update(value).digest('hex');
const results=[];
fs.mkdirSync(output,{recursive:true});
assert.equal(catalog.length,550,'the actual active catalog has550 cards');
assert.equal(Object.keys(by).length,550,'the actual active IDs are unique');
assert.equal(Object.keys(geometry).length,550,'all active illustrations have compact delivery entries');

(async()=>{
 for(const engine of (process.env.QA_ENGINES||'chromium,webkit').split(',')){
  assert(['chromium','webkit'].includes(engine),'known browser engine');
  const browser=await (engine==='webkit'?webkit:chromium).launch({headless:true,...(engine==='chromium'?{channel:'chromium',args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']}: {})});
  const report={engine,browser_version:browser.version(),playwright:require('playwright/package.json').version,source_commit:expectedCommit,physical_device:false,checks:[],screenshots:[],viewports:[],touch_samples:[],errors:[],status:'running',performance_scope:'Linux browser and software-rendered Godot on the available host. Startup/touch samples include test polling and host scheduling; JS heap is not total WebAssembly/GPU/device memory.'};
  let context,page,cdp,lastAction='boot',heartbeat,heartbeatBusy=false;
  const check=(value,label)=>{assert(value,label);report.checks.push(label);};
  const save=()=>fs.writeFileSync(path.join(output,engine+'-results.json'),JSON.stringify(report,null,2));
  try{
   const deviceName=engine==='chromium'?'Pixel 7':'iPhone 13';
   const {screen,...phone}=devices[deviceName];report.emulated_device=deviceName;
   context=await browser.newContext({...phone,viewport:{width:390,height:844},deviceScaleFactor:1});
   page=await context.newPage();page.setDefaultTimeout(90000);
   if(engine==='chromium'){cdp=await context.newCDPSession(page);await cdp.send('Performance.enable');}
   page.on('pageerror',error=>report.errors.push(String(error)));
   page.on('console',message=>{if(message.type()==='error')report.errors.push(message.text());});
   const q=()=>page.evaluate(()=>window.orafoldQA);
   const wait=fn=>page.waitForFunction(fn,undefined,{timeout:90000});
   heartbeat=setInterval(async()=>{
    if(heartbeatBusy)return;heartbeatBusy=true;
    try{
     const current=await page.evaluate(()=>{const s=window.orafoldQA;return s?{page:s.page,modal:s.modal,render_version:s.render_version,command_count:s.command_count,selected:s.selected,battle_stage:s.battle?.stage,phase:s.battle?.hero?.phase,hand_size:s.hand?.length,inspection:s.inspection?.art,art_delivery:s.art_delivery}:null;});
     fs.writeFileSync(path.join(output,engine+'-progress.json'),JSON.stringify({last_action:lastAction,checks:report.checks.length,screenshots:report.screenshots.length,viewports:report.viewports.length,current},null,2));
    }catch{}finally{heartbeatBusy=false;}
   },5000);heartbeat.unref();
   const deadline=(promise,label,ms)=>{let timer;return Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error(label)),ms);})]).finally(()=>clearTimeout(timer));};
   async function tapRect(rect,label,occluders=[]){
    const point=clearTouchPoint(rect,occluders);check(point,label+' exposes a44CSS touch region');
    check(encloses([0,0,page.viewportSize().width,page.viewportSize().height],rect),label+' stays inside viewport');
    await page.touchscreen.tap(point[0],point[1]);
   }
   async function action(id){
    lastAction=id;
    if(['log','restart','convergence'].includes(id)&&!(await q()).actions[id])await action('actions');
    await page.waitForFunction(id=>{const a=window.orafoldQA?.actions?.[id];return a&&!a.disabled;},id);
    for(let tries=0;tries<20;tries++){
     const current=await q(),a=current.actions[id],v=current.action_visibility?.[id];
     const clip=v?.clip_rect||[0,0,page.viewportSize().width,page.viewportSize().height];
     const hit=id.startsWith('card_')&&v?v.visible_rect:a.rect;
     if(encloses(clip,hit)&&encloses([0,0,page.viewportSize().width,page.viewportSize().height],hit)&&hit[2]>=43.9&&hit[3]>=43.9)break;
     const gesture=scrollGesture(current,id);
     if(cdp){
      await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...gesture.from,id:0,radiusX:2,radiusY:2,force:1}]});
      for(let step=1;step<=6;step++){await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:gesture.from.x,y:gesture.from.y+(gesture.to.y-gesture.from.y)*step/6,id:0,radiusX:2,radiusY:2,force:1}]});await page.waitForTimeout(35);}
      await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
     }else{
      // Mobile WebKit exposes tap but no wheel or protocol touchMove. Trusted
      // browser pointer pan reaches Godot's configured touch emulation. It is
      // real canvas input, never DOM scrolling or a ScrollContainer mutation.
      await page.mouse.move(gesture.from.x,gesture.from.y);await page.mouse.down();
      for(let step=1;step<=6;step++){await page.mouse.move(gesture.from.x,gesture.from.y+(gesture.to.y-gesture.from.y)*step/6);await page.waitForTimeout(35);}
      await page.mouse.up();
     }
     (report.scroll_gestures||=[]).push({action:id,driver:cdp?'CDP primary touch':'trusted browser pointer with Godot touch emulation',...gesture});
     await page.waitForTimeout(180);
     check(tries<19,id+' becomes reachable through real scroll input');
    }
    // Compare three newly published observations; geometry movement must settle
    // before touching a canvas control after rotation, scrolling or animation.
    const ready=await page.waitForFunction(sample=>{
     const current=window.orafoldQA;if(!current||current===sample.previous)return false;sample.previous=current;
     const a=current.actions[sample.id],v=current.action_visibility?.[sample.id];
     if(!a||a.disabled){sample.count=0;return false;}
     const r=sample.id.startsWith('card_')&&v?v.visible_rect:a.rect;
     sample.count=sample.last&&r.every((n,i)=>Math.abs(n-sample.last[i])<1)?sample.count+1:1;sample.last=[...r];
     return sample.count>=3?{rect:r,render:current.render_version,modal:current.modal_version}:false;
    },{id,previous:null,last:null,count:0});
    let settled;try{settled=await ready.jsonValue();}finally{await ready.dispose();}
    const before=performance.now();await tapRect(settled.rect,id);
    await page.waitForFunction(s=>{const c=window.orafoldQA;return c&&(c.render_version>s.render||c.modal_version!==s.modal);},settled);
    report.touch_samples.push({action:id,elapsed_ms:Math.round(performance.now()-before),meaning:'real touch to next published UI/model frame; includes host/test overhead'});
   }
   async function shot(label){
    lastAction='screenshot:'+label;
    await deadline(page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))),'Screenshot paint did not settle within15s',15000);
    await page.waitForTimeout(180);
    let bytes;
    if(cdp){const v=page.viewportSize();const capture=await deadline(cdp.send('Page.captureScreenshot',{format:'png',fromSurface:true,clip:{x:0,y:0,width:v.width,height:v.height,scale:1}}),'Screenshot readback did not finish within30s',30000);bytes=Buffer.from(capture.data,'base64');}
    else bytes=await page.screenshot({timeout:30000});
    const file=engine+'-'+label+'.png';fs.writeFileSync(path.join(output,file),bytes);
    check(bytes.readUInt32BE(16)===page.viewportSize().width&&bytes.readUInt32BE(20)===page.viewportSize().height,'screenshot contains native1x viewport '+label);
    check(bytes.length>20000,'screenshot contains rendered content '+label);
    report.screenshots.push({file,sha256:hash(bytes),bytes:bytes.length,viewport:page.viewportSize()});save();
   }
   async function allArt(){
    const before=await q();
    await page.waitForFunction(expected=>{
     const cards=(window.orafoldQA?.battle_art||[]).filter(row=>row.card_id&&row.visible&&['hand','board'].includes(row.zone));
     return cards.length>0&&cards.every(row=>expected[row.card_id]&&row.profile==='compact'&&row.status==='final'&&!row.pending&&row.pixels[0]===expected[row.card_id][0]&&row.pixels[1]===expected[row.card_id][1]);
    },geometry);
    const current=await q();check(artReady(current,geometry),'every visible card owns its final compact illustration');
    assert.deepEqual(current.battle,before.battle,'art delivery is read-only');check(current.command_count===before.command_count,'art delivery issues no command');
   }
   async function inspectorArt(){
    await page.waitForFunction(expected=>{
     const inspection=window.orafoldQA?.inspection,art=inspection?.art,size=expected[inspection?.id];
     return Boolean(size&&art?.state==='ready'&&art.status==='final'&&art.profile==='full'&&art.visible===true&&art.draw_count>0&&art.card_id===inspection.id&&art.requested_card_id===inspection.id&&art.preview_only===false&&art.pixels?.[0]===size[0]&&art.pixels?.[1]===size[1]);
    },fullGeometry);
    check(fullArtReady(await q(),fullGeometry),'inspector owns its actual full-resolution final illustration');
   }
   async function resize(size){
    const current=page.viewportSize();if(current.width===size.width&&current.height===size.height)return q();
    const old=await q();await page.setViewportSize(size);
    await page.waitForFunction(({size,version})=>{const s=window.orafoldQA,m=window.orafoldDisplayMetrics?.();return s?.render_version>version&&m&&Math.abs(m.cssWidth-size.width)<1&&Math.abs(m.cssHeight-size.height)<1;},{size,version:old.render_version});
    await page.waitForTimeout(250);return q();
   }
   const startup=performance.now();
   const infoResponse=await page.request.get(new URL('build-info.json',gameURL).href);check(infoResponse.ok(),'build-info is reachable');
   const info=await infoResponse.json();assert.equal(info.commit,expectedCommit,'tested source is the exact candidate');report.build_info=info;
   await page.goto(gameURL.href,{waitUntil:'domcontentloaded'});await wait(()=>window.orafoldQA?.page==='lobby');
   report.startup_to_menu_ms=Math.round(performance.now()-startup);
   for(const id of ['start','campaign','builder','collection','economy','online','settings'])check(Boolean((await q()).actions[id]),'functional main-menu route '+id);
   await shot('menu-portrait');
   await action('collection');await wait(()=>window.orafoldQA?.library_total===550);
   check((await q()).library_total===550,'all550 active cards are available in the actual collection');
   const first=Object.keys((await q()).actions).find(id=>id.startsWith('card_'));
   check(first&&by[first.slice(5)],'the collection exposes actual production card IDs');await action(first);
   const detail=await q();check(detail.inspection?.title===by[first.slice(5)].name,'the inspector displays the complete actual name');
   await inspectorArt();await shot('collection-inspection-portrait');await action('modal_close');await action('builder_back');
   await action('builder');check((await q()).deck_size===30,'builder loads an existing valid30-card deck');await shot('deckbuilder-portrait');
   await action('save_deck');await wait(()=>window.orafoldQA.message.includes('gespeichert'));await action('builder_back');
   await action('start');await wait(()=>window.orafoldQA.page==='decks');
   for(const power of ['houses','stillwatch','morph','ninth'])check(Boolean((await q()).actions['choose_'+power]),'starter '+power+' is visible in deck selection');
   await shot('starters-portrait');await action('choose_houses');await action('deck_play');
   await wait(()=>window.orafoldQA.page==='battle'&&window.orafoldQA.actions.rotate_menu);
   const opening=await q();check(opening.battle.stage==='mulligan','the real opening starts on the battlefield');
   for(let turn=0;turn<3;turn++){
    let current=await resize({width:844,height:390});await wait(()=>window.orafoldQA.actions.mulligan_done&&!window.orafoldQA.actions.rotate_menu);
    assert.deepEqual(current.battle,opening.battle,'portrait to landscape preserves complete opening state');check(current.command_count===opening.command_count,'rotation executes no command');
    current=await resize({width:390,height:844});await wait(()=>window.orafoldQA.actions.rotate_menu);assert.deepEqual(current.battle,opening.battle,'landscape to portrait preserves complete opening state');
   }
   await resize(variants[0]);await wait(()=>window.orafoldQA.actions.mulligan_done);await allArt();await shot('mulligan-844x390');
   await action('mulligan_done');await action('origin_2');await wait(()=>window.orafoldQA.battle.stage!=='origins');
   if((await q()).battle.stage==='second')await action('opening_done');
   await wait(()=>window.orafoldQA.battle.stage==='battle'&&window.orafoldQA.battle.active==='hero');
   // Obtain six cards using only original draw/turn commands. A forced model
   // fixture must never be counted as a browser gameplay or draw-limit pass.
   for(let turn=0;(await q()).battle.hero.hand.length<6&&turn<4;turn++){
    const current=await q();check(!current.battle.winner,'real six-card setup remains a live duel');
    await action('end');await wait(()=>window.orafoldQA.battle.active==='hero'||window.orafoldQA.battle.winner);
   }
   if((await q()).battle.hero.phase==='draw')await action('end');
   const stableBattle=await q();check(stableBattle.battle.hero.hand.length===6,'six actual cards obtained without state injection');
   for(const size of variants){
    const current=await resize(size);await allArt();
    assert.deepEqual((await q()).battle,stableBattle.battle,'responsive relayout preserves entire battle at '+size.width+'x'+size.height);
    const bounds=[0,0,size.width,size.height],layout=battleGeometry(await q(),bounds,{requireSix:true}),art=premiumArt(await q(),bounds),availability=playability(await q());
    report.viewports.push({size,layout,art,availability,physical_device:false});
    await shot('battle-'+size.width+'x'+size.height);
    const hand=(await q()).hand[0];await tapRect(hand.rect,'hand0');await wait(()=>window.orafoldQA.selected===0);
    await action('inspect');await inspectorArt();
    const inspected=await q();check(inspected.inspection?.title===by[hand.id].name,'full hand-card name is readable at '+size.width);
    check(Boolean(inspected.inspection.rules),'full actual ability text is present at '+size.width);await shot('inspection-'+size.width+'x'+size.height);await action('modal_close');
    if((await q()).actions.cancel_selection)await action('cancel_selection');
   }
   await resize(variants[0]);
   const beforeLog=await q();await action('log');check((await q()).modal&&(await q()).actions.verify_replay,'combat log/replay lives in reachable secondary sheet');await action('modal_close');assert.deepEqual((await q()).battle,beforeLog.battle,'secondary sheet changes no rule state');
   // Reload must release the portrait guard and offer a verified active journal
   // rather than silently starting a different duel or trusting raw saved HP.
   const beforeReload=await q();await page.reload({waitUntil:'domcontentloaded'});await wait(()=>window.orafoldQA?.page==='lobby');
   check(!(await q()).actions.rotate_menu,'landscape reload has no stuck rotate overlay');
   check(Boolean((await q()).actions.resume_duel),'an interrupted real duel has a visible resume action');await action('resume_duel');await wait(()=>window.orafoldQA.page==='battle');
   assert.deepEqual((await q()).battle,beforeReload.battle,'verified resume reconstructs complete exact model state');check((await q()).command_count===beforeReload.command_count,'verified resume retains exact accepted command count');await shot('resumed-battle');
   await action('menu');await action('confirm_menu');await action('settings');
   await wait(()=>Boolean(window.orafoldApp?.state));const app=await page.evaluate(()=>window.orafoldApp.state());
   check(typeof app.standalone==='boolean'&&typeof app.fullscreenSupported==='boolean','real Web-App capability API is present');
   check(Boolean((await q()).actions.app_fullscreen)&&Boolean((await q()).actions.app_install),'fullscreen/install controls are reachable');
   await action('app_fullscreen');
   if(app.fullscreenSupported&&!app.ios){
    await page.waitForFunction(()=>window.orafoldApp.state().fullscreen);
    check((await page.evaluate(()=>window.orafoldApp.state())).fullscreen,'actual browser enters fullscreen from the touch gesture');
    await action('app_fullscreen');await page.waitForFunction(()=>!window.orafoldApp.state().fullscreen);
    check(!(await page.evaluate(()=>window.orafoldApp.state())).fullscreen,'actual browser exits fullscreen through the same control');
   }else{
    check((await q()).modal,'unsupported/iOS fullscreen gives a reachable explanation');await action('modal_close');
   }
   await action('app_install');check((await q()).modal,'install help opens through a real touch');await shot('install-help');await action('modal_close');
   report.web_app=await page.evaluate(()=>window.orafoldApp.state());
   const resource=await page.evaluate(()=>({canvas:[document.querySelector('canvas').width,document.querySelector('canvas').height],dpr:devicePixelRatio,heap:performance.memory?{usedJSHeapSize:performance.memory.usedJSHeapSize,totalJSHeapSize:performance.memory.totalJSHeapSize}:null,resources:performance.getEntriesByType('resource').map(r=>({name:new URL(r.name).pathname,transferSize:r.transferSize,encodedBodySize:r.encodedBodySize,duration_ms:Math.round(r.duration)}))}));report.runtime_samples=resource;
   if(cdp)report.chromium_performance=(await cdp.send('Performance.getMetrics')).metrics.filter(m=>['JSHeapUsedSize','JSHeapTotalSize','TaskDuration','ScriptDuration','LayoutDuration','Nodes'].includes(m.name));
   check(report.errors.length===0,'no browser/Godot errors: '+report.errors.join('\n'));report.status='passed';save();
  }catch(error){
   report.status='failed';report.last_action=lastAction;report.error=String(error);
   if(page){report.last_qa=await page.evaluate(()=>window.orafoldQA).catch(()=>null);await page.screenshot({path:path.join(output,engine+'-FAILED.png'),timeout:15000}).catch(()=>{});}save();throw error;
  }finally{clearInterval(heartbeat);results.push(report);if(context)await context.close();await browser.close();fs.writeFileSync(path.join(output,'results.json'),JSON.stringify(results,null,2));}
 }
 assert(results.length>0,'at least one actual browser profile executes');
 console.log('PREMIUM BROWSER:',results.map(r=>`${r.engine}: ${r.checks.length} checks / ${r.viewports.length} landscape sizes / ${r.status}`).join('; '));
 console.log('Full AI duels and replay/restart are covered separately by tools/alpha_browser_qa.cjs; this runner does not count arranged presentation fixtures as gameplay.');
})().catch(error=>{console.error(error);process.exitCode=1;});
