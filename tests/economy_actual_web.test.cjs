'use strict';
// Runs the actual exported Godot application. No extracted adapter expressions,
// synthetic wallet grants, fake wins, or QA commands that mutate game state.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {chromium,webkit}=require('playwright');
const gameURL=process.env.GAME_URL||'http://127.0.0.1:8893/';
const engines=(process.env.ECONOMY_WEB_ENGINES||'chromium').split(',');

for(const name of engines){
 test(`actual ${name} Godot Web economy commits, fails closed, and reloads`,{timeout:180000},async t=>{
  const browser=await (name==='webkit'?webkit:chromium).launch({headless:true,...(name==='chromium'?{channel:'chromium',args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']}: {})});
  t.after(()=>browser.close());
  const context=await browser.newContext({viewport:{width:1280,height:900},deviceScaleFactor:1});
  const page=await context.newPage();
  page.setDefaultTimeout(90000);
  const errors=[];
  page.on('pageerror',error=>errors.push(String(error)));
  page.on('console',message=>{if(message.type()==='error')errors.push(message.text());});
  const read=()=>page.evaluate(()=>{
   const keys=Object.keys(localStorage).filter(key=>key.startsWith('orafold.economy.sandbox.'));
   if(keys.length!==1)return null;
   return {key:keys[0],raw:localStorage.getItem(keys[0]),envelope:JSON.parse(localStorage.getItem(keys[0]))};
  });
  const state=async()=>(await read()).envelope.primary;
  const openEconomy=async()=>{
   await page.waitForFunction(()=>window.orafoldQA?.page==='lobby'&&window.orafoldQA.actions.economy);
   const rect=await page.evaluate(()=>window.orafoldQA.actions.economy.rect);
   await page.mouse.click(rect[0]+rect[2]/2,rect[1]+rect[3]/2);
   await page.waitForFunction(()=>window.orafoldQA?.page==='economy'&&window.orafoldQA.economy_ready);
  };
  const hosted=async text=>{
   for(let step=0;step<8;step++){
    const rect=await page.evaluate(text=>window.orafoldQA?.hosted_actions?.find(action=>action.text.includes(text)&&!action.disabled)?.rect,text);
    if(rect&&rect[1]>=0&&rect[1]+rect[3]<=900){
     await page.mouse.click(rect[0]+rect[2]/2,rect[1]+rect[3]/2);
     return;
    }
    await page.mouse.move(1100,700);
    await page.mouse.wheel(0,350);
    await page.waitForTimeout(200);
   }
   assert.fail(`Visible enabled actual Control missing: ${text}`);
  };
  await page.goto(new URL('?qa=1',gameURL).href,{waitUntil:'domcontentloaded'});
  if(process.env.EXPECTED_COMMIT){
   const commit=await page.evaluate(()=>fetch('build-info.json').then(response=>response.json()).then(info=>info.commit));
   assert.equal(commit,process.env.EXPECTED_COMMIT,'the exact rebuilt candidate is under test');
  }
  await openEconomy();
  const initial=await state();
  assert.equal(initial.catalog_id,'production-550-v1');
  assert.equal(initial.starters_granted,true,'four starter grant actually committed through Web bridge');
  assert.equal(initial.wallet.gold,350,'existing onboarding plus level gold');
  assert.equal(initial.wallet.crafting,1200);
  assert.equal(initial.boosters.standard,5);
  assert(initial.claimed_rewards.includes('onboarding'));
  assert(Object.keys(initial.collection).every(id=>!id.startsWith('economy-fixture')));
  assert.equal(initial.transactions['alpha03:four-free-starters:v1'].result.ok,true);

  // Fault injection targets only this test context's economy storage writes.
  // The real Godot UI command must observe the JS false/0 bridge result.
  const beforeFailure=await read();
  await page.evaluate(()=>{
   window.__economyOriginalSetItem=Storage.prototype.setItem;
   window.__economyQuotaFailures=0;
   Storage.prototype.setItem=function(key,value){
    if(String(key).startsWith('orafold.economy.sandbox.')){
     window.__economyQuotaFailures++;
     throw new DOMException('Test quota exhausted','QuotaExceededError');
    }
    return window.__economyOriginalSetItem.call(this,key,value);
   };
  });
  await hosted('Booster sichern');
  await page.waitForFunction(()=>window.__economyQuotaFailures>0);
  assert.equal((await read()).raw,beforeFailure.raw,'failed actual Web commit leaves wallet and receipts paired');
  await page.evaluate(()=>{Storage.prototype.setItem=window.__economyOriginalSetItem;});
  await page.reload({waitUntil:'domcontentloaded'});
  await openEconomy();
  assert.deepEqual(await state(),initial,'reload after failed UI command neither charges nor invents success');

  await hosted('Booster sichern');
  await page.waitForFunction(()=>{
   const key=Object.keys(localStorage).find(key=>key.startsWith('orafold.economy.sandbox.'));
   const state=JSON.parse(localStorage.getItem(key)).primary;
   return state.wallet.gold===250&&state.boosters.standard===6;
  });
  const bought=await state();
  assert.equal(bought.sequence,initial.sequence+1,'one real purchase command creates one local gold receipt');
  await hosted('Booster öffnen');
  await page.waitForFunction(()=>{
   const key=Object.keys(localStorage).find(key=>key.startsWith('orafold.economy.sandbox.'));
   const state=JSON.parse(localStorage.getItem(key)).primary;
   return state.sequence===5&&state.boosters.standard===5;
  });
  const opened=await state();
  const openReceipt=Object.values(opened.transactions).find(transaction=>transaction.request.type==='open_booster');
  assert.equal(openReceipt.result.cards.length,5,'actual Control opens five committed real cards');
  assert.equal(opened.wallet.gold,250);
  assert.equal(opened.sequence,bought.sequence+1);
  assert.equal(errors.length,0,errors.join('\n'));
  await page.reload({waitUntil:'domcontentloaded'});
  await openEconomy();
  assert.deepEqual(await state(),opened,'reloading actual Godot app cannot repeat onboarding or pack payout');
  assert.equal(errors.length,0,errors.join('\n'));
 });
}
