'use strict';
// Reproducible actual UI probe. Read-only QA/save observations; only normal input,
// orientation-size changes and screenshots. No model/save or GUI callback writes.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {chromium,webkit,devices} = require('playwright');
const {nativeCapture,nativeGeometry} = require('./native_capture_contract.cjs');
const {campaignHeaderReady} = require('./campaign_header_contract.cjs');
const expected = process.env.EXPECTED_COMMIT;
assert(/^[a-f0-9]{40}$/.test(expected||''),'Exact exported commit is required');
const root=path.resolve(__dirname,'../..');
const output=path.join(path.resolve(process.env.PREMIUM_BROWSER_OUTPUT||path.join(root,'work/premium-browser')),'campaign-header');
fs.mkdirSync(output,{recursive:true});
const url=new URL(process.env.GAME_URL||'http://127.0.0.1:8893/');url.searchParams.set('qa','1');
const nav=['Kapitelübersicht','Rückblick','Charaktere','Leseeinstellungen','Hauptmenü'];
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
const inside=(r,v)=>r.length===4&&r.every(Number.isFinite)&&r[2]>=43.9&&r[3]>=43.9&&r[0]>=-.1&&r[1]>=-.1&&r[0]+r[2]<=v.width+.1&&r[1]+r[3]<=v.height+.1;
(async()=>{
for(const engine of (process.env.QA_ENGINES||'chromium,webkit').split(',')){
 let browser,page;
 const report={engine,source_commit:expected,driver_sha256:hash(fs.readFileSync(__filename)),source_files:Object.fromEntries(['scripts/campaign_orafold/presentation.gd','data/campaign_orafold/prototype.json','scripts/economy/alpha550_panel.gd'].map(p=>[p,hash(fs.readFileSync(path.join(root,p)))])),checks:[],rotations:[],native_captures:[],screenshots:[],errors:[],status:'running',scope:'Actual normal menu to provisional campaign overview; portrait-landscape-portrait nativeDPR2. Not a repeated economy/story/battle/fullgame/device/release certification.'};
 const save=()=>fs.writeFileSync(path.join(output,engine+'-results.json'),JSON.stringify(report,null,2));
 const check=(ok,label)=>{assert(ok,label);report.checks.push(label);};
 const deadline=setTimeout(async()=>{report.status='failed';report.failure='Explicit6-minute header journey deadline';save();process.exitCode=2;await browser?.close().catch(()=>{});},360000);
 try{
  browser=await(engine==='webkit'?webkit:chromium).launch({headless:true,...(engine==='chromium'?{channel:'chromium',args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']}:{})});
  report.browser_version=browser.version();report.playwright=require('playwright/package.json').version;
  const {screen,...phone}=devices[engine==='webkit'?'iPhone 13':'Pixel 7'];
  const context=await browser.newContext({...phone,viewport:{width:390,height:844},deviceScaleFactor:2});
  page=await context.newPage();page.setDefaultTimeout(60000);
  page.on('pageerror',e=>report.errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')report.errors.push(m.text());});
  const read=()=>page.evaluate(()=>({q:window.orafoldQA,c:window.orafoldCampaignQA,campaign_store:localStorage.getItem('orafold.campaign.v2'),economies:Object.fromEntries(Object.keys(localStorage).filter(k=>k.startsWith('orafold.economy.sandbox.')).sort().map(k=>[k,localStorage.getItem(k)]))}));
  const wait=async(fn,arg,timeout=60000)=>{const h=await page.waitForFunction(fn,arg,{timeout});await h.dispose();};
  const geometry=()=>page.evaluate(()=>{const c=document.querySelector('canvas'),r=c?.getBoundingClientRect();return {dpr:devicePixelRatio,inner:[innerWidth,innerHeight],body_width:document.body.getBoundingClientRect().width,canvas:c?{backing:[c.width,c.height],css:[r.x,r.y,r.width,r.height]}:null};});
  async function layout(label,size,rows){
   const matched=await page.waitForFunction(campaignHeaderReady,{size,nav,rows},{timeout:60000});
   let state;try{state=await matched.jsonValue();}finally{await matched.dispose();}
   check(state.readiness.matching_pairs===2,label+' two distinct coherent Shell/Campaign publications');
   const controls=nav.map(text=>{const a=state.q.hosted_actions.find(a=>a.text===text);return {text,rect:a.rect,disabled:a.disabled};});
   check(state.c.logical_viewport[0]===size.width&&state.c.logical_viewport[1]===size.height,label+' logical viewport equals actual CSS dimensions');
   check(state.c.compact===(size.width<720),label+' compact mode uses logical width');
   for(const a of controls)check(inside(a.rect,size),label+' visible44CSS nav: '+a.text);
   const ys=[];for(const a of controls)if(!ys.some(y=>Math.abs(y-a.rect[1])<1))ys.push(a.rect[1]);
   check(ys.length===rows,label+' actual navigation has '+rows+' rows');
   check(state.c.validation_errors.length===0&&!state.c.save_error,label+' prototype validates with no save error');
   const metrics=await geometry();nativeGeometry(metrics,size,2);check(true,label+' nativeDPR2 and both canvas backing axes preserved');
   report.rotations.push({label,viewport:size,logical_viewport:state.c.logical_viewport,compact:state.c.compact,navigation:controls,rows:ys.length,readiness:state.readiness,shell_portrait:state.q.portrait,metrics,screen:state.c.screen,flags:state.c.flags,campaign_store_sha256:hash(state.campaign_store||''),economy_store_sha256:hash(JSON.stringify(state.economies))});save();return state;
  }
  async function shot(tag){const png=await nativeCapture(page,{factor:2,timeout:45000,receipts:report.native_captures,tag});const file=path.join(output,engine+'-'+tag+'.png');fs.writeFileSync(file,png);report.screenshots.push({tag,file,bytes:png.length,sha256:hash(png)});save();}
  await page.goto(url.href,{waitUntil:'domcontentloaded',timeout:45000});await wait(()=>window.orafoldQA?.page==='lobby',null,90000);
  report.build=await page.evaluate(()=>fetch('build-info.json',{cache:'no-store'}).then(r=>r.json()));check(report.build.commit===expected,'Exact new exported commit');
  await wait(()=>window.orafoldQA?.actions?.campaign&&!window.orafoldQA.actions.campaign.disabled);
  const a=(await read()).q.actions.campaign;check(inside(a.rect,page.viewportSize()),'Normal menu Campaign action has44CSS visible bounds');
  report.action={id:'campaign',rect:a.rect};await page.touchscreen.tap(a.rect[0]+a.rect[2]/2,a.rect[1]+a.rect[3]/2);
  const initial=await layout('portrait-initial',{width:390,height:844},3);await shot('portrait-390x844');
  await page.setViewportSize({width:844,height:390});const landscape=await layout('landscape',{width:844,height:390},1);await shot('landscape-844x390');
  check(landscape.campaign_store===initial.campaign_store&&JSON.stringify(landscape.economies)===JSON.stringify(initial.economies),'Rotation to landscape preserves exact campaign/economy saved bytes');
  check(JSON.stringify(landscape.c.flags)===JSON.stringify(initial.c.flags),'Rotation to landscape preserves campaign flags');
  await page.setViewportSize({width:390,height:844});const final=await layout('portrait-restored',{width:390,height:844},3);
  check(final.campaign_store===initial.campaign_store&&JSON.stringify(final.economies)===JSON.stringify(initial.economies),'Rotation back preserves exact campaign/economy saved bytes');
  check(JSON.stringify(final.c.flags)===JSON.stringify(initial.c.flags),'Rotation back preserves campaign flags');
  check(report.errors.length===0,'No browser/Godot errors');report.status='passed';report.finished_at=new Date().toISOString();save();console.log(JSON.stringify({engine,status:report.status,checks:report.checks.length,screenshots:report.screenshots.length,rows:report.rotations.map(x=>x.rows)}));
 }catch(e){report.status='failed';report.failure=String(e);try{report.failure_observation=await page.evaluate(()=>({q:window.orafoldQA,c:window.orafoldCampaignQA}));}catch(_){}save();throw e;}
 finally{clearTimeout(deadline);await browser?.close();save();}
}
})().catch(e=>{console.error(e);if(process.exitCode!==2)process.exitCode=1;});
