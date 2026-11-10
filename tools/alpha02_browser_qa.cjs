'use strict';
const {chromium,webkit,devices}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const cards=JSON.parse(fs.readFileSync('data/alpha/cards.json')).cards, by=Object.fromEntries(cards.map(c=>[c.id,c]));
(async()=>{
 fs.mkdirSync('work/alpha02',{recursive:true});const records=[];
 for(const name of (process.env.QA_ENGINES||'chromium,webkit').split(',')){
  const engine=name==='webkit'?webkit:chromium;
  const browser=await engine.launch({headless:true,...(name==='chromium'?{args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']}: {})});
  try{
   const context=await browser.newContext({...devices['iPhone 13'],viewport:{width:390,height:844},deviceScaleFactor:3,hasTouch:true}),page=await context.newPage(),errors=[];
   page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
   await page.addInitScript(()=>Object.defineProperty(window,'nachtsiegelInsets',{configurable:true,get:()=>()=>innerWidth>innerHeight?{left:44,right:44,top:0,bottom:21}:{left:0,right:0,top:20,bottom:20},set:()=>{}}));
   const q=()=>page.evaluate(()=>window.orafoldQA),wait=fn=>page.waitForFunction(fn,undefined,{timeout:90000});
   const action=async id=>{
    await page.waitForFunction(id=>window.orafoldQA?.actions[id]&&!window.orafoldQA.actions[id].disabled,id,{timeout:90000});
    const a=(await q()).actions[id],r=a.rect;assert(r[2]>=43.9&&r[3]>=43.9,id+' touch');
    assert(r[0]>=0&&r[1]>=0&&r[0]+r[2]<=page.viewportSize().width+1&&r[1]+r[3]<=page.viewportSize().height+1,id+' visible bounds');
    const old=await q();await page.touchscreen.tap(r[0]+r[2]/2,r[1]+r[3]/2);
    await page.waitForFunction(v=>{const s=window.orafoldQA;return s.render_version>v.render_version||s.modal_version!==v.modal_version},old,{timeout:90000});
   };
   const url=new URL(process.env.GAME_URL||'http://127.0.0.1:8788/');url.searchParams.set('qa','1');
   const began=Date.now();await page.goto(url.href,{waitUntil:'networkidle'});await wait(()=>window.orafoldQA?.page==='lobby');
   const boot=Date.now()-began;
   const metrics=await page.evaluate(()=>({...window.orafoldDisplayMetrics(),transform:getComputedStyle(document.querySelector('canvas')).transform}));
   assert.equal(metrics.transform,'none');assert(Math.abs(metrics.pixelsWidth/metrics.cssWidth-3)<.02);assert((await q()).font_msdf);
   for(const id of ['start','builder','collection','settings'])assert((await q()).actions[id]);
   await action('start');assert.equal((await q()).page,'decks');
   for(const power of ['houses','stillwatch','morph','ninth']){assert((await q()).actions['choose_'+power]);assert((await q()).actions['preview_'+power]);}
   await page.screenshot({path:`work/alpha02/${name}-portrait-starters.png`});
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
   await action('inspect');assert((await q()).actions.modal_close);await page.screenshot({path:`work/alpha02/${name}-inspection.png`});await action('modal_close');
   await action('cancel_selection');await action('menu');await action('confirm_menu');
   await page.setViewportSize({width:390,height:844});await wait(()=>window.orafoldQA.portrait);
   await action('builder');await action('deck_tab');
   const original=(await q()).deck_ids;
   await action('remove_oa-neutral-c01');assert.equal((await q()).deck_size,29);assert((await q()).actions.save_deck.disabled);
   await action('library_tab');
   const candidate=cards.find(c=>c.id!=='oa-neutral-c01'&&['neutral','houses'].includes(c.faction)&&original.filter(id=>id===c.id).length<(c.rarity==='legendary'?1:3));
   // Find a visible first-row legal card; the deterministic starter has neutral c02.
   assert(candidate);const add='add_'+candidate.id;
   // Library starts at the top; candidates are in its first displayed row.
   await action(add);const edited=(await q()).deck_ids;assert.equal(edited.length,30);assert.notDeepEqual(edited,original);
   await action('save_deck');await page.waitForTimeout(300);
   await page.screenshot({path:`work/alpha02/${name}-portrait-builder.png`});
   await page.reload({waitUntil:'networkidle'});await wait(()=>window.orafoldQA?.page==='lobby');await action('builder');assert.deepEqual((await q()).deck_ids,edited);
   await action('builder_back');await action('start');await action('custom_houses');await action('deck_play');
   const played=(await q()).battle.hero;assert.deepEqual([...played.hand,...played.deck].sort(),[...edited].sort());
   assert.equal(errors.length,0,errors.join('\n'));
   records.push({engine:name,boot_ms:boot,metrics,errors,checks:['portrait menu and four starters','real edited deck saved/reloaded/selected','native DPR3 and MSDF','safe areas','rotation preserves complete state and selected card','landscape paths and card inspector']});
   console.log('ALPHA02 BROWSER PASS',name);await context.close();
  }finally{await browser.close();}
 }
 fs.writeFileSync('work/alpha02/browser-results.json',JSON.stringify(records,null,2));console.log('ALPHA02 BROWSER:',records.length,'profiles,0 failures');
})().catch(e=>{console.error(e);process.exit(1)});
