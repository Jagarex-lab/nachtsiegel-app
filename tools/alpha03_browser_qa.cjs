'use strict';
// Uses only visible canvas input and read-only QA observations. No fake wins.
const {chromium,webkit,devices}=require('playwright');
const assert=require('node:assert/strict'),fs=require('node:fs');
const rootURL=process.env.GAME_URL||'http://127.0.0.1:8893/';
const output=process.env.ALPHA03_BROWSER_OUTPUT||'work/alpha03/browser';
fs.mkdirSync(output,{recursive:true});
const results=[];
(async()=>{
 for(const name of (process.env.QA_ENGINES||'chromium,webkit').split(',')){
  const browser=await (name==='webkit'?webkit:chromium).launch({headless:true,...(name==='chromium'?{channel:'chromium',args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']}: {})});
  let page,checks=0;
  const errors=[];
  const check=(ok,label)=>{checks++;assert(ok,label);};
  try{
   const {screen,...phone}=devices['iPhone 13'];
   const context=await browser.newContext({...phone,viewport:{width:390,height:844},deviceScaleFactor:2});
   page=await context.newPage();page.setDefaultTimeout(120000);
   page.on('pageerror',e=>errors.push(String(e)));
   page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
   const q=()=>page.evaluate(()=>window.orafoldQA);
   const wait=fn=>page.waitForFunction(fn,undefined,{timeout:120000});
   const tap=async rect=>{
    check(rect[2]>=43.9&&rect[3]>=43.9,'44px touch target');
    const v=page.viewportSize();check(rect[0]>=-1&&rect[1]>=-1&&rect[0]+rect[2]<=v.width+1&&rect[1]+rect[3]<=v.height+1,'target in viewport');
    await page.touchscreen.tap(rect[0]+rect[2]/2,rect[1]+rect[3]/2);
   };
   const action=async id=>{
    await page.waitForFunction(id=>window.orafoldQA?.actions[id]&&!window.orafoldQA.actions[id].disabled,id);
    await tap((await q()).actions[id].rect);
   };
   const hosted=async text=>{
    await page.waitForFunction(text=>window.orafoldQA?.hosted_actions?.some(x=>x.text.includes(text)&&!x.disabled),text);
    const a=(await q()).hosted_actions.find(x=>x.text.includes(text)&&!x.disabled);await tap(a.rect);
   };
   const shot=async label=>{await page.waitForTimeout(300);await page.screenshot({path:`${output}/${name}-${label}.png`});};
   await page.goto(new URL('?qa=1',rootURL).href,{waitUntil:'domcontentloaded'});
   await wait(()=>window.orafoldQA?.page==='lobby'&&window.orafoldQA.actions.online);
   const info=await page.evaluate(()=>fetch('build-info.json').then(x=>x.json()));
   if(process.env.EXPECTED_COMMIT)check(info.commit===process.env.EXPECTED_COMMIT,'exact candidate commit');
   for(const id of ['start','campaign','builder','collection','economy','online','settings'])check(Boolean((await q()).actions[id]),'real main entry '+id);
   await shot('main-portrait');
   await action('economy');await wait(()=>window.orafoldQA.page==='economy'&&window.orafoldQA.economy_ready);
   await shot('progress-portrait');
   const beforeActions=(await q()).hosted_actions.map(x=>x.text);
   check(beforeActions.some(x=>x.includes('Zurück')),'economy back exists');
   for(const size of [{width:844,height:390},{width:390,height:844}]){
    await page.setViewportSize(size);await page.waitForTimeout(500);
    check((await q()).page==='economy'&&(await q()).economy_ready,'economy survives rotation');
   }
   await hosted('Zurück');await wait(()=>window.orafoldQA.page==='lobby');
   await action('campaign');await wait(()=>window.orafoldQA.page==='campaign'&&window.orafoldCampaignQA?.screen==='overview');
   check((await page.evaluate(()=>window.orafoldCampaignQA.validation_errors)).length===0,'campaign content valid in exported package');
   await shot('campaign-portrait');
   await hosted('Hauptmenü');await wait(()=>window.orafoldQA.page==='lobby');
   await action('online');await wait(()=>window.orafoldQA.page==='online');
   check((await q()).hosted_actions.some(x=>x.text.includes('Anmelden')),'online real authentication control');
   await shot('online-portrait');
   await hosted('Zurück');await wait(()=>window.orafoldQA.page==='lobby');
   await action('collection');await wait(()=>window.orafoldQA.library_total===550);
   await shot('collection-portrait');
   await action('builder_back');await wait(()=>window.orafoldQA.page==='lobby');
   await action('start');await wait(()=>window.orafoldQA.page==='decks');
   const starterIDs=Object.keys((await q()).actions).filter(x=>x.startsWith('choose_'));
   check(starterIDs.length===4,'four actual starter choices');
   await shot('starters-portrait');
   await action(starterIDs[0]);await action('deck_play');await wait(()=>window.orafoldQA.page==='battle');
   check((await q()).portrait,'portrait has orientation guidance');check(Boolean((await q()).actions.rotate_menu),'safe return through portrait guide');
   const initial=(await q()).battle,initialCommands=(await q()).command_count;
   for(let cycle=0;cycle<3;cycle++){
    await page.setViewportSize({width:844,height:390});await wait(()=>!window.orafoldQA.portrait&&window.orafoldQA.actions.mulligan_done);
    check(JSON.stringify((await q()).battle)===JSON.stringify(initial),'rotation preserves entire model '+cycle);
    check((await q()).command_count===initialCommands,'rotation does not execute actions '+cycle);
    check(Object.keys((await q()).board).length===10,'five paired lanes restored '+cycle);
    await page.setViewportSize({width:390,height:844});await wait(()=>window.orafoldQA.portrait&&window.orafoldQA.actions.rotate_menu);
   }
   await page.setViewportSize({width:915,height:412});await wait(()=>!window.orafoldQA.portrait&&window.orafoldQA.actions.mulligan_done);
   await shot('opening-landscape');
   await page.reload({waitUntil:'domcontentloaded'});await wait(()=>window.orafoldQA?.page==='lobby'&&!window.orafoldQA.portrait);
   check(!(await q()).actions.rotate_menu,'landscape reload has no stuck portrait overlay');
   await action('start');await wait(()=>window.orafoldQA.page==='decks');
   const again=Object.keys((await q()).actions).find(x=>x.startsWith('choose_'));await action(again);await action('deck_play');
   await wait(()=>window.orafoldQA.page==='battle'&&!window.orafoldQA.portrait&&window.orafoldQA.actions.mulligan_done);
   check((await q()).battle.stage==='mulligan','fresh landscape reload starts playable real opening');
   check(errors.length===0,'no browser/Godot errors: '+errors.join('\n'));
   results.push({engine:name,checks,failures:0,commit:info.commit,physical_device:false,scope:'actual integrated Web export, menus,550 collection, repeated rotation/full-state retention and landscape reload'});
   await context.close();
  }catch(error){
   if(page)await page.screenshot({path:`${output}/${name}-FAILED.png`}).catch(()=>{});
   results.push({engine:name,checks,failures:1,error:String(error),errors});throw error;
  }finally{
   await browser.close();fs.writeFileSync(`${output}/results.json`,JSON.stringify(results,null,2));
  }
 }
 console.log(JSON.stringify(results));
})().catch(error=>{console.error(error);process.exitCode=1;});
