'use strict';
// Reproducible actual UI journey. No product code, model or storage is mutated by
// JavaScript. Only trusted browser pointer/touch input and normal reload/rotate.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {chromium, webkit, devices} = require('playwright');
const {nativeCapture} = require('./native_capture_contract.cjs');
const {scrollGesture} = require('./browser_contract.cjs');
const root = path.resolve(__dirname, '../..');
const output = path.join(path.resolve(process.env.PREMIUM_BROWSER_OUTPUT || path.join(root, 'work/premium-browser')), 'hosted');
const url = new URL(process.env.GAME_URL || 'http://127.0.0.1:8893/'); url.searchParams.set('qa','1');
const expected = process.env.EXPECTED_COMMIT;
assert(/^[a-f0-9]{40}$/.test(expected || ''), 'Explicit exact exported commit required');
const catalog = JSON.parse(fs.readFileSync(path.join(root,'data/production/cards.json'))).cards;
const cards = new Map(catalog.map(card => [card.id,card]));
const previewSizes = Object.fromEntries(Object.entries(JSON.parse(fs.readFileSync(path.join(root,'data/production/art_preview_delivery.json'))).entries).map(([id,entry])=>[id,[entry.width,entry.height]]));
assert.equal(cards.size,550);
const canonical = value => Array.isArray(value) ? '['+value.map(canonical).join(',')+']' : value && typeof value === 'object' ? '{'+Object.keys(value).sort().map(key => JSON.stringify(key)+':'+canonical(value[key])).join(',')+'}' : JSON.stringify(value);
const hash = value => crypto.createHash('sha256').update(typeof value === 'string' || Buffer.isBuffer(value) ? value : canonical(value)).digest('hex');
const inside = (r,v) => Array.isArray(r) && r.length===4 && r.every(Number.isFinite) && r[2]>=43.9 && r[3]>=43.9 && r[0]>=-.1 && r[1]>=-.1 && r[0]+r[2]<=v.width+.1 && r[1]+r[3]<=v.height+.1;
function pick(q, selector) {
  if(selector.kind==='shell')return q.actions?.[selector.id];
  return q.hosted_actions?.find(a => (selector.id ? a.id===selector.id : selector.exact ? a.text===selector.text : a.text?.includes(selector.text)));
}
fs.mkdirSync(output,{recursive:true});
(async()=>{
for(const engine of (process.env.QA_ENGINES || 'chromium,webkit').split(',')){
  const report={engine,source_commit:expected,scope:'Actual product UI, public read-only QA/local save observation. No physical device, full campaign/game completion or production deployment claim.',checks:[],actions:[],pans:[],screenshots:[],native_captures:[],errors:[],status:'running',catalog_sha256:hash(fs.readFileSync(path.join(root,'data/production/cards.json'),'utf8')),driver_sha256:hash(fs.readFileSync(__filename,'utf8')),source_files:Object.fromEntries(['scripts/alpha/shell.gd','scripts/economy/alpha550_panel.gd','scripts/economy/alpha550_economy.gd','scripts/campaign_orafold/presentation.gd','scripts/campaign_orafold/battle_adapter.gd','data/campaign_orafold/prototype.json'].map(file=>[file,hash(fs.readFileSync(path.join(root,file)))])),limits:['Hosted-page QA does not expose ancestor clip rectangles; exact viewport geometry plus actual action outcomes are checked, without claiming unavailable clip measurements.','Campaign reload is tested against its documented safe encounter checkpoint; it does not promise full mid-turn journal resume.']};
  let browser,context,page,cdp,stage='boot';
  const save=()=>fs.writeFileSync(path.join(output,engine+'-results.json'),JSON.stringify(report,null,2));
  const deadline=setTimeout(async()=>{report.status='failed';report.failure='Explicit12-minute journey deadline';report.last_stage=stage;save();console.error(report.failure);process.exitCode=2;await browser?.close().catch(()=>{});},720000);
  const check=(condition,label)=>{assert(condition,label);report.checks.push(label);};
  try{
    browser=await (engine==='webkit'?webkit:chromium).launch({headless:true,...(engine==='chromium'?{channel:'chromium',args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']}: {})});
    report.browser_version=browser.version();report.playwright=require('playwright/package.json').version;
    const {screen,...phone}=devices[engine==='webkit'?'iPhone 13':'Pixel 7'];
    context=await browser.newContext({...phone,viewport:{width:390,height:844},deviceScaleFactor:2});
    page=await context.newPage();page.setDefaultTimeout(60000);
    if(engine==='chromium')cdp=await context.newCDPSession(page);
    page.on('pageerror',e=>report.errors.push(String(e)));
    page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text());});
    const q=()=>page.evaluate(()=>window.orafoldQA);
    const observe=()=>page.evaluate(()=>({q:window.orafoldQA,campaign:window.orafoldCampaignQA,campaign_store:(()=>{const raw=localStorage.getItem('orafold.campaign.v2');return raw?JSON.parse(raw):null;})(),economies:Object.keys(localStorage).filter(k=>k.startsWith('orafold.economy.sandbox.')).map(key=>{const raw=localStorage.getItem(key);return {key,raw,envelope:JSON.parse(raw)};})}));
    const fresh=async()=>{const h=await page.waitForFunction(sample=>{const q=window.orafoldQA;if(!q||q===sample.last)return false;sample.last=q;return ++sample.n>=2;},{last:null,n:0},{timeout:10000});await h.dispose();};
    const wait=async(fn,arg)=>{const h=await page.waitForFunction(fn,arg,{timeout:60000});await h.dispose();};
    const stateContext=q=>({page:q.page,modal:q.modal,modal_version:q.modal_version,inspection:q.inspection?.id});
    async function held(selector,before){
      const h=await page.waitForFunction(sample=>{
        const q=window.orafoldQA;if(!q||q===sample.previous)return false;sample.previous=q;
        if(q.page!==sample.page||q.modal!==sample.modal||q.modal_version!==sample.modal_version)throw Error('Pan changed actual feature context');
        const s=sample.selector,a=s.kind==='shell'?q.actions?.[s.id]:q.hosted_actions?.find(a=>s.id?a.id===s.id:s.exact?a.text===s.text:a.text?.includes(s.text));
        if(!a)return false;const r=a.rect,now=performance.now();
        if(!sample.last||r.some((v,i)=>Math.abs(v-sample.last[i])>.25)){sample.n=0;sample.since=now;}
        sample.n++;sample.last=r.slice();return sample.n>=4&&now-sample.since>=250?{rect:r,fresh:sample.n,quiet_ms:now-sample.since}:false;
      },{selector,...stateContext(before),previous:null,last:null,n:0,since:0},{timeout:10000});
      try{return await h.jsonValue();}finally{await h.dispose();}
    }
    async function pan(selector,before,delta){
      const v=page.viewportSize();const buttons=before.hosted_page?before.hosted_actions:Object.values(before.actions);
      const campaign=before.hosted_page==='campaign';
      const nav=['Kapitelübersicht','Rückblick','Charaktere','Leseeinstellungen','Hauptmenü'];
      const headerBottom=campaign?Math.max(0,...buttons.filter(a=>nav.includes(a.text)).map(a=>a.rect[1]+a.rect[3])):0;
      const low=campaign?headerBottom+18:12,high=v.height-(campaign?64:24);
      // Find actual exposed gaps using the published button edges. A single
      // hardcoded Y was covered by a tall campaign hand button in attempt1.
      const ys=[high,low,(low+high)/2,...buttons.flatMap(a=>[a.rect[1]-3,a.rect[1]+a.rect[3]+3])].filter(y=>y>=low&&y<=high).sort((a,b)=>delta<0?b-a:a-b);
      let from;
      for(const y of ys){for(const x of [v.width-24,v.width-30,v.width-38,v.width*.75,v.width*.5,v.width*.25]){
        if(!buttons.some(a=>x>=a.rect[0]&&x<=a.rect[0]+a.rect[2]&&y>=a.rect[1]&&y<=a.rect[1]+a.rect[3])){from={x,y};break;}
      }if(from)break;}
      let to;
      if(selector.kind==='shell') { const gesture=scrollGesture(before,selector.id);from=gesture.from;to=gesture.to; }
      assert(from,'A real nonbutton scroll surface exists');
      const distance=Math.min(160,Math.abs(delta),delta<0?from.y-90:v.height-24-from.y);assert(distance>10);
      to ||= {x:from.x,y:from.y+Math.sign(delta)*distance};let quiet;
      if(cdp){await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...from,id:0,radiusX:2,radiusY:2,force:1}]});try{await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{...to,id:0,radiusX:2,radiusY:2,force:1}]});quiet=await held(selector,before);}finally{await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}}
      else{await page.mouse.move(from.x,from.y);await page.mouse.down();try{await page.mouse.move(to.x,to.y);quiet=await held(selector,before);}finally{await page.mouse.up();}}
      await fresh();const after=await q();assert.deepEqual(stateContext(after),stateContext(before));report.pans.push({selector,from,to,quiet,driver:cdp?'trusted primary CDP touch':'trusted pointer through configured Godot touch emulation'});report.last_stage=stage;save();
    }
    async function reveal(selector,band=null){
      for(let i=0;i<24;i++){
        const before=await q(),a=pick(before,selector);assert(a,'Actual action exists '+JSON.stringify(selector));assert(!a.disabled,'Actual action enabled '+JSON.stringify(selector));
        const r=a.rect,v=page.viewportSize();const good=inside(r,v)&&(band===null||r[1]>=band[0]&&r[1]<=band[1]);if(good)return a;
        let delta=r[1]<0?Math.min(160,-r[1]+24):-Math.min(160,Math.max(12,r[1]+r[3]-v.height+24));
        if(band&&r[1]>=0&&r[1]+r[3]<=v.height)delta=r[1]<band[0]?Math.min(160,band[0]-r[1]+12):-Math.min(160,r[1]-band[1]+12);
        await pan(selector,before,delta);
      }throw Error('Target did not become actually visible '+JSON.stringify(selector));
    }
    async function tap(selector){
      stage='tap:'+JSON.stringify(selector);report.last_stage=stage;save();console.error(stage);
      await wait(s=>{const q=window.orafoldQA,a=s.kind==='shell'?q?.actions?.[s.id]:q?.hosted_actions?.find(a=>s.id?a.id===s.id:s.exact?a.text===s.text:a.text?.includes(s.text));return a&&!a.disabled;},selector);
      const a=await reveal(selector);const r=a.rect,v=page.viewportSize();check(inside(r,v),'Actual44CSS target in viewport: '+(selector.id||selector.text));
      const current=await q(),actual=pick(current,selector);assert(actual&&!actual.disabled,'The actual planned action remains available immediately before input');assert(actual.rect.every((value,index)=>Math.abs(value-r[index])<=.25),'No stale target rectangle is dispatched');assert(inside(actual.rect,v),'Latest actual target still has44CSS viewport bounds');
      const live=actual.rect;report.actions.push({selector,rect:live,text:actual.text||'',page:current.page});await page.touchscreen.tap(live[0]+live[2]/2,live[1]+live[3]/2);await fresh();save();
    }
    const shell=id=>tap({kind:'shell',id});const hostedText=(text,exact=false)=>tap({kind:'hosted',text,exact});const hostedId=id=>tap({kind:'hosted',id});
    async function shot(tag){stage='screenshot:'+tag;const png=await nativeCapture(page,{factor:2,timeout:45000,receipts:report.native_captures,tag});const file=path.join(output,engine+'-'+tag+'.png');fs.writeFileSync(file,png);report.screenshots.push({tag,file,sha256:hash(png),bytes:png.length});save();}
    const getEconomy=o=>{const a=o.economies.filter(x=>x.envelope?.primary?.catalog_id==='production-550-v1');assert.equal(a.length,1,'Exactly one actual production economy slot');return a[0];};
    async function financialPanSafety(){
      report.financial_pan_safety=[];
      for(const text of ['Booster sichern','Booster öffnen']){
        const selector={kind:'hosted',text};const control=await reveal(selector);const before=getEconomy(await observe());const r=control.rect;
        const from={x:r[0]+r[2]/2,y:r[1]+r[3]/2},to={x:from.x,y:from.y-80};
        if(cdp){await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...from,id:0,radiusX:2,radiusY:2,force:1}]});try{await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{...to,id:0,radiusX:2,radiusY:2,force:1}]});}finally{await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}}
        else{await page.mouse.move(from.x,from.y);await page.mouse.down();try{await page.mouse.move(to.x,to.y);}finally{await page.mouse.up();}}
        await fresh();const after=getEconomy(await observe());check(after.raw===before.raw,'Immediate original button-pan release cannot purchase/open: '+text);
        report.financial_pan_safety.push({selector,from,to,immediate_release:true,full_saved_state_unchanged:true,before_sequence:before.envelope.primary.sequence,after_sequence:after.envelope.primary.sequence});save();
      }
    }
    async function openPack(label){
      const before=getEconomy(await observe()).envelope.primary;await hostedText('Booster öffnen');
      await wait(sequence=>{for(const k of Object.keys(localStorage).filter(k=>k.startsWith('orafold.economy.sandbox.'))){const s=JSON.parse(localStorage.getItem(k)).primary;if(s?.catalog_id==='production-550-v1'&&s.sequence===sequence+1)return true;}return false;},before.sequence);
      const after=getEconomy(await observe()).envelope.primary;const tx=after.transactions[after.journal.at(-1).id];
      check(tx.request.type==='open_booster'&&tx.result.cards.length===5,label+' opens exactly five real card results');
      for(const result of tx.result.cards)check(cards.has(result.id)&&cards.get(result.id).rarity===result.rarity,label+' actual catalog identity '+result.id);
      check(after.boosters.standard===before.boosters.standard-1&&after.wallet.gold===before.wallet.gold,label+' consumes one saved booster and no additional gold');
      const converted=tx.result.cards.reduce((n,c)=>n+(c.converted||0),0),newCopies=tx.result.cards.filter(c=>!(c.converted>0)).length;
      const copies=s=>Object.values(s.collection).reduce((n,c)=>n+c.count,0);
      check(copies(after)===copies(before)+newCopies&&after.wallet.crafting===before.wallet.crafting+converted,label+' exact copies and duplicate essence accounted');
      (report.booster_openings||=[]).push({label,before,after,results:tx.result.cards});
      await reveal({kind:'hosted',text:'Booster öffnen'},[70,140]);await shot(label);
      return after;
    }
    await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:45000});await page.waitForFunction(()=>window.orafoldQA?.page==='lobby',null,{timeout:90000});await fresh();
    report.build=await page.evaluate(()=>fetch('build-info.json',{cache:'no-store'}).then(r=>r.json()));check(report.build.commit===expected,'Exact exported source commit');
    await shell('start');await wait(()=>window.orafoldQA.page==='decks');await shell('choose_houses');await shell('deck_play');await wait(()=>window.orafoldQA.page==='battle'&&window.orafoldQA.battle.stage==='mulligan');
    await page.setViewportSize({width:844,height:390});await wait(()=>!window.orafoldQA.portrait&&window.orafoldQA.actions.mulligan_done);
    check((await q()).hand.length===5,'Actual on-board five-card mulligan');
    await wait(sizes=>{const rows=window.orafoldQA?.battle_art?.filter(row=>row.zone==='hand'&&row.visible);return rows?.length===5&&rows.every(row=>row.status==='final'&&!row.pending&&row.profile==='compact'&&row.pixels?.[0]===sizes[row.card_id]?.[0]&&row.pixels?.[1]===sizes[row.card_id]?.[1]);},previewSizes);
    await shot('mulligan-hint-844x390');
    await shell('menu');await shell('confirm_menu');await wait(()=>window.orafoldQA.page==='lobby');
    await page.setViewportSize({width:390,height:844});await fresh();await shell('collection');await wait(()=>window.orafoldQA.library_total===550);check((await q()).library_total===550,'Actual collection has550 active cards');await shell('builder_back');
    await shell('economy');await wait(()=>window.orafoldQA.page==='economy'&&window.orafoldQA.economy_ready);
    let before=getEconomy(await observe()).envelope.primary;check(before.trust==='local_untrusted_test_data'&&before.starters_granted,'Actual untrusted local550 economy and free starters');check(before.wallet.gold>=100&&before.boosters.standard>=1,'Existing normal onboarding makes purchase/open available without injection');
    await financialPanSafety();
    await hostedText('Booster sichern');await wait(sequence=>Object.keys(localStorage).filter(k=>k.startsWith('orafold.economy.sandbox.')).some(k=>JSON.parse(localStorage.getItem(k)).primary?.sequence===sequence+1),before.sequence);
    let after=getEconomy(await observe()).envelope.primary;check(after.wallet.gold===before.wallet.gold-100&&after.boosters.standard===before.boosters.standard+1,'Real gold purchase is exactly100 for one booster');
    report.booster_purchase={before,after};await openPack('booster-portrait');
    await page.setViewportSize({width:844,height:390});await fresh();await openPack('booster-landscape');
    const saved=getEconomy(await observe());report.economy_saved_sha256=hash(saved.raw);
    await page.reload({waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.orafoldQA?.page==='lobby',null,{timeout:90000});await shell('economy');await wait(()=>window.orafoldQA.economy_ready);check(getEconomy(await observe()).raw===saved.raw,'Reload preserves exact committed economy bytes and both reveals without replayed rewards');await shot('booster-reloaded-landscape');
    await hostedText('Zurück');await wait(()=>window.orafoldQA.page==='lobby');await page.setViewportSize({width:390,height:844});await fresh();await shell('campaign');await wait(()=>window.orafoldCampaignQA?.screen==='overview');
    check((await observe()).campaign.validation_errors.length===0,'Actual provisional campaign content validates');await shot('campaign-provisional-overview');
    await hostedId('chapter_cp01');await wait(()=>window.orafoldCampaignQA?.screen==='dialogue');await shot('campaign-dialogue');
    for(let step=0;step<24;step++){await wait(()=>window.orafoldQA?.hosted_actions?.some(a=>['choice_preserve','next'].includes(a.id)));const current=await q();if(current.hosted_actions.some(a=>a.id==='choice_preserve'))break;assert(current.hosted_actions.some(a=>a.id==='next'),'Actual displayed dialogue has a next action before the first choice');await hostedId('next');}
    check((await q()).hosted_actions.some(a=>a.id==='choice_preserve'),'Real narrative reaches its actually displayed first decision');await shot('campaign-choice');await hostedId('choice_preserve');
    await wait(()=>window.orafoldCampaignQA?.flags?.approach==='preserve');check((await observe()).campaign_store.flags.approach==='preserve','Actual selected choice persisted');
    for(let step=0;step<24;step++){await wait(()=>window.orafoldQA?.hosted_actions?.some(a=>a.id==='next'||a.text?.includes('Übungsduell starten')));const current=await q();if(current.hosted_actions.some(a=>a.text?.includes('Übungsduell starten')))break;assert(current.hosted_actions.some(a=>a.id==='next'),'Actual displayed post-choice narrative advances to its encounter');await hostedId('next');}
    await hostedText('Übungsduell starten');await wait(()=>window.orafoldCampaignQA?.screen==='battle'&&window.orafoldQA?.battle?.stage==='mulligan');
    let battle=await observe();check(battle.q.battle.production?.profile==='production-550-v1'&&battle.q.battle.hero.hp===30&&battle.q.battle.enemy.hp===30,'Campaign handoff uses actual550 production kernel and30HP');check(battle.q.battle.hero.hand.length===5&&battle.q.battle.hero.lanes.length===5&&battle.q.battle.enemy.lanes.length===5,'Actual campaign battle has five starting cards and five paired paths');
    const initialBattle=structuredClone(battle.q.battle),token=battle.campaign_store.active.battle.token;check(typeof token==='string'&&token.length>0,'Encounter has a real durable token');await shot('campaign-battle-start');
    await hostedText('Austausch bestätigen',true);await wait(()=>window.orafoldQA.battle.stage!=='mulligan');battle=await observe();check(battle.q.command_count===1,'One real campaign mulligan command accepted');
    const liveBattle=canonical(battle.q.battle),liveCommands=battle.q.command_count;
    await hostedText('Kapitelübersicht',true);await wait(()=>window.orafoldCampaignQA.screen==='overview');await hostedId('resume');await wait(()=>window.orafoldCampaignQA.screen==='battle');battle=await observe();check(canonical(battle.q.battle)===liveBattle&&battle.q.command_count===liveCommands&&battle.campaign_store.active.battle.token===token,'Actual overview and resume preserve the same live encounter and commands');
    await hostedText('Hauptmenü',true);await wait(()=>window.orafoldQA.page==='lobby');await page.reload({waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.orafoldQA?.page==='lobby',null,{timeout:90000});await shell('campaign');await wait(()=>window.orafoldCampaignQA.screen==='overview');
    let restored=await observe();check(restored.campaign_store.flags.approach==='preserve'&&restored.campaign_store.active.battle.token===token,'Campaign choice and battle token survive actual browser reload');await hostedId('resume');await wait(()=>window.orafoldCampaignQA.screen==='battle');restored=await observe();check(restored.q.battle.stage==='mulligan'&&restored.q.battle.seed===initialBattle.seed,'Documented reload resumes the same-seed opening checkpoint, not an invented mid-turn journal');await shot('campaign-reloaded-checkpoint');
    report.campaign={provisional_source:JSON.parse(fs.readFileSync(path.join(root,'data/campaign_orafold/prototype.json'))).status,initial_battle:initialBattle,choice:restored.campaign_store.flags.approach,token,live_resume_sha256:hash(liveBattle),reload_battle:restored.q.battle,reload_scope:'same-seed safe encounter opening, not exact midturn resume'};
    check(getEconomy(await observe()).raw===saved.raw,'Uncompleted campaign journey cannot mint economy completion rewards');await hostedText('Hauptmenü',true);await wait(()=>window.orafoldQA.page==='lobby');
    check(report.errors.length===0,'No browser/Godot errors');report.status='passed';report.finished_at=new Date().toISOString();save();console.log(JSON.stringify({engine,status:report.status,checks:report.checks.length,actions:report.actions.length,pans:report.pans.length,screenshots:report.screenshots.length}));
  }catch(error){report.status='failed';report.failure ||= String(error);report.last_stage=stage;try{report.failure_observation=await page.evaluate(()=>({q:window.orafoldQA,campaign:window.orafoldCampaignQA}));}catch(e){report.failure_observation=String(e);}save();throw error;}
  finally{clearTimeout(deadline);await browser?.close();save();}
}
})().catch(error=>{console.error(error);if(process.exitCode!==2)process.exitCode=1;});
