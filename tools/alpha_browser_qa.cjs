'use strict';
const {chromium,webkit,devices}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const cards=[...JSON.parse(fs.readFileSync('data/production/cards.json','utf8')).cards,...JSON.parse(fs.readFileSync('data/legacy/cards.json','utf8')).cards],by=Object.fromEntries(cards.map(c=>[c.id,c]));
(async()=>{
 const url=new URL(process.env.GAME_URL||'http://127.0.0.1:8788/');url.searchParams.set('qa','1');
 const legacyOnly=process.env.QA_LEGACY_ONLY==='1';
 fs.rmSync('work/alpha/browser-results.json',{force:true});
 const results=[],profiles={chromium:[{name:'desktop',viewport:{width:1280,height:720},hasTouch:true},{name:'desktop-wide',viewport:{width:1600,height:900},hasTouch:true},{...devices['Pixel 7'],name:'android',viewport:{width:915,height:412},deviceScaleFactor:1},{...devices['Pixel 7'],name:'android-bars',viewport:{width:844,height:320},deviceScaleFactor:2,insets:{left:44,right:44,top:0,bottom:21}}],webkit:[{...devices['iPhone 13'],name:'iphone',viewport:{width:844,height:390},deviceScaleFactor:3},{...devices['iPhone 13 Pro Max'],name:'iphone-wide',viewport:{width:915,height:412},deviceScaleFactor:1},{...devices['iPhone 13'],name:'iphone-bars',viewport:{width:844,height:320},deviceScaleFactor:1,reducedMotion:'reduce',insets:{left:44,right:44,top:0,bottom:21}}]};
 for(const engine of (process.env.QA_ENGINES||'chromium,webkit').split(',')){
  for(const profile of profiles[engine].filter(p=>!process.env.QA_PROFILES||process.env.QA_PROFILES.split(',').includes(p.name))){
  const browser=await (engine==='webkit'?webkit:chromium).launch({headless:true,...(process.env.QA_PROXY?{proxy:{server:process.env.QA_PROXY,bypass:"localhost,127.0.0.1"}}:{}),...(engine==='chromium'?{args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']}: {})});
  try{
   console.log('BROWSER RUNTIME',engine,browser.version(),require('playwright/package.json').version);
   const {name,insets,...opts}=profile,context=await browser.newContext(opts),page=await context.newPage(),errors=[];
   let inspectedCard=null,profileTemplate=null;const relicActivations=[],toolbarTests=[];
   page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
   if(insets)await page.addInitScript(v=>Object.defineProperty(window,'nachtsiegelInsets',{configurable:true,get:()=>()=>v,set:()=>{}}),insets);
   const state=()=>page.evaluate(()=>window.orafoldQA);const progress=setInterval(async()=>{try{const q=await state();fs.writeFileSync(`work/alpha/browser-progress-${engine}-${name}.json`,JSON.stringify({engine,name,page:q?.page,modal:q?.modal,message:q?.message,commands:q?.command_count,battle:q?.battle},null,2));}catch{}},5000);progress.unref();
   const wait=fn=>page.waitForFunction(fn,undefined,{timeout:90000});
   const tap=async r=>{await page.touchscreen.tap(r[0]+r[2]/2,r[1]+r[3]/2);await page.waitForTimeout(90);};
   const action=async id=>{if(id==='convergence'&&!(await state()).actions[id])await action('actions');await page.waitForFunction(id=>{const a=window.orafoldQA?.actions?.[id];return a&&!a.disabled&&a.rect[2]>=43.9&&a.rect[3]>=43.9;},id,{timeout:90000});let previous=await state();if(id==='convergence'&&!previous.actions[id]){await action('actions');previous=await state();}
    const inside=r=>r[0]>=-.1&&r[1]>=-.1&&r[0]+r[2]<=page.viewportSize().width+1&&r[1]+r[3]<=page.viewportSize().height+1;
    if((previous.modal&&id!=='modal_close')||/^(custom_|template_|choose_|preview_)/.test(id)){
     for(let tries=0;tries<8&&!inside(previous.actions[id].rect);tries++){
      const r=previous.actions[id].rect,v=page.viewportSize();
      await page.mouse.move(Math.max(1,Math.min(v.width-1,r[0]+r[2]/2)),v.height*.6);
      await page.mouse.wheel(0,r[1]<0?-v.height*.55:v.height*.55);
      await page.waitForTimeout(140);previous=await state();
     }
    }
    assert(inside(previous.actions[id].rect),id+' actual visible touch bounds');
    await tap(previous.actions[id].rect);await page.waitForFunction(v=>{const q=window.orafoldQA;return q.render_version>v.render_version||q.modal_version!==v.modal_version;},previous,{timeout:90000});};
   const capture=engine==='chromium'?await context.newCDPSession(page):null;
   const shot=async tag=>{
    let buffer;
    if(capture){
     const viewport=page.viewportSize();let expiry;
     const response=await Promise.race([capture.send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:true,clip:{x:0,y:0,width:viewport.width,height:viewport.height,scale:opts.deviceScaleFactor||1}}),new Promise((_,reject)=>{expiry=setTimeout(()=>reject(new Error('CDP capture timed out after 30s')),30000)})]).finally(()=>clearTimeout(expiry));
     buffer=Buffer.from(response.data,'base64');
    }else buffer=await page.screenshot();
    assert.equal(buffer.readUInt32BE(16),page.viewportSize().width*(opts.deviceScaleFactor||1),'native screenshot width');
    assert.equal(buffer.readUInt32BE(20),page.viewportSize().height*(opts.deviceScaleFactor||1),'native screenshot height');
    assert(buffer.length>20000,'nonempty rendered screenshot');
    fs.writeFileSync(`work/alpha/${engine}-${name}-${tag}.png`,buffer);
    return buffer;
   };
   async function opening(customPower=null){await action('start');if(!legacyOnly){if(customPower)await action('custom_'+customPower);await action('deck_play');}if(legacyOnly){await wait(()=>window.orafoldQA.board.hero0);return;}await action('mulligan_done');await action('origin_2');await wait(()=>window.orafoldQA?.battle?.stage!=='origins');if((await state()).battle.stage==='second')await action('opening_done');await wait(()=>window.orafoldQA?.battle?.stage==='battle'&&window.orafoldQA.board.hero0);}
   async function toolbarViewportChecks(){
    // Obtain six real cards by drawing, or by holding the first hand for one
    // legal turn. No HP, cards, phase, seed or model state is injected.
    let current=await state();
    if(current.battle.hero.phase==='draw'){await action('end');current=await state();}
    if(current.battle.hero.hand.length<6){
     assert.equal(current.battle.hero.phase,'main','real hold-turn starts in main phase');await action('end');
     await page.waitForFunction(()=>window.orafoldQA.battle.active==='hero'&&window.orafoldQA.battle.hero.phase==='draw');await action('end');current=await state();
    }
    assert.equal(current.battle.hero.hand.length,6,'six-card toolbar case is reached through real draw/turn commands');
    const expected=current.battle,commands=current.command_count,previousViewport=page.viewportSize();
    await page.evaluate(()=>{window.__orafoldToolbarPriorInsets=Object.getOwnPropertyDescriptor(window,'nachtsiegelInsets');Object.defineProperty(window,'nachtsiegelInsets',{configurable:true,value:()=>({left:44,right:44,top:0,bottom:21})});});
    try{
     for(const height of [270,320]){
      const version=(await state()).render_version;await page.setViewportSize({width:844,height});
      await page.waitForFunction(({version,height})=>{const q=window.orafoldQA;return q?.render_version>version&&Math.abs(q.layout_size[0]-756)<1&&Math.abs(q.layout_size[1]-(height-21))<1;},{version,height},{timeout:90000});
      const resized=await state();assert.deepEqual(resized.battle,expected,'toolbar resize preserves full model state');assert.equal(resized.command_count,commands,'toolbar resize issues no command');assert(!resized.actions.rotate_menu,'landscape browser toolbars must not show an orientation guard');assert.equal(Object.keys(resized.board).length,10,'all five paired paths remain available with toolbars');assert.equal(resized.hand.length,6,'all six actual hand cards stay present');
      const safe=r=>r&&r[0]>=43.9&&r[1]>=-.1&&r[0]+r[2]<=800.1&&r[1]+r[3]<=height-21+.1;
      for(const [id,r]of Object.entries(resized.board)){assert(safe(r),id+' remains inside simulated safe area');assert(r[2]>=43.9&&r[3]>=43.9,id+' remains44CSS');}
      for(const c of resized.hand){assert(safe(c.rect),'six-card hand safe area '+c.id);assert(c.rect[2]>=43.9&&c.rect[3]>=43.9,'six-card touch44CSS '+c.id);}
      for(const id of ['menu','end']){const r=resized.actions[id]?.rect;assert(safe(r),id+' toolbar primary action remains visible');assert(r[2]>=43.9&&r[3]>=43.9,id+' remains44CSS with toolbars');}
      await action('menu');assert((await state()).modal,'safe menu really opens through touch at toolbar height');await action('modal_close');assert.deepEqual((await state()).battle,expected,'menu inspection is read-only during toolbar test');
      await shot('toolbar-'+height+'-six-cards');toolbarTests.push({viewport:{width:844,height},simulated_safe_insets:{left:44,right:44,top:0,bottom:21},available_height:height-21,hand_size:6,real_device_test:false});
     }
    }finally{
     await page.evaluate(()=>{const descriptor=window.__orafoldToolbarPriorInsets;if(descriptor)Object.defineProperty(window,'nachtsiegelInsets',descriptor);else delete window.nachtsiegelInsets;delete window.__orafoldToolbarPriorInsets;});
     const version=(await state()).render_version;await page.setViewportSize(previousViewport);await page.waitForFunction(v=>window.orafoldQA.render_version>v,version);
    }
    assert.deepEqual((await state()).battle,expected,'restoring browser geometry preserves all gameplay state');
   }
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
     for(const legal of q.legal_plays||[]){
      if(legal.lanes.length){choice={i:legal.index,lane:legal.lanes[0],side:legal.side,relic:legal.relic};break;}
     }
     if(!choice){
      if(q.mode==='alpha'&&p.relic&&!p.relic_used){
       // The actual enabled button is the model's activation contract. Generic
       // relics must not disappear behind an obsolete four-effect lookup table.
       await action('actions');const activation=(await state()).actions.relic;
       assert(activation,'installed relic has an actual activation control');
       if(!activation.disabled){
        const before=await state(),id=before.battle.hero.relic.id;await action('relic');await page.waitForFunction(n=>window.orafoldQA.command_count>n,before.command_count);
        const after=await state();assert.equal(after.command_count,before.command_count+1,'relic activation issues exactly one command');assert(after.battle.hero.relic_used,'actual activation consumes its per-turn use');
        relicActivations.push({id,generic:by[id]?.effect==='v2',remaining_relic:after.battle.hero.relic?.id||null,round:before.battle.round,command:after.command_count});continue;
       }
       await action('modal_close');
      }
      const ready=q.controlled_lanes||[];
      if(q.mode==='alpha'&&b.round>=11&&ready.length>=3){
       await action('convergence');for(const i of ready.slice(0,3)){const previous=await state();await tap(previous.board['hero'+i]);await page.waitForFunction(v=>window.orafoldQA.render_version>v,previous.render_version);}const previous=await state();await action('convergence');await page.waitForFunction(n=>window.orafoldQA.command_count>n,previous.command_count);
      }else await action('end');return;
     }
     await page.waitForFunction(()=>window.orafoldQA.hand.map(c=>c.id).join()===window.orafoldQA.battle.hero.hand.join());q=await state();await tap(q.hand[choice.i].rect);
     await page.waitForFunction(i=>window.orafoldQA.selected===i,choice.i);const before=(await state()).command_count;
     await tap(choice.relic?(await state()).actions.relic_slot.rect:(await state()).board[choice.side+choice.lane]);
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
    await shot('lobby');await action('collection');assert.equal((await state()).page,'collection');assert(!(await state()).actions.save_deck);
    if(!legacyOnly){
     const collection=await state(),viewport=page.viewportSize();
     const inside=r=>r[0]>=(insets?.left||0)&&r[1]>=(insets?.top||0)&&r[0]+r[2]<=viewport.width-(insets?.right||0)+1&&r[1]+r[3]<=viewport.height-(insets?.bottom||0)+1;
     // Cards are sorted by energy/name. A fixed card ID can be below the
     // ScrollContainer's visible first row; its full rect still exists in QA.
     // Inspect an actual fully visible card using browser touch, never an
     // offscreen coordinate or a direct game-model/test-hook call.
     const visible=Object.entries(collection.actions).filter(([id,a])=>id.startsWith('card_')&&!a.disabled&&a.rect[2]>=43.9&&a.rect[3]>=43.9&&inside(a.rect)).sort((a,b)=>a[1].rect[1]-b[1].rect[1]||a[1].rect[0]-b[1].rect[0]);
     assert(visible.length>0,'collection has an actual visible >=44CSS card');
     const [id,target]=visible[0],card=by[id.slice('card_'.length)];assert(card,'visible collection action identifies a real card');
     inspectedCard={id:card.id,name:card.name,rect:target.rect};
     await action(id);const detail=await state();
     assert(detail.modal&&detail.actions.inspect_target&&detail.actions.modal_close,'card inspector with explicit close actions');
     assert(detail.modal_version>collection.modal_version,'inspection opened a new modal');
     assert.deepEqual(detail.deck_ids,collection.deck_ids,'read-only collection inspection preserves the deck');
     assert.equal(detail.page,'collection','inspection stays in the collection');
     assert(inside(detail.actions.modal_close.rect)&&detail.actions.modal_close.rect[2]>=43.9&&detail.actions.modal_close.rect[3]>=43.9,'inspector close is visible >=44CSS');
     await shot('collection-inspection');await action('modal_close');
     const closed=await state();assert(!closed.modal&&closed.page==='collection','closing inspection restores collection');
     assert.deepEqual(closed.deck_ids,collection.deck_ids,'closing inspection preserves the deck');
     console.log('COLLECTION INSPECTION',engine,name,card.id,card.name);
    }
    await action('builder_back');
    if(!legacyOnly){await action('settings');const power={desktop:'houses','desktop-wide':'stillwatch',android:'ninth',iphone:'morph','android-bars':'houses','iphone-wide':'stillwatch','iphone-bars':'morph'}[name];await action('faction_'+power);await action('settings_back');}
    await opening();let q=await state();assert.equal(q.battle.hero.maxHp,legacyOnly?35:30);if(!legacyOnly)assert.equal(q.battle.enemy.maxHp,30);
    for(const key of (legacyOnly?['end','actions','inspect','menu','log']:['end','actions','inspect','menu','log'])){const r=q.actions[key].rect;assert(r[2]>=43.9&&r[3]>=43.9,`${key}:44CSS`);assert(r[0]>=0&&r[1]>=0&&r[0]+r[2]<=opts.viewport.width+1&&r[1]+r[3]<=opts.viewport.height+1,`${key}:bounds`);}
    for(const r of Object.values(q.board))assert(r[2]>=43.9&&r[3]>=43.9&&r[0]>=0&&r[1]>=0&&r[0]+r[2]<=opts.viewport.width+1&&r[1]+r[3]<=opts.viewport.height+1,'board safe bounds');
    await shot('battle');if(!legacyOnly&&['desktop','iphone'].includes(name))await toolbarViewportChecks();await playTurn();await shot('after-turn');
    if((await state()).battle.winner){await action('result_menu');}else{await action('menu');await action('confirm_menu');}
    await action('builder');await action('save_deck');await wait(()=>window.orafoldQA.message.includes('gespeichert'));await shot('builder');
    await page.reload({waitUntil:'networkidle'});await wait(()=>window.orafoldQA?.page==='lobby');await action('builder');assert.equal((await state()).deck_size,legacyOnly?25:30);await action('builder_back');
    if(['desktop','desktop-wide','android','iphone'].includes(name)){
     let productionTemplate=null;
     if(!legacyOnly){
      const templateId=['desktop','iphone'].includes(name)?'prod-relic':'prod-aggro';
      await action('builder');await action('strategy_templates');await action('template_'+templateId);
      const loaded=await state();productionTemplate=JSON.parse(fs.readFileSync('data/production/test_decks.json','utf8')).decks.find(deck=>deck.id===templateId);profileTemplate=templateId;
      assert.deepEqual(loaded.deck_ids,productionTemplate.cards,'realproductiontemplate loads exact30cards');
      assert(loaded.deck_ids.some(id=>id.startsWith('of-')),'fullbrowsergame uses actual genericproductioncards');
      await action('save_deck');await action('builder_back');
     }
     await opening(productionTemplate?.power);
     let turns=0;while(!(await state()).battle.winner&&turns++<160){const q=await state();console.log('UI DUEL',engine,name,'turn',q.battle.round,'HP',q.battle.hero.hp,q.battle.enemy.hp,'commands',q.command_count);await playTurn();}
     q=await state();assert(q.battle.winner,'complete UI duel');if(profileTemplate==='prod-relic')assert(relicActivations.some(value=>value.generic),'Reliktstrategie must exercise at least one real generic activation through UI');await shot('result');await action('result_log');await action('verify_replay');await wait(()=>window.orafoldQA.message==='Replay identisch.');
     await action('restart');await action('confirm_restart');await wait(()=>!window.orafoldQA.battle.winner);await shot('restart');
    }
    assert.equal(errors.length,0,errors.join('\n'));results.push({engine,profile:name,viewport:opts.viewport,dpr:opts.deviceScaleFactor||1,errors,inspected_card:inspectedCard,strategy_template:profileTemplate,relic_activations:relicActivations,toolbar_viewport_tests:toolbarTests,checks:'real touch, menu, collection, visible card inspector/close with unchanged deck, settings, opening, 44CSS bounds, cards, saved deck reload; fullAlpha games load real production strategy templates through builder; relic activation uses actual enabled UI control',full_duel:['desktop','desktop-wide','android','iphone'].includes(name)?(legacyOnly?'legacy':'alpha'):null});
    console.log('ALPHA BROWSER PASS:',engine,name);
   }catch(error){await shot('failure').catch(()=>{});fs.writeFileSync('work/alpha/browser-errors.json',JSON.stringify({engine,name,errors,diagnostic:await page.evaluate(()=>({status:document.querySelector('#status')?.textContent,page:window.orafoldQA?.page})).catch(()=>null)},null,2));throw error;}
   finally{clearInterval(progress);await context.close();}
  }finally{await browser.close();}
  }
 }
 fs.writeFileSync('work/alpha/browser-results.json',JSON.stringify(results,null,2));console.log(`ALPHA BROWSER: ${results.length} profiles,0 failures`);
})().catch(error=>{console.error(error);process.exit(1)});
