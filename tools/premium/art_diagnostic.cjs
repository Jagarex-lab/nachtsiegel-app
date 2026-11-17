'use strict';
// Passive real-UI/network diagnostic, explicitly not an acceptance-test pass.
const {chromium,devices}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {clearTouchPoint,encloses}=require('./browser_contract.cjs');
const output=path.resolve(process.env.ART_DIAGNOSTIC_OUTPUT||'work/premium-mobile/art-diagnostic');fs.mkdirSync(output,{recursive:true});
const base=new URL(process.env.GAME_URL||'http://127.0.0.1:8893/');base.searchParams.set('qa','1');
const expected=process.env.EXPECTED_COMMIT;assert(/^[0-9a-f]{40}$/.test(expected||''));
const runs=Number(process.env.ART_DIAGNOSTIC_RUNS||3);assert(Number.isInteger(runs)&&runs>=1&&runs<=5);
const manifest={};for(const file of ['data/production/art_delivery.json','data/production/art_preview_delivery.json'])for(const [id,entry]of Object.entries(JSON.parse(fs.readFileSync(file)).entries))if(entry.relative_url)manifest[new URL(entry.relative_url,base).pathname]={id,...entry};
const summary={diagnostic_only:true,source_commit:expected,physical_device:false,attempts:[]};
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'chromium',args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{for(let attempt=1;attempt<=runs;attempt++){
  const {screen,...phone}=devices['Pixel 7'],context=await browser.newContext({...phone,viewport:{width:390,height:844},deviceScaleFactor:1}),page=await context.newPage();page.setDefaultTimeout(90000);
  const record={attempt,requests:[],observations:[],console:[],outcome:'running'},started=Date.now(),pending=new Set();let phase='boot';
  const q=()=>page.evaluate(()=>window.orafoldQA),save=()=>fs.writeFileSync(path.join(output,'attempt-'+attempt+'.json'),JSON.stringify(record,null,2));
  page.on('console',message=>{if(message.type()==='error')record.console.push(message.text());});page.on('pageerror',error=>record.console.push(String(error)));
  const requests=new Map();
  page.on('request',request=>{const p=new URL(request.url()).pathname;if(!manifest[p])return;const row={path:p,id:manifest[p].id,profile:p.includes('/full/')?'full':'compact',started_ms:Date.now()-started};record.requests.push(row);requests.set(request,row);});
  page.on('requestfailed',request=>{const row=requests.get(request);if(row)Object.assign(row,{failure:request.failure()?.errorText,finished_ms:Date.now()-started});});
  page.on('requestfinished',request=>{const row=requests.get(request);if(!row)return;const work=(async()=>{try{const response=await request.response(),bytes=await response.body();Object.assign(row,{status:response.status(),bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex'),expected_bytes:manifest[row.path].bytes,expected_sha256:manifest[row.path].web_sha256,finished_ms:Date.now()-started});}catch(error){row.body_read_error=String(error);}})();pending.add(work);work.finally(()=>pending.delete(work));});
  const progress=setInterval(async()=>{try{const value=await page.evaluate(()=>({page:window.orafoldQA?.page,inspection:window.orafoldQA?.inspection?.art,delivery:window.orafoldQA?.art_delivery,guard:Array.from(window[Symbol.for('orafold.art.fetch.guard.v2')]?.controllers||[]).map(([url,group])=>({path:new URL(url).pathname,controllers:group.size}))}));record.observations.push({phase,ms:Date.now()-started,...value});save();}catch{}},250);progress.unref();
  async function action(id){
   phase='action:'+id;await page.waitForFunction(id=>window.orafoldQA?.actions?.[id]&&!window.orafoldQA.actions[id].disabled,id);
   for(let trial=0;trial<20;trial++){const state=await q(),a=state.actions[id],v=state.action_visibility?.[id],clip=v?.clip_rect||[0,0,390,844],hit=id.startsWith('card_')&&v?v.visible_rect:a.rect;if(encloses(clip,hit)&&hit[2]>=43.9&&hit[3]>=43.9)break;await page.mouse.move(clip[0]+clip[2]/2,clip[1]+clip[3]/2);await page.mouse.wheel(0,a.rect[1]<clip[1]?-Math.min(240,clip[3]*.7):Math.min(240,clip[3]*.7));await page.waitForTimeout(160);}
   const sample=await page.waitForFunction(s=>{const state=window.orafoldQA;if(!state||state===s.previous)return false;s.previous=state;const a=state.actions[s.id],v=state.action_visibility?.[s.id];if(!a||a.disabled)return false;const r=s.id.startsWith('card_')&&v?v.visible_rect:a.rect;s.count=s.last&&r.every((n,i)=>Math.abs(n-s.last[i])<1)?s.count+1:1;s.last=r;return s.count>=3?{rect:r,render:state.render_version,modal:state.modal_version}:false;},{id,previous:null,last:null,count:0});
   let ready;try{ready=await sample.jsonValue();}finally{await sample.dispose();}const point=clearTouchPoint(ready.rect);assert(point);await page.touchscreen.tap(point[0],point[1]);await page.waitForFunction(s=>window.orafoldQA.render_version>s.render||window.orafoldQA.modal_version!==s.modal,ready);
  }
  try{
   const info=await(await page.request.get(new URL('build-info.json',base).href)).json();assert.equal(info.commit,expected);
   await page.goto(base.href,{waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.orafoldQA?.page==='lobby');await action('collection');await page.waitForFunction(()=>window.orafoldQA.library_total===550);
   const id=Object.keys((await q()).actions).find(key=>key.startsWith('card_'));record.card_id=id.slice(5);record.before_inspection=await q();await action(id);phase='wait-full-art';
   await page.waitForFunction(()=>['ready','failed'].includes(window.orafoldQA?.inspection?.art?.state),undefined,{timeout:30000});
   await page.waitForTimeout(400);record.final=await q();record.outcome=record.final.inspection.art.state;
   await page.screenshot({path:path.join(output,'attempt-'+attempt+'-'+record.outcome+'.png'),timeout:30000});
  }catch(error){record.outcome='diagnostic-error';record.error=String(error);record.final=await q().catch(()=>null);}
  finally{clearInterval(progress);await Promise.allSettled([...pending]);save();summary.attempts.push({attempt,outcome:record.outcome,card_id:record.card_id});await context.close();fs.writeFileSync(path.join(output,'summary.json'),JSON.stringify(summary,null,2));}
 }}finally{await browser.close();}
 console.log(JSON.stringify(summary,null,2));
})().catch(error=>{console.error(error);process.exitCode=1;});
