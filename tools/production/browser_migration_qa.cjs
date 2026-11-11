'use strict';
// Same-origin upgrade proof: all changes to game data use visible UI actions.
// IndexedDB transactions below are READ ONLY and inspect real persisted files.
// Browser/device profiles are simulations; this is not a physical iPhone test.
const {chromium,webkit,devices}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const http=require('node:http');
const crypto=require('node:crypto');
const ROOT=path.resolve(__dirname,'../..');
const OUTPUT=path.resolve(ROOT,process.env.MIGRATION_OUTPUT||'work/production-browser-migration');
const OLD=path.resolve(ROOT,process.env.MIGRATION_OLD_BUILD||'work/production/before-web');
const NEW=path.resolve(ROOT,process.env.MIGRATION_NEW_BUILD||'work/alpha/web');
const oldCards=JSON.parse(fs.readFileSync(path.join(ROOT,'data/alpha/cards.json'),'utf8')).cards;
const productionCards=JSON.parse(fs.readFileSync(path.join(ROOT,'data/production/cards.json'),'utf8')).cards;
const knownProduction=new Set(productionCards.map(c=>c.id));
const LEGACY_PROFILE='orafold_alpha_profile_v1.json';
const ACTIVE_PROFILE='orafold_profile_v2.json';
const MIRROR_KEY='orafold.profile.v2';
const MIRROR_BACKUP=MIRROR_KEY+'.bak';
const QUOTA_PADDING='orafold.qa.quota-padding';
const TIMEOUT=120000;
const PREVIOUS_RUNTIME='2b8ea627853b29ac80a5fca2f1c7a00253f92666';
const sha256=value=>crypto.createHash('sha256').update(value).digest('hex');
let servedRoot=OLD;
const mime={'.html':'text/html; charset=utf-8','.js':'application/javascript','.json':'application/json','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
function serve(request,response){
 if(!['GET','HEAD'].includes(request.method)){response.writeHead(405);response.end();return;}
 let pathname;
 try{pathname=decodeURIComponent(new URL(request.url,'http://localhost').pathname);}catch{response.writeHead(400);response.end();return;}
 if(pathname==='/favicon.ico'){response.writeHead(204);response.end();return;}
 if(!pathname.startsWith('/nachtsiegel-app/')){response.writeHead(404);response.end();return;}
 const relative=pathname.slice('/nachtsiegel-app/'.length)||'index.html';
 const filename=path.resolve(servedRoot,relative);
 if(!filename.startsWith(servedRoot+path.sep)){response.writeHead(403);response.end();return;}
 const stat=fs.statSync(filename,{throwIfNoEntry:false});
 if(!stat?.isFile()){response.writeHead(404);response.end();return;}
 response.writeHead(200,{'Content-Type':mime[path.extname(filename)]||'application/octet-stream','Content-Length':stat.size,'Cache-Control':'no-store','Cross-Origin-Opener-Policy':'same-origin','Cross-Origin-Embedder-Policy':'require-corp'});
 if(request.method==='HEAD'){response.end();return;}
 fs.createReadStream(filename).pipe(response);
}
async function readProfiles(page){
 return page.evaluate(async()=>{
  if(typeof indexedDB.databases!=='function')throw new Error('IndexedDB database enumeration unsupported: actual persisted-profile proof unavailable');
  const databases=await indexedDB.databases(),records=[];
  for(const metadata of databases){
   if(!metadata.name)continue;
   const db=await new Promise((resolve,reject)=>{
    const request=indexedDB.open(metadata.name);
    request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error);
    request.onupgradeneeded=()=>{request.transaction.abort();reject(new Error('Read-only inspection refuses to create a missing database'));};
   });
   try{
    if(!db.objectStoreNames.contains('FILE_DATA'))continue;
    await new Promise((resolve,reject)=>{
     const transaction=db.transaction('FILE_DATA','readonly');
     transaction.onerror=()=>reject(transaction.error);transaction.onabort=()=>reject(transaction.error||new Error('readonly transaction aborted'));
     transaction.oncomplete=resolve;
     transaction.objectStore('FILE_DATA').openCursor().onsuccess=event=>{
      const cursor=event.target.result;if(!cursor)return;
      const key=String(cursor.key);
      if(/\/(?:orafold_alpha_profile_v1|orafold_profile_v2)\.json(?:\.bak|\.corrupt)?$/.test(key)){
       const contents=cursor.value.contents;
       const bytes=contents instanceof Uint8Array?contents:new Uint8Array(contents);
       const raw=new TextDecoder().decode(bytes);
       let data;try{data=JSON.parse(raw);}catch{data=null;}
       records.push({database:metadata.name,key,raw,data});
      }
      cursor.continue();
     };
    });
   }finally{db.close();}
  }
  return records;
 });
}
function mainProfile(records,fileName=ACTIVE_PROFILE){
 const candidates=records.filter(row=>row.key.endsWith('/'+fileName));
 assert.equal(candidates.length,1,'exactly one real active profile file across IndexedDB databases');
 assert(candidates[0].data&&typeof candidates[0].data==='object','actual persisted profile is valid JSON');
 return candidates[0];
}
async function waitProfile(page,predicate,label,fileName=ACTIVE_PROFILE){
 const deadline=Date.now()+30000;let observed=[];
 while(Date.now()<deadline){
  observed=await readProfiles(page);
  const matches=observed.filter(row=>row.key.endsWith('/'+fileName));
  if(matches.length===1&&predicate(matches[0].data))return {profile:mainProfile(observed,fileName),records:observed};
  await page.waitForTimeout(100);
 }
 throw new Error(label+': persisted file did not reach required state: '+JSON.stringify(observed.map(row=>({key:row.key,data:row.data}))));
}
async function readWebProfile(page){
 return page.evaluate(({key,backup})=>{
  const raw=localStorage.getItem(key),previous=localStorage.getItem(backup);
  let data=null,backupData=null;try{data=raw===null?null:JSON.parse(raw);}catch{}try{backupData=previous===null?null:JSON.parse(previous);}catch{}
  return {raw,data,backup:previous,backup_data:backupData};
 },{key:MIRROR_KEY,backup:MIRROR_BACKUP});
}
async function waitWebProfile(page,predicate,label){
 const deadline=Date.now()+30000;let observed;
 while(Date.now()<deadline){observed=await readWebProfile(page);if(predicate(observed.data))return observed;await page.waitForTimeout(100);}
 throw new Error(label+': independent Web primary did not reach required state: '+JSON.stringify(observed));
}
async function fillStorageQuota(page){
 // This is infrastructure fault injection, not a profile/model edit. Only the
 // separately named QA padding value is written; real profile keys are untouched.
 return page.evaluate(key=>{
  localStorage.removeItem(key);
  const trySize=count=>{try{localStorage.setItem(key,'x'.repeat(count));return true;}catch(error){if(error.name==='QuotaExceededError')return false;throw error;}};
  let low=0,high=1024;const ceiling=8*1024*1024;
  while(high<=ceiling&&trySize(high)){low=high;high*=2;}
  if(high>ceiling)throw new Error('No actual storage quota reached within bounded8M-character padding; scenario is unsupported, not passed');
  while(high-low>1){const mid=Math.floor((low+high)/2);if(trySize(mid))low=mid;else high=mid;}
  if(!trySize(low)||trySize(low+1))throw new Error('Could not establish a reproducible real localStorage quota boundary');
  return {padding_characters:low,next_character_rejected:true};
 },QUOTA_PADDING);
}
async function run(engineName,baseURL,expectedCommit){
 const browser=await (engineName==='webkit'?webkit:chromium).launch({headless:true,...(engineName==='chromium'?{channel:'chromium',args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']}: {})});
 let context,page,cdp,oldTab,lastStep='launch',assertions=0;
 const oldTabErrors=[];
 const errors=[],steps=[],shots=[];let quotaProof=null,idbfsAfterStale=null;
 const check=(value,label)=>{assertions++;assert(value,label);};
 const equal=(actual,expected,label)=>{assertions++;assert.deepEqual(actual,expected,label);};
 const inside=(rect,viewport)=>rect&&rect[0]>=-.1&&rect[1]>=-.1&&rect[0]+rect[2]<=viewport.width+1&&rect[1]+rect[3]<=viewport.height+1;
 function progress(step){lastStep=step;steps.push(step);fs.writeFileSync(path.join(OUTPUT,engineName+'-progress.json'),JSON.stringify({engine:engineName,step,assertions},null,2));console.log('MIGRATION',engineName,step);}
 try{
  context=await browser.newContext(engineName==='webkit'?{...devices['iPhone 13'],viewport:{width:390,height:844},deviceScaleFactor:3,hasTouch:true}:{viewport:{width:1280,height:720},deviceScaleFactor:1,hasTouch:true});
  page=await context.newPage();page.setDefaultTimeout(TIMEOUT);if(engineName==='chromium')cdp=await context.newCDPSession(page);
  page.on('pageerror',error=>errors.push(String(error)));
  page.on('console',message=>{if(message.type()==='error')errors.push(message.text());});
  const q=()=>page.evaluate(()=>window.orafoldQA);
  const wait=(predicate,arg)=>page.waitForFunction(predicate,arg,{timeout:TIMEOUT});
  async function shot(tag){
   const filename=engineName+'-'+tag+'.png',viewport=page.viewportSize(),factor=engineName==='webkit'?3:1;let buffer;
   if(cdp){
    let timer;const result=await Promise.race([cdp.send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:true,clip:{x:0,y:0,width:viewport.width,height:viewport.height,scale:factor}}),new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('Native migration screenshot timeout')),45000);})]).finally(()=>clearTimeout(timer));buffer=Buffer.from(result.data,'base64');
   }else buffer=await page.screenshot({timeout:45000});
   equal(buffer.readUInt32BE(16),viewport.width*factor,'native screenshot width '+tag);equal(buffer.readUInt32BE(20),viewport.height*factor,'native screenshot height '+tag);
   check(buffer.length>20000,'actual rendered screenshot '+tag);fs.writeFileSync(path.join(OUTPUT,filename),buffer);shots.push({file:filename,bytes:buffer.length,sha256:sha256(buffer)});
  }
  async function action(id){
   await page.bringToFront();progress('action '+id);
   await wait(key=>{const action=window.orafoldQA?.actions?.[key];return action&&!action.disabled;},id);
   let before=await q();
   for(let attempt=0;attempt<16&&!inside(before.actions[id]?.rect,page.viewportSize());attempt++){
    const rect=before.actions[id].rect,viewport=page.viewportSize();
    await page.mouse.move(Math.max(1,Math.min(viewport.width-1,rect[0]+rect[2]/2)),viewport.height*.62);
    await page.mouse.wheel(0,rect[1]<0?-viewport.height*.55:viewport.height*.55);await page.waitForTimeout(140);before=await q();
   }
   const rect=before.actions[id]?.rect;check(inside(rect,page.viewportSize()),'visible bounds for '+id);check(rect[2]>=43.9&&rect[3]>=43.9,'44CSS touch area for '+id);
   await page.touchscreen.tap(rect[0]+rect[2]/2,rect[1]+rect[3]/2);
   await wait(previous=>{const current=window.orafoldQA;return current.render_version>previous.render_version||current.modal_version!==previous.modal_version;},before);
  }
  async function boot(phase){
   await page.bringToFront();const url=new URL(baseURL);url.searchParams.set('qa','1');url.searchParams.set('migration_phase',phase);
   await page.goto(url.href,{waitUntil:'networkidle'});await wait(()=>window.orafoldQA?.page==='lobby');
   check((await page.title()).includes('ORAFOLD'),'ORAFOLD starts directly');
  }
  servedRoot=OLD;progress('boot actual old runtime');await boot('old');
  const oldInfo=JSON.parse(fs.readFileSync(path.join(OLD,'build-info.json'),'utf8'));
  equal(oldInfo.commit,PREVIOUS_RUNTIME,'preserved old artifact identified by its actual commit');
  await action('settings');await action('faction_houses');await action('difficulty');await action('option_difficulty_Taktisch');await action('motion');await action('settings_back');
  if(page.viewportSize().width>page.viewportSize().height){await page.setViewportSize({width:390,height:844});await wait(()=>window.orafoldQA.portrait);}
  await action('builder');await action('deck_tab');
  const original=(await q()).deck_ids;equal(original.length,30,'old real deck starts with thirty cards');
  const removed=original[0];await action('remove_'+removed);equal((await q()).deck_size,29,'old UI removal produces29');check((await q()).actions.save_deck.disabled,'invalid29-card deck cannot save');
  await action('library_tab');
  const replacement=oldCards.find(card=>card.id!==removed&&['houses','neutral'].includes(card.faction)&&original.filter(id=>id===card.id).length<(card.rarity==='legendary'?1:3));check(replacement,'different legal old card exists');
  const search=(await q()).actions.search.rect;check(inside(search,page.viewportSize()),'old real search visible');
  await page.touchscreen.tap(search[0]+search[2]/2,search[1]+search[3]/2);await page.keyboard.type(replacement.name);await wait(name=>window.orafoldQA.search_text===name,replacement.name);await action('search_apply');
  await action('add_'+replacement.id);const edited=(await q()).deck_ids;equal(edited,[...original.slice(1),replacement.id],'old UI exact card replacement and ordering');
  await action('save_deck');
  const persisted=await waitProfile(page,data=>data?.version===1&&JSON.stringify(data.decks?.['alpha:houses']?.cards)===JSON.stringify(edited),'old UI save',LEGACY_PROFILE);
  const oldProfile=persisted.profile.data;check(oldProfile.reduced_motion===true&&oldProfile.difficulty===5&&oldProfile.faction==='houses','real old v1 disk profile contains chosen settings');
  equal(oldProfile.wins,(await q()).profile_wins,'old UI wins equal actual persisted wins');
  const oldRawSha=sha256(persisted.profile.raw);await shot('old-saved-deck');
  // Keep a genuinely stale filesystem alive BEFORE any v2 file exists.
  // Opening an old tab only after migration would already import the v2 file
  // into its IDBFS snapshot and would miss whole-filesystem deletion hazards.
  progress('open stale old-runtime tab before version2 exists');
  check(!(await readProfiles(page)).some(row=>row.key.endsWith('/'+ACTIVE_PROFILE)),'version2 file does not yet exist when stale tab opens');
  oldTab=await context.newPage();oldTab.on('pageerror',error=>oldTabErrors.push(String(error)));oldTab.on('console',message=>{if(message.type()==='error')oldTabErrors.push(message.text());});
  const oldURL=new URL(baseURL);oldURL.searchParams.set('qa','1');oldURL.searchParams.set('migration_phase','stale_old_writer_before_v2');
  await oldTab.goto(oldURL.href,{waitUntil:'networkidle'});await oldTab.waitForFunction(()=>window.orafoldQA?.page==='lobby',undefined,{timeout:TIMEOUT});
  check(!(await readProfiles(oldTab)).some(row=>row.key.endsWith('/'+ACTIVE_PROFILE)),'stale old runtime boots before any version2 persisted file');
  // No cookies, database, storageState or model state are injected. The server
  // serves another verified export at the SAME origin and same application path.
  progress('switch static test server to candidate, preserve browser context');servedRoot=NEW;await boot('production');
  const response=await page.request.get(new URL('build-info.json',baseURL).href);check(response.ok(),'candidate build-info reachable');const newInfo=await response.json();equal(newInfo.commit,expectedCommit,'actual candidate commit');
  equal((await q()).profile_wins,oldProfile.wins,'wins preserved across real engine navigation');equal((await q()).power,oldProfile.faction,'selected power preserved');
  await action('builder');equal((await q()).deck_ids,edited,'old exact deck survives initial production load');await shot('new-migrated-deck');await action('builder_back');
  await action('settings');await action('motion');
  const migrated=await waitProfile(page,data=>data?.version===2,'first production explicit preference save');
  equal(migrated.profile.data.catalog_profile,'production-550-v1','production catalog profile persisted');
  equal(migrated.profile.data.decks['alpha:houses'].cards,edited,'persisted migration keeps every original ID and order');
  equal(migrated.profile.data.decks['alpha:houses'].catalog_profile,'production-550-v1','migrated deck explicitly bound');
  equal(migrated.profile.data.difficulty,oldProfile.difficulty,'nondefault old difficulty preserved');equal(migrated.profile.data.wins,oldProfile.wins,'disk migration preserves wins');
  const webMigrated=await waitWebProfile(page,data=>data?.version===2,'first independent Web primary save');equal(webMigrated.data.decks['alpha:houses'].cards,edited,'independent Web primary keeps migrated deck');check(typeof webMigrated.backup==='string','actual independent first-save backup exists');equal(sha256(webMigrated.backup),oldRawSha,'independent Web backup preserves exact original version1 bytes');
  equal(sha256(mainProfile(migrated.records,LEGACY_PROFILE).raw),oldRawSha,'read-only import leaves old version1 source byte-exact');
  const backup=migrated.records.find(row=>row.key===migrated.profile.key+'.bak');check(backup,'first migration creates real previous-version backup');equal(sha256(backup.raw),oldRawSha,'first migration backup preserves exact old profile bytes');
  await action('motion');await action('settings_back');
  const final=await waitProfile(page,data=>data?.version===2&&data.reduced_motion===oldProfile.reduced_motion,'restored reduced motion preference');
  equal(final.profile.data.difficulty,5,'final stored difficulty remains5');equal(final.profile.data.decks['alpha:houses'].cards,edited,'second preference save preserves migrated deck');
  await page.reload({waitUntil:'networkidle'});await wait(()=>window.orafoldQA?.page==='lobby');
  await action('collection');equal((await q()).library_total,550,'new active collection has exact550 entries');check((await q()).library_visible_ids.length<=12,'portrait collection retains bounded visible controls');check((await q()).library_visible_ids.every(id=>knownProduction.has(id)),'no separateLegacy/archived IDs leak into collection');await action('builder_back');
  await action('builder');equal((await q()).deck_ids,edited,'production restart restores exact migrated deck');await shot('new-reloaded-deck');await action('builder_back');
  progress('prepare real quota failure while saving a previously absent deck slot');
  await action('settings');await action('faction_stillwatch');await action('motion');await action('motion');await action('settings_back');await action('builder');
  const beforeQuota=await waitWebProfile(page,data=>data?.version===2&&data.faction==='stillwatch'&&data.reduced_motion===oldProfile.reduced_motion,'quota precondition preferences');check(!beforeQuota.data.decks['alpha:stillwatch'],'quota case starts without the new deck slot');
  try{
   quotaProof=await fillStorageQuota(page);check(quotaProof.next_character_rejected,'real separate-key storage padding fills quota');await action('save_deck');
   check(/Speichern fehlgeschlagen/.test((await q()).message),'quota save reports a visible failure');const afterQuota=await readWebProfile(page);equal(afterQuota.raw,beforeQuota.raw,'quota failure leaves independent primary bytes unchanged');equal(afterQuota.backup,beforeQuota.backup,'quota failure rolls independent backup back exactly');check(!afterQuota.data.decks['alpha:stillwatch'],'quota failure cannot create a stored deck');
  }finally{await page.evaluate(key=>localStorage.removeItem(key),QUOTA_PADDING);}
  await action('builder_back');await action('start');check(!(await q()).actions.custom_stillwatch,'failed save cannot leave an in-memory custom deck');await action('decks_back');await action('settings');await action('faction_houses');await action('settings_back');await action('builder');equal((await q()).deck_ids,edited,'house deck remains unchanged after the failed other-slot save');
  // A stale old tab cannot contain this new identity. Saving it makes the
  // downgrade test stronger than merely preserving a deck of shared old IDs.
  await action('deck_tab');await action('remove_'+edited[0]);equal((await q()).deck_size,29,'production edit removes exactly one card');await action('library_tab');
  const newCard=productionCards.find(card=>card.id.startsWith('of-')&&card.kind==='creature'&&['houses','neutral'].includes(card.faction));check(newCard,'genuine new production identity exists');
  const newSearch=(await q()).actions.search.rect;await page.touchscreen.tap(newSearch[0]+newSearch[2]/2,newSearch[1]+newSearch[3]/2);await page.keyboard.type(newCard.name);await wait(name=>window.orafoldQA.search_text===name,newCard.name);await action('search_apply');await action('add_'+newCard.id);
  const productionEdited=(await q()).deck_ids;equal(productionEdited,[...edited.slice(1),newCard.id],'real new card replaces exactly one migrated copy');await action('save_deck');
  const productionSaved=await waitProfile(page,data=>data?.version===2&&JSON.stringify(data.decks?.['alpha:houses']?.cards)===JSON.stringify(productionEdited),'real new-card deck save');
  const productionPrimary=await waitWebProfile(page,data=>data?.version===2&&JSON.stringify(data.decks?.['alpha:houses']?.cards)===JSON.stringify(productionEdited),'real new-card independent primary');const protectedRaw=productionPrimary.raw;
  progress('write from old tab whose filesystem predates version2');
  try{
   async function oldAction(id){
    await oldTab.bringToFront();await oldTab.waitForFunction(key=>window.orafoldQA?.actions?.[key]&&!window.orafoldQA.actions[key].disabled,id,{timeout:TIMEOUT});
    const before=await oldTab.evaluate(()=>window.orafoldQA),rect=before.actions[id].rect;check(inside(rect,oldTab.viewportSize()),'old-tab visible action '+id);check(rect[2]>=43.9&&rect[3]>=43.9,'old-tab action44CSS '+id);
    await oldTab.touchscreen.tap(rect[0]+rect[2]/2,rect[1]+rect[3]/2);await oldTab.waitForFunction(previous=>{const now=window.orafoldQA;return now.render_version>previous.render_version||now.modal_version!==previous.modal_version;},before,{timeout:TIMEOUT});
   }
   await oldAction('settings');await oldAction('motion');
   const oldWritten=await waitProfile(oldTab,data=>data?.version===1&&data.reduced_motion!==oldProfile.reduced_motion,'actual stale old tab write',LEGACY_PROFILE);
   check(sha256(oldWritten.profile.raw)!==oldRawSha,'old runtime truly wrote different version1 bytes');
   const secondary=oldWritten.records.find(row=>row.key.endsWith('/'+ACTIVE_PROFILE));idbfsAfterStale={present:!!secondary,equals_new_primary:secondary?.raw===protectedRaw};
   const independent=await readWebProfile(page);equal(independent.raw,protectedRaw,'old whole-filesystem write cannot modify the independent Web primary');equal(independent.data.decks['alpha:houses'].cards,productionEdited,'new card remains in independent version2 deck');equal(oldTabErrors,[],'zero old-tab browser errors');
  }finally{servedRoot=NEW;await oldTab.close();oldTab=null;}
  await page.reload({waitUntil:'networkidle'});await wait(()=>window.orafoldQA?.page==='lobby');await action('builder');equal((await q()).deck_ids,productionEdited,'production restart ignores the later stale version1 write');
  const afterOldWrite=await waitWebProfile(page,data=>data?.version===2,'independent version2 survives old writer');equal(afterOldWrite.data.difficulty,5,'old writer cannot reset migrated difficulty');equal(afterOldWrite.data.reduced_motion,oldProfile.reduced_motion,'old writer cannot reset reduced motion');await shot('new-deck-after-old-tab-write');await action('builder_back');
  await action('start');await action('custom_houses');await action('deck_play');let state=await q();
  equal([...state.battle.hero.hand,...state.battle.hero.deck].sort(),[...productionEdited].sort(),'real new match uses protected new-card deck multiset');
  equal(state.battle.hero.hand.length,5,'five opening cards');equal(state.battle.hero.hp,30,'hero starts30HP');equal(state.battle.enemy.hp,30,'enemy starts30HP');equal(state.battle.level,5,'real match uses migrated difficulty');equal(state.battle.production.profile,'production-550-v1','real match uses production engine');
  const initial=state.battle;await page.setViewportSize({width:844,height:390});await wait(()=>window.orafoldQA.actions.mulligan_done);state=await q();equal(state.battle,initial,'rotation preserves complete new opening state');equal(Object.keys(state.board).length,10,'migrated match mulligan uses actual five paired paths');await shot('new-migrated-battlefield');
  equal(errors,[],'zero browser console or page errors');
  return {engine:engineName,browser_version:browser.version(),playwright:require('playwright/package.json').version,assertions,errors,old_runtime_commit:oldInfo.commit,old_runtime_note:'Retained 2b8ea627 build; git diff of scripts/data/assets/project/export_presets against live fde508e is empty. The actual artifact remains correctly labelled 2b8ea627.',new_commit:newInfo.commit,origin:new URL(baseURL).origin,application_path:new URL(baseURL).pathname,old_profile_database:persisted.profile.database,old_profile_key:persisted.profile.key,old_profile_sha256:oldRawSha,old_profile_wins:oldProfile.wins,edited_deck:edited,production_edited_deck:productionEdited,production_added_id:newCard.id,stale_old_tab_tested:true,stale_tab_booted_before_v2:true,idbfs_after_stale_write:idbfsAfterStale,quota_failure_test:quotaProof,removed_id:removed,added_id:replacement.id,checks:['actual old UI deck edit/save','readonly IndexedDB proves real v1 bytes','same origin/context navigation without state injection','stable IDs/order, wins, nondefaultdifficulty5 and reduced motion preserved','isolated v2 disk migration and exact v1 backup; old source untouched','actual stale old-tab whole-filesystem v1 write cannot erase independent new-card v2 deck or settings','real quota failure preserves primary, backup and in-memory deck slots','new page reload and collection550','actual migrated custom-deck match and rotation-preserved battlefield mulligan'],real_device_test:false,shots,steps};
 }catch(error){
  let diagnostic=null;try{diagnostic=page?await Promise.race([page.evaluate(()=>window.orafoldQA).catch(()=>null),new Promise(resolve=>setTimeout(()=>resolve(null),5000))]):null;}catch{}
  fs.writeFileSync(path.join(OUTPUT,engineName+'-error.json'),JSON.stringify({engine:engineName,step:lastStep,error:String(error),errors,diagnostic,assertions},null,2));
  throw error;
 }finally{if(page)try{await page.evaluate(key=>localStorage.removeItem(key),QUOTA_PADDING);}catch{}if(oldTab)await oldTab.close();if(context)await context.close();await browser.close();}
}
(async()=>{
 fs.mkdirSync(OUTPUT,{recursive:true});fs.rmSync(path.join(OUTPUT,'results.json'),{force:true});
 const oldInfo=JSON.parse(fs.readFileSync(path.join(OLD,'build-info.json'),'utf8')),newInfo=JSON.parse(fs.readFileSync(path.join(NEW,'build-info.json'),'utf8'));
 assert.equal(oldInfo.commit,PREVIOUS_RUNTIME,'known previous runtime artifact required');
 assert.match(newInfo.commit,/^[a-f0-9]{40}$/,'candidate source commit required');
 if(process.env.EXPECTED_COMMIT)assert.equal(newInfo.commit,process.env.EXPECTED_COMMIT,'expected candidate source must match build metadata');
 assert.notEqual(newInfo.commit,oldInfo.commit,'two actual different exported versions required');
 const server=http.createServer(serve);await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const url='http://127.0.0.1:'+server.address().port+'/nachtsiegel-app/';
 const results=[];
 try{
  for(const name of (process.env.QA_ENGINES||'chromium,webkit').split(',')){assert(['chromium','webkit'].includes(name));results.push(await run(name,url,newInfo.commit));}
  const report={passed:true,verified_at_utc:new Date().toISOString(),harness_sha256:sha256(fs.readFileSync(__filename)),assertions:results.reduce((n,row)=>n+row.assertions,0),real_device_test:false,new_commit:newInfo.commit,results};
  fs.writeFileSync(path.join(OUTPUT,'results.json'),JSON.stringify(report,null,2)+'\n');console.log('PRODUCTION BROWSER MIGRATION:',report.assertions,'assertions;',results.length,'engines;0 failures');
 }finally{await new Promise(resolve=>server.close(resolve));}
})().catch(error=>{console.error(error);process.exitCode=1;});
