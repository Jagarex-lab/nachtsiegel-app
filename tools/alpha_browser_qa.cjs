'use strict';
const {chromium,webkit,devices}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const cards=[...JSON.parse(fs.readFileSync('data/alpha/cards.json','utf8')).cards,...JSON.parse(fs.readFileSync('data/legacy/cards.json','utf8')).cards],by=Object.fromEntries(cards.map(c=>[c.id,c]));
(async()=>{
 const url=new URL(process.env.GAME_URL||'http://127.0.0.1:8788/');url.searchParams.set('qa','1');
 const legacyOnly=process.env.QA_LEGACY_ONLY==='1';
 const results=[],profiles={chromium:[{name:'desktop',viewport:{width:1280,height:720},hasTouch:true},{name:'desktop-wide',viewport:{width:1600,height:900},hasTouch:true},{...devices['Pixel 7'],name:'android',viewport:{width:915,height:412},deviceScaleFactor:1},{...devices['Pixel 7'],name:'android-bars',viewport:{width:844,height:320},deviceScaleFactor:2,insets:{left:44,right:44,top:0,bottom:21}}],webkit:[{...devices['iPhone 13'],name:'iphone',viewport:{width:844,height:390},deviceScaleFactor:3},{...devices['iPhone 13 Pro Max'],name:'iphone-wide',viewport:{width:915,height:412},deviceScaleFactor:1},{...devices['iPhone 13'],name:'iphone-bars',viewport:{width:844,height:320},deviceScaleFactor:1,reducedMotion:'reduce',insets:{left:44,right:44,top:0,bottom:21}}]};
 for(const engine of (process.env.QA_ENGINES||'chromium,webkit').split(',')){
  for(const profile of profiles[engine].filter(p=>!process.env.QA_PROFILES||process.env.QA_PROFILES.split(',').includes(p.name))){
  const browser=await (engine==='webkit'?webkit:chromium).launch({headless:true,...(process.env.QA_PROXY?{proxy:{server:process.env.QA_PROXY,bypass:"localhost,127.0.0.1"}}:{}),...(engine==='chromium'?{args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']}: {})});
  try{
   console.log('BROWSER RUNTIME',engine,browser.version(),require('playwright/package.json').version);
   const {name,insets,...opts}=profile,context=await browser.newContext(opts),page=await context.newPage(),errors=[];
   page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
   if(insets)await page.addInitScript(v=>Object.defineProperty(window,'nachtsiegelInsets',{configurable:true,get:()=>()=>v,set:()=>{}}),insets);
   const state=()=>page.evaluate(()=>window.orafoldQA);const progress=setInterval(async()=>{try{const q=await state();fs.writeFileSync(`work/alpha/browser-progress-${engine}-${name}.json`,JSON.stringify({engine,name,page:q?.page,modal:q?.modal,message:q?.message,commands:q?.command_count,battle:q?.battle},null,2));}catch{}},5000);progress.unref();
   const wait=fn=>page.waitForFunction(fn,undefined,{timeout:90000});
   const tap=async r=>{await page.touchscreen.tap(r[0]+r[2]/2,r[1]+r[3]/2);await page.waitForTimeout(90);};
   const action=async id=>{if(id==='convergence'&&!(await state()).actions[id])await action('actions');await page.waitForFunction(id=>{const a=window.orafoldQA?.actions?.[id];return a&&!a.disabled&&a.rect[2]>=43.9&&a.rect[3]>=43.9;},id,{timeout:90000});let previous=await state();if(id==='convergence'&&!previous.actions[id]){await action('actions');previous=await state();}await tap(previous.actions[id].rect);await page.waitForFunction(v=>{const q=window.orafoldQA;return q.render_version>v.render_version||q.modal_version!==v.modal_version;},previous,{timeout:90000});};
   const capture=engine==='chromium'?await context.newCDPSession(page):null;
   const shot=async tag=>{
    let buffer;
    if(capture){
     const viewport=page.viewportSize();let expiry;
     const response=await Promise.race([capture.send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:true,clip:{x:0,y:0,width:viewport.width,height:viewport.height,scale:opts.deviceScaleFactor||1}}),new Promise((_,reject)=>{expiry=setTimeout(()=>reject(new Error('CDP capture timed out after 30s')),30000)})]).finally(()=>clearTimeout(expiry));
     buffer=Buffer.from(response.data,'base64');
    }else buffer=await page.screenshot();
    assert.equal(buffer.readUInt32BE(16),opts.viewport.width*(opts.deviceScaleFactor||1),'native screenshot width');
    assert.equal(buffer.readUInt32BE(20),opts.viewport.height*(opts.deviceScaleFactor||1),'native screenshot height');
    assert(buffer.length>20000,'nonempty rendered screenshot');
    fs.writeFileSync(`work/alpha/${engine}-${name}-${tag}.png`,buffer);
    return buffer;
   };
   async function opening(){await action('start');if(!legacyOnly)await action('deck_play');if(legacyOnly){await wait(()=>window.orafoldQA.board.hero0);return;}await action('mulligan_done');await action('origin_2');await wait(()=>window.orafoldQA?.battle?.stage!=='origins');if((await state()).battle.stage==='second')await action('opening_done');await wait(()=>window.orafoldQA?.battle?.stage==='battle'&&window.orafoldQA.board.hero0);}
   async function playTurn(){
    for(let n=0;n<22;n++){
     let q=await state(),b=q.battle,p=b.hero;if(b.winner)return;
     if(p.phase==='draw'){
      if(p.hand.length+Math.min(p.pendingDraw,p.deck.length)>6){await page.waitForFunction(()=>window.orafoldQA.hand.length===window.orafoldQA.battle.hero.hand.length);await tap(q.hand[0].rect);}
      const before=q.command_count;await action('end');await page.waitForFunction(n=>window.orafoldQA.command_count>n||window.orafoldQA.battle.winner,before);continue;
     }
     if(p.pendingTarget){const lane=b.enemy.lanes.findIndex(Boolean),before=q.command_count;await tap(q.board['enemy'+lane]);await page.waitForFunction(n=>window.orafoldQA.command_count>n,before);continue;}
     if(p.pendingShift){await action('skip');continue;}
     let choice=null;
     for(let i=0;i<p.hand.length&&!choice;i++){
      const c=by[p.hand[i]];if(c.cost>p.energy)continue;
      let lane=-1,side='hero';
      if(c.kind==='creature'){if(q.mode==='legacy'&&p.summons>=2)continue;lane=p.lanes.findIndex(x=>!x);}
      else if(c.kind==='relic')lane=0;
      else switch(c.effect){
       case 'stasis':lane=b.enemy.lanes.findIndex(Boolean);side='enemy';break;
       case 'displace':lane=b.enemy.lanes.findIndex((u,j)=>u&&([j-1,j+1].some(k=>k>=0&&k<5&&!b.enemy.lanes[k])));side='enemy';break;
       case 'surge':lane=p.lanes.findIndex(u=>u&&!u.stun&&(!u.summoned||by[u.id].effect==='haste')&&u.atk>p.weak);break;
       case 'recall':if(p.discard.some(id=>by[id].kind==='creature'))lane=p.lanes.findIndex(x=>!x);break;
       case 'redirect':if(b.delayed.some(e=>e.side==='hero')){lane=0;side='enemy';}break;
       case 'delay':case 'bolt':lane=0;side='enemy';break;
       default:lane=0;
      }
      if(lane>=0)choice={i,lane,side};
     }
     if(!choice){
      if(q.mode==='alpha'&&p.relic&&!p.relic_used&&p.energy>=1){
       const effect=by[p.relic.id].effect,benefit=effect==='relic_res'&&p.resonance<15||effect==='relic_ward'&&p.ward<25||effect==='relic_heal'&&p.hp<p.maxHp||effect==='relic_draw'&&p.hand.length<6&&p.deck.length;
       if(benefit){const before=q.command_count;await action('actions');await action('relic');await page.waitForFunction(n=>window.orafoldQA.command_count>n,before);continue;}
      }
      const ready=p.lanes.map((u,i)=>u&&!u.stun&&(!u.summoned||by[u.id].effect==='haste')&&u.atk>p.weak&&!b.enemy.lanes[i]?i:-1).filter(i=>i>=0);
      if(q.mode==='alpha'&&b.round>=11&&ready.length>=3){
       await action('convergence');for(const i of ready.slice(0,3)){const previous=await state();await tap(previous.board['hero'+i]);await page.waitForFunction(v=>window.orafoldQA.render_version>v,previous.render_version);}const previous=await state();await action('convergence');await page.waitForFunction(n=>window.orafoldQA.command_count>n,previous.command_count);
      }else await action('end');return;
     }
     await page.waitForFunction(()=>window.orafoldQA.hand.map(c=>c.id).join()===window.orafoldQA.battle.hero.hand.join());q=await state();await tap(q.hand[choice.i].rect);
     await page.waitForFunction(i=>window.orafoldQA.selected===i,choice.i);const before=(await state()).command_count;
     await tap((await state()).board[choice.side+choice.lane]);
     await page.waitForFunction(n=>window.orafoldQA.command_count>n||window.orafoldQA.battle.winner,before,{timeout:90000});
    }
    throw Error('UI action loop made no turn progress');
   }
   try{
    if(process.env.EXPECTED_COMMIT){const r=await page.request.get(new URL('build-info.json',url).href);assert(r.ok());assert.equal((await r.json()).commit,process.env.EXPECTED_COMMIT);}
    await page.goto(url.href,{waitUntil:'networkidle'});await wait(()=>window.orafoldQA?.page==='lobby');assert((await page.title()).includes('ORAFOLD'));
    console.log('LOBBY',engine,name);let menu=await state();
    for(const key of ['start','builder','collection','settings'])assert(menu.actions[key],key);
    for(const key of ['archive','mode_alpha','mode_legacy'])assert(!menu.actions[key],'no public route '+key);
    await shot('lobby');await action('collection');assert.equal((await state()).page,'collection');assert(!(await state()).actions.save_deck);if(!legacyOnly){await action('card_oa-neutral-c01');await action('modal_close');}await action('builder_back');
    if(!legacyOnly){await action('settings');const power={desktop:'houses','desktop-wide':'stillwatch',android:'ninth',iphone:'morph','android-bars':'houses','iphone-wide':'stillwatch','iphone-bars':'morph'}[name];await action('faction_'+power);await action('settings_back');}
    await opening();let q=await state();assert.equal(q.battle.hero.maxHp,legacyOnly?35:30);if(!legacyOnly)assert.equal(q.battle.enemy.maxHp,30);
    for(const key of (legacyOnly?['end','actions','inspect','menu','log']:['end','actions','inspect','menu','log'])){const r=q.actions[key].rect;assert(r[2]>=43.9&&r[3]>=43.9,`${key}:44CSS`);assert(r[0]>=0&&r[1]>=0&&r[0]+r[2]<=opts.viewport.width+1&&r[1]+r[3]<=opts.viewport.height+1,`${key}:bounds`);}
    for(const r of Object.values(q.board))assert(r[2]>=43.9&&r[3]>=43.9&&r[0]>=0&&r[1]>=0&&r[0]+r[2]<=opts.viewport.width+1&&r[1]+r[3]<=opts.viewport.height+1,'board safe bounds');
    await shot('battle');await playTurn();await shot('after-turn');
    if((await state()).battle.winner){await action('result_menu');}else{await action('menu');await action('confirm_menu');}
    await action('builder');await action('save_deck');await wait(()=>window.orafoldQA.message.includes('gespeichert'));await shot('builder');
    await page.reload({waitUntil:'networkidle'});await wait(()=>window.orafoldQA?.page==='lobby');await action('builder');assert.equal((await state()).deck_size,legacyOnly?25:30);await action('builder_back');
    if(['desktop','desktop-wide','android','iphone'].includes(name)){
     await opening();
     let turns=0;while(!(await state()).battle.winner&&turns++<160){const q=await state();console.log('UI DUEL',engine,name,'turn',q.battle.round,'HP',q.battle.hero.hp,q.battle.enemy.hp,'commands',q.command_count);await playTurn();}
     q=await state();assert(q.battle.winner,'complete UI duel');await shot('result');await action('result_log');await action('verify_replay');await wait(()=>window.orafoldQA.message==='Replay identisch.');
     await action('restart');await action('confirm_restart');await wait(()=>!window.orafoldQA.battle.winner);await shot('restart');
    }
    assert.equal(errors.length,0,errors.join('\n'));results.push({engine,profile:name,viewport:opts.viewport,dpr:opts.deviceScaleFactor||1,errors,checks:'real touch, menu, collection, settings, opening, 44CSS bounds, cards, saved deck reload',full_duel:['desktop','desktop-wide','android','iphone'].includes(name)?(legacyOnly?'legacy':'alpha'):null});
    console.log('ALPHA BROWSER PASS:',engine,name);
   }catch(error){await shot('failure').catch(()=>{});fs.writeFileSync('work/alpha/browser-errors.json',JSON.stringify({engine,name,errors,diagnostic:await page.evaluate(()=>({status:document.querySelector('#status')?.textContent,page:window.orafoldQA?.page})).catch(()=>null)},null,2));throw error;}
   finally{clearInterval(progress);await context.close();}
  }finally{await browser.close();}
  }
 }
 fs.writeFileSync('work/alpha/browser-results.json',JSON.stringify(results,null,2));console.log(`ALPHA BROWSER: ${results.length} profiles,0 failures`);
})().catch(error=>{console.error(error);process.exit(1)});
