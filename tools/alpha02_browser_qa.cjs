'use strict';
const {chromium,webkit,devices}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const cards=JSON.parse(fs.readFileSync('data/alpha/cards.json')).cards, by=Object.fromEntries(cards.map(c=>[c.id,c]));
(async()=>{
 fs.mkdirSync('work/alpha02',{recursive:true});const records=[];
 for(const name of (process.env.QA_ENGINES||'chromium,webkit').split(',')){
  const engine=name==='webkit'?webkit:chromium;
  let lastPage,lastErrors=[];
  const browser=await engine.launch({headless:true,...(name==='chromium'?{channel:'chromium',args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']}: {})});
  try{
   const {screen:fixedScreen,...mobile}=devices['iPhone 13'];
   const context=await browser.newContext({...mobile,viewport:{width:390,height:844},deviceScaleFactor:3,hasTouch:true}),page=await context.newPage(),errors=[];
   lastPage=page;lastErrors=errors;
   page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
   await page.addInitScript(()=>Object.defineProperty(window,'nachtsiegelInsets',{configurable:true,get:()=>()=>innerWidth>innerHeight?{left:44,right:44,top:0,bottom:21}:{left:0,right:0,top:20,bottom:20},set:()=>{}}));
   const q=()=>page.evaluate(()=>window.orafoldQA),wait=fn=>page.waitForFunction(fn,undefined,{timeout:90000});
   const captures=[],cdp=name==='chromium'?await context.newCDPSession(page):null;
   const shot=async suffix=>{
    let buffer;
    if(cdp){
     const viewport=page.viewportSize();let expiry;const response=await Promise.race([cdp.send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:true,clip:{x:0,y:0,width:viewport.width,height:viewport.height,scale:3}}),new Promise((_,reject)=>{expiry=setTimeout(()=>reject(new Error('CDP capture timed out after 30s')),30000)})]).finally(()=>clearTimeout(expiry));
     buffer=Buffer.from(response.data,'base64');captures.push('cdp-explicit-native-viewport');
    }else{buffer=await page.screenshot();captures.push('playwright');}
    assert.equal(buffer.readUInt32BE(16),page.viewportSize().width*3,'native screenshot width');assert.equal(buffer.readUInt32BE(20),page.viewportSize().height*3,'native screenshot height');assert(buffer.length>20000,'nonempty rendered screenshot');
    fs.writeFileSync(`work/alpha02/${name}-${suffix}.png`,buffer);
   };

   const timings=[],rotationMetrics=[];
   const action=async id=>{const beganAction=Date.now();
    await page.waitForFunction(id=>window.orafoldQA?.actions[id]&&!window.orafoldQA.actions[id].disabled,id,{timeout:90000});
    const a=(await q()).actions[id],r=a.rect;assert(r[2]>=43.9&&r[3]>=43.9,id+' touch');
    assert(r[0]>=0&&r[1]>=0&&r[0]+r[2]<=page.viewportSize().width+1&&r[1]+r[3]<=page.viewportSize().height+1,id+' visible bounds');
    const old=await q();await page.touchscreen.tap(r[0]+r[2]/2,r[1]+r[3]/2);
    await page.waitForFunction(v=>{const s=window.orafoldQA;return s.render_version>v.render_version||s.modal_version!==v.modal_version},old,{timeout:90000});timings.push({action:id,qa_state_ms:Date.now()-beganAction});
   };
   const url=new URL(process.env.GAME_URL||'http://127.0.0.1:8788/');url.searchParams.set('qa','1');
   const began=Date.now();await page.goto(url.href,{waitUntil:'networkidle'});await wait(()=>window.orafoldQA?.page==='lobby');
   const boot=Date.now()-began;console.log('ALPHA02',name,'portrait lobby',boot);
   const metrics=await page.evaluate(()=>({...window.orafoldDisplayMetrics(),transform:getComputedStyle(document.querySelector('canvas')).transform}));
   assert.equal(metrics.transform,'none');assert(Math.abs(metrics.pixelsWidth/metrics.cssWidth-3)<.02);assert((await q()).font_msdf);
   for(const id of ['start','builder','collection','settings'])assert((await q()).actions[id]);
   await action('start');assert.equal((await q()).page,'decks');
   for(const power of ['houses','stillwatch','morph','ninth']){assert((await q()).actions['choose_'+power]);assert((await q()).actions['preview_'+power]);}
   console.log('ALPHA02',name,'starter screenshot');await shot('portrait-starters');
   await action('choose_houses');await action('deck_play');await wait(()=>window.orafoldQA.actions.rotate_menu);
   const initial=(await q()).battle;assert.equal(initial.stage,'mulligan');assert.equal(Object.keys((await q()).board).length,0);
   await page.setViewportSize({width:844,height:390});await wait(()=>window.orafoldQA.actions.mulligan_done);await page.waitForTimeout(220);
   assert.deepEqual((await q()).battle,initial);
   await action('mulligan_done');await action('origin_2');
   if((await q()).battle.stage==='second')await action('opening_done');
   await wait(()=>window.orafoldQA.battle.stage==='battle');
   let state=await q(),first=state.hand[0].rect;await page.touchscreen.tap(first[0]+first[2]/2,first[1]+first[3]/2);await wait(()=>window.orafoldQA.selected===0);
   const selected=await q();
   await page.setViewportSize({width:390,height:844});await wait(()=>window.orafoldQA.actions.rotate_menu);
   await page.setViewportSize({width:915,height:412});await wait(()=>window.orafoldQA.board.hero0);await page.waitForTimeout(220);
   assert.deepEqual((await q()).battle,selected.battle);assert.equal((await q()).selected,0);
   for(const r of Object.values((await q()).board))assert(r[2]>=43.9&&r[3]>=43.9);
   console.log('ALPHA02',name,'rotation passed');await action('inspect');assert((await q()).actions.modal_close);fs.writeFileSync('work/alpha02/'+name+'-pre-inspection.json',JSON.stringify({state:await q(),metrics:await page.evaluate(()=>({...window.orafoldDisplayMetrics(),screenWidth:screen.width,screenHeight:screen.height}))}));await shot('inspection');await action('modal_close');
   await action('cancel_selection');await action('menu');await action('confirm_menu');
   await page.setViewportSize({width:390,height:844});await wait(()=>window.orafoldQA.portrait);
   const returned=await page.evaluate(()=>window.orafoldDisplayMetrics());rotationMetrics.push(returned);assert.equal(returned.cssWidth,390,'canvas returns to portrait CSS width');assert.equal(returned.cssHeight,844,'canvas returns to portrait CSS height');assert.equal(returned.pixelsWidth,1170,'portrait native buffer restored');assert.equal(returned.pixelsHeight,2532,'portrait native buffer height restored');
   await action('builder');console.log('ALPHA02',name,'builder');
   await action('filters');await action('filter_type');await action('option_filter_type_creature');
   const shown=Object.keys((await q()).actions).filter(k=>k.startsWith('card_')).map(k=>by[k.slice(5)]);assert(shown.length&&shown.every(c=>c.kind==='creature'));
   await action('filters');await action('reset_filters');
   const beforeQuery=(await q()).deck_ids,query=(await q()).actions.search.rect;
   await page.touchscreen.tap(query[0]+query[2]/2,query[1]+query[3]/2);await page.keyboard.type('Pfad');
   await page.waitForFunction(()=>window.orafoldQA.search_text==='Pfad');
   await page.setViewportSize({width:393,height:500});await wait(()=>window.orafoldQA.layout_size[1]<500);
   assert.equal((await q()).search_text,'Pfad');assert.deepEqual((await q()).deck_ids,beforeQuery);
   const saveRect=(await q()).actions.save_deck.rect;assert(saveRect[1]+saveRect[3]<=500,'save visible with simulated keyboard viewport');
   await action('filters');await action('reset_filters');await page.setViewportSize({width:390,height:844});await wait(()=>window.orafoldQA.layout_size[1]>700);
   // Simulated keyboard: shrink visualViewport only, keeping innerHeight/buffer.
   // This is deliberately separate from a real iOS keyboard/device test.
   const beforeKeyboard=(await q()).deck_ids;
   await page.evaluate(()=>{Object.defineProperty(window.visualViewport,'height',{configurable:true,get:()=>500});window.visualViewport.dispatchEvent(new Event('resize'));});
   await wait(()=>window.orafoldQA.layout_size[1]<500);
   const keyboardMetrics=await page.evaluate(()=>window.orafoldDisplayMetrics());rotationMetrics.push(keyboardMetrics);
   assert(Math.abs(keyboardMetrics.pixelsHeight/keyboardMetrics.cssHeight-keyboardMetrics.pixelsWidth/keyboardMetrics.cssWidth)<.01,'keyboard preserves isotropic canvas scale');
   assert.equal(keyboardMetrics.visibleHeight,500);assert.deepEqual((await q()).deck_ids,beforeKeyboard);
   assert((await q()).actions.save_deck.rect[1]+(await q()).actions.save_deck.rect[3]<=500,'save stays above simulated keyboard');
   await page.evaluate(()=>{Object.defineProperty(window.visualViewport,'height',{configurable:true,get:()=>350});window.visualViewport.dispatchEvent(new Event('resize'));});
   await wait(()=>window.orafoldQA.layout_size[1]<350);assert((await q()).portrait,'keyboard does not turn portrait into landscape');
   await page.evaluate(()=>{delete window.visualViewport.height;window.visualViewport.dispatchEvent(new Event('resize'));});
   await wait(()=>window.orafoldQA.layout_size[1]>700);
   await action('deck_tab');
   const original=(await q()).deck_ids;
   await action('remove_oa-neutral-c01');assert.equal((await q()).deck_size,29);assert((await q()).actions.save_deck.disabled);
   await action('library_tab');
   const candidate=cards.find(c=>c.id!=='oa-neutral-c01'&&['neutral','houses'].includes(c.faction)&&original.filter(id=>id===c.id).length<(c.rarity==='legendary'?1:3));
   // Pick a different legal identity, then locate it through the real search UI.
   // Catalog order does not determine the energy/name-sorted library position.
   assert(candidate);const add='add_'+candidate.id;
   const beforeSearch=await q(),searchRect=beforeSearch.actions.search.rect;
   assert.equal(beforeSearch.search_text,'','previous filter reset left an empty search');
   assert(searchRect[2]>=43.9&&searchRect[3]>=43.9,'card-name search touch');
   assert(searchRect[0]>=0&&searchRect[1]>=0&&searchRect[0]+searchRect[2]<=page.viewportSize().width+1&&searchRect[1]+searchRect[3]<=page.viewportSize().height+1,'card-name search visible bounds');
   await page.touchscreen.tap(searchRect[0]+searchRect[2]/2,searchRect[1]+searchRect[3]/2);await page.keyboard.type(candidate.name);
   await page.waitForFunction(value=>window.orafoldQA.search_text===value,candidate.name,{timeout:90000});
   await action('search_apply');const found=await q();
   assert.deepEqual(Object.keys(found.actions).filter(key=>key.startsWith('card_')),['card_'+candidate.id],'name search returns the intended real card');
   assert.deepEqual(found.deck_ids,beforeSearch.deck_ids,'searching does not edit the deck');
   assert(found.deck_ids.filter(id=>id===candidate.id).length<(candidate.rarity==='legendary'?1:3),'chosen card remains below its legal copy cap');
   assert(found.actions[add]&&!found.actions[add].disabled,'actual filtered add action is legal');
   await action(add);const edited=(await q()).deck_ids;assert.equal(edited.length,30);assert.notDeepEqual(edited,original);
   assert.deepEqual(edited,[...beforeSearch.deck_ids,candidate.id],'exact replacement card added in the stored order');
   await action('save_deck');await page.waitForTimeout(300);
   await shot('portrait-builder');
   await page.reload({waitUntil:'networkidle'});await wait(()=>window.orafoldQA?.page==='lobby');await action('builder');assert.deepEqual((await q()).deck_ids,edited);console.log('ALPHA02',name,'edited deck persisted');
   await action('builder_back');await action('start');await action('custom_houses');await action('deck_play');
   const played=(await q()).battle.hero;assert.deepEqual([...played.hand,...played.deck].sort(),[...edited].sort());
   assert.equal(errors.length,0,errors.join('\n'));
   records.push({engine:name,boot_ms:boot,metrics,rotationMetrics,captures,timings,errors,deck_edit:{removed_id:'oa-neutral-c01',added_id:candidate.id,added_name:candidate.name,search_query:candidate.name},checks:['portrait menu and four starters','real card-name search and exact legal replacement','real edited deck saved/reloaded/selected','native DPR3 and MSDF','safe areas','rotation preserves complete state and selected card','landscape paths and card inspector']});
   console.log('ALPHA02 BROWSER PASS',name);await context.close();
  }catch(error){const diagnostic=lastPage?await Promise.race([lastPage.evaluate(()=>({qa:window.orafoldQA,metrics:window.orafoldDisplayMetrics?.()})).catch(()=>null),new Promise(r=>setTimeout(()=>r(null),5000))]):null;fs.writeFileSync('work/alpha02/'+name+'-error.json',JSON.stringify({error:String(error),console:lastErrors,diagnostic},null,2));throw error;}finally{await browser.close();}
 }
 fs.writeFileSync('work/alpha02/browser-results.json',JSON.stringify(records,null,2));console.log('ALPHA02 BROWSER:',records.length,'profiles,0 failures');
})().catch(e=>{console.error(e);process.exit(1)});
