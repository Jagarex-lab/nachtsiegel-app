'use strict';
// Read-only post-deployment verification; never dispatches or publishes.
const assert=require('node:assert/strict'),fs=require('node:fs');
const {chromium,webkit,devices}=require('playwright');
const {verifyExecutables}=require('./public_integrity.cjs');
const output='work/release-public';fs.mkdirSync(output,{recursive:true});
const candidate=JSON.parse(process.env.RELEASE_CANDIDATE||'null');
assert(candidate?.schema===1&&candidate.repository==='Jagarex-lab/nachtsiegel-app','trusted candidate required');
assert(/^[0-9a-f]{40}$/.test(candidate.commit),'exact candidate commit required');
assert.equal(candidate.public_url,'https://jagarex-lab.github.io/nachtsiegel-app/','fixed public deployment target');
const results=[];
async function getJSON(name){
 const url=new URL(name,candidate.public_url);url.searchParams.set('release',candidate.commit);
 const response=await fetch(url,{headers:{'Cache-Control':'no-cache'}});assert(response.ok,`live ${name}: ${response.status}`);return response.json();
}
(async()=>{
 let info,evidence,lastError;
 for(let attempt=0;attempt<18;attempt++){
  try{
   info=await getJSON('build-info.json');evidence=await getJSON('release-evidence.json');
   assert.equal(info.commit,candidate.commit);assert.deepEqual(evidence.candidate,candidate);lastError=null;break;
  }catch(error){lastError=error;if(attempt<17)await new Promise(resolve=>setTimeout(resolve,10000));}
 }
 if(lastError)throw lastError;
 const executables=await verifyExecutables(candidate,evidence);
 fs.writeFileSync(`${output}/provenance.json`,JSON.stringify({candidate,info,evidence,verified_executables:executables},null,2));
 for(const [engine,runner] of [['chromium',chromium],['webkit',webkit]]){
  const browser=await runner.launch({headless:true,...(engine==='chromium'?{channel:'chromium',args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']}: {})});
  let page;const errors=[];
  try{
   const {screen,...phone}=devices['iPhone 13'];
   const context=await browser.newContext({...phone,viewport:{width:844,height:390},deviceScaleFactor:2,serviceWorkers:'block'});
   page=await context.newPage();page.on('pageerror',error=>errors.push(String(error)));page.on('console',message=>{if(message.type()==='error')errors.push(message.text());});
   const url=new URL(candidate.public_url);url.searchParams.set('qa','1');url.searchParams.set('release',candidate.commit);
   const failed=[];
   page.on('response',response=>{if(response.status()>=400&&new URL(response.url()).origin===url.origin)failed.push(`${response.status()} ${new URL(response.url()).pathname}`);});
   await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:120000});
   await page.waitForFunction(()=>window.orafoldQA?.page==='lobby'&&window.orafoldQA.actions.settings,undefined,{timeout:180000});
   const state=await page.evaluate(()=>window.orafoldQA);
   for(const id of ['start','campaign','builder','collection','economy','online','settings'])assert(state.actions[id],`live main entry ${id}`);
   assert.equal(state.portrait,false,'landscape boot must not have a blocking orientation guide');
   assert.deepEqual(await page.evaluate(()=>fetch('build-info.json',{cache:'no-store'}).then(response=>response.json())),info,'runtime and HTTP source match');
   const action=state.actions.start;assert(!action.disabled&&action.rect[2]>=44&&action.rect[3]>=44,'play has an actual touch target');
   await page.touchscreen.tap(action.rect[0]+action.rect[2]/2,action.rect[1]+action.rect[3]/2);
   await page.waitForFunction(()=>window.orafoldQA?.page==='decks',undefined,{timeout:60000});
   const decks=await page.evaluate(()=>window.orafoldQA);
   assert.equal(Object.keys(decks.actions).filter(id=>id.startsWith('choose_')).length,4,'four live starter decks');
   await page.screenshot({path:`${output}/${engine}-live-starters.png`});
   assert.deepEqual(errors,[],'no runtime JavaScript exceptions');assert.deepEqual(failed,[],'no failed same-origin assets');
   results.push({engine,commit:candidate.commit,qa_run_id:candidate.qa_run_id,passed:true,physical_device:false,scope:'actual public build, executable menu and four starter choices; complete duels were tested before release'});
   await context.close();
  }catch(error){
   if(page)await page.screenshot({path:`${output}/${engine}-FAILED.png`}).catch(()=>{});
   results.push({engine,passed:false,error:String(error),errors});throw error;
  }finally{
   await browser.close();fs.writeFileSync(`${output}/results.json`,JSON.stringify(results,null,2));
  }
 }
 console.log(JSON.stringify(results));
})().catch(error=>{fs.writeFileSync(`${output}/error.txt`,String(error)+'\n');console.error(error);process.exitCode=1;});
