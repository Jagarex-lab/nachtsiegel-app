'use strict';
// Visible browser input and actual exported files. Browser profiles are
// simulations; these checks do not establish physical iPhone memory/latency.
const {chromium,webkit}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const http=require('node:http');
const crypto=require('node:crypto');
const ROOT=path.resolve(__dirname,'../..');
const BUILD=path.resolve(ROOT,process.env.ART_WEB_BUILD||'work/alpha/web');
const OUTPUT=path.resolve(ROOT,process.env.ART_BROWSER_OUTPUT||'work/production-art/browser');
const manifest=JSON.parse(fs.readFileSync(path.join(BUILD,'art-delivery.json'),'utf8'));
const cards=JSON.parse(fs.readFileSync(path.join(ROOT,'data/production/cards.json'),'utf8')).cards;
const card=cards.find(value=>value.id==='of-houses-020');
const expected=manifest.entries[card.id];
const requests=[];
const previewRequests=[];
const previewManifest=JSON.parse(fs.readFileSync(path.join(BUILD,'art-preview-delivery.json'),'utf8'));
const compactExpected=previewManifest.entries[card.id];
const sha=body=>crypto.createHash('sha256').update(body).digest('hex');
const mime={'.html':'text/html; charset=utf-8','.js':'application/javascript','.json':'application/json','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png','.webp':'image/webp'};
fs.mkdirSync(OUTPUT,{recursive:true});
async function serve(request,response){
 try{
  const match=new URL(request.url,'http://localhost').pathname.match(/^\/orafold-delivery\/(success|offline|corrupt|redirect|oversized)\/(.*)$/);
  if(!match){response.writeHead(404);response.end();return;}
  const [,scenario,raw]=match,relative=decodeURIComponent(raw||'index.html');
  const filename=path.resolve(BUILD,relative);
  if(!filename.startsWith(BUILD+path.sep)||fs.lstatSync(filename,{throwIfNoEntry:false})?.isSymbolicLink()){response.writeHead(403);response.end();return;}
  if(!fs.statSync(filename,{throwIfNoEntry:false})?.isFile()){response.writeHead(404);response.end();return;}
  let body=fs.readFileSync(filename),status=200;
  if(relative.startsWith('art/preview/')){previewRequests.push({scenario,relative,status,bytes:body.length,sha256:sha(body)});await new Promise(resolve=>setTimeout(resolve,1200));}
  if(relative.startsWith('art/full/')){
   if(scenario==='offline'){status=404;body=Buffer.from('deliberately unavailable external full illustration');}
   else if(scenario==='corrupt'){body=Buffer.from(body);body[Math.floor(body.length/2)]^=1;}
   else if(scenario==='redirect'){status=302;body=Buffer.from('deliberately refused full-art redirect');}
   else if(scenario==='oversized'){body=Buffer.alloc(8*1024*1024+1);}
   requests.push({scenario,relative,status,bytes:body.length,sha256:sha(body)});
   // Make the actual immediate preview observable before the real response.
   await new Promise(resolve=>setTimeout(resolve,1200));
  }
  response.writeHead(status,{'Content-Type':mime[path.extname(filename)]||'application/octet-stream','Content-Length':body.length,'Cache-Control':'no-store','Cross-Origin-Opener-Policy':'same-origin','Cross-Origin-Embedder-Policy':'require-corp',...(status===302?{'Location':'/orafold-delivery/success/'+expected.relative_url}:{})});
  response.end(body);
 }catch(error){response.writeHead(500);response.end(String(error));}
}
async function run(engine,base,scenario){
 const browser=await (engine==='webkit'?webkit:chromium).launch({headless:true,...(engine==='chromium'?{channel:'chromium',args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']}:{})});
 let page,assertions=0;
 const errors=[],consoleErrors=[],browserArtURLs=[],pageErrorRecords=[],expectedNetworkErrors=[];
 const check=(value,label)=>{assertions++;assert(value,label);};
 const equal=(actual,wanted,label)=>{assertions++;assert.deepEqual(actual,wanted,label);};
 try{
  const context=await browser.newContext({viewport:{width:1280,height:900},hasTouch:true,deviceScaleFactor:1});
  page=await context.newPage();page.setDefaultTimeout(120000);
  page.on('pageerror',error=>{
   const record={message:String(error),stack:String(error.stack||''),name:String(error.name||'')};
   pageErrorRecords.push(record);
   // WebKit reports a deliberately blocked native fetch as a pageerror even
   // when Godot handles its rejection. Accept only this exact native message
   // and a message-only stack; actual JS frames and every other error fail.
   const normalize=value=>value.replace('http: /','http://');
   const wanted='Fetch API cannot load '+base+'orafold-delivery/redirect/'+expected.relative_url+' due to access control checks.';
   const nativeStack=!record.stack||normalize(record.stack.replace(/^Error:\s*/, '').trim())===wanted;
   if(engine==='webkit'&&scenario==='redirect'&&normalize(record.message)===wanted&&nativeStack)expectedNetworkErrors.push(record);
   else errors.push(record);
  });
  await page.addInitScript(()=>{
   window.__orafoldArtUnhandledRejections=[];
   window.addEventListener('unhandledrejection',event=>window.__orafoldArtUnhandledRejections.push({message:String(event.reason),stack:String(event.reason?.stack||'')}));
  });
  page.on('console',message=>{if(message.type()==='error')consoleErrors.push(message.text());});
  page.on('request',request=>{if(new URL(request.url()).pathname.includes('/art/full/'))browserArtURLs.push(request.url());});
  const q=()=>page.evaluate(()=>window.orafoldQA);
  const wait=(fn,arg)=>page.waitForFunction(fn,arg,{timeout:120000});
  async function tap(id,render=true){
   await wait(key=>{const action=window.orafoldQA?.actions?.[key];return action&&!action.disabled;},id);
   const before=await q(),rect=before.actions[id].rect;
   check(rect[2]>=43.9&&rect[3]>=43.9&&rect[0]>=0&&rect[1]>=0&&rect[0]+rect[2]<=1281&&rect[1]+rect[3]<=901,id+' actual visible touch action');
   await page.touchscreen.tap(rect[0]+rect[2]/2,rect[1]+rect[3]/2);
   if(render)await wait(old=>window.orafoldQA.render_version>old.render_version||window.orafoldQA.modal_version!==old.modal_version,before);
  }
  const url=base+'orafold-delivery/'+scenario+'/?qa=1';
  await page.goto(url,{waitUntil:'networkidle'});await wait(()=>window.orafoldQA?.page==='lobby');
  const starts=requests.filter(row=>row.scenario===scenario).length;
  equal(starts,0,'initial Web PCK/lobby does not fetch any full art');
  await tap('collection');
  await tap('search',false);await page.keyboard.insertText(card.name);await tap('search_apply');
  await wait(id=>window.orafoldQA.library_visible_ids.includes(id),card.id);
  await wait(id=>window.orafoldQA.library_art?.[id]?.state==='ready',card.id);
  equal((await q()).library_art[card.id].pixels,[compactExpected.width,compactExpected.height],'visible compact card actually receives the external preview pixels');
  equal(requests.filter(row=>row.scenario===scenario).length,0,'actual compact collection/search starts no full-art HTTP');
  const before=await q();await tap('card_'+card.id);
  await wait(()=>window.orafoldQA.inspection?.art?.preview_only===true);
  const preview=await q();equal(preview.inspection.art.pixels,[512,384],'inspector immediately draws actual verified compact preview pixels');
  equal(preview.deck_ids,before.deck_ids,'opening read-only inspector preserves the deck');
  await wait(wanted=>window.orafoldQA.inspection?.art?.state===wanted,scenario==='success'?'ready':'failed');
  const after=await q();
  equal(after.inspection.art.preview_only,scenario!=='success','verified full replaces preview only after success');
  equal(after.inspection.art.pixels,scenario==='success'?[1448,1086]:[512,384],'actual result uses honest native/preview dimensions');
  equal(after.inspection.id,card.id,'real visible inspector retains its card identity');
  // The QA state is rebuilt before the canvas compositor has necessarily
  // painted it. Settle actual browser paint before native screenshot readback.
  await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
  await page.waitForTimeout(180);
  const screenshot=await page.screenshot({timeout:45000});
  equal([screenshot.readUInt32BE(16),screenshot.readUInt32BE(20)],[1280,900],'screenshot retains the actual native viewport');
  check(screenshot.length>20000,'native screenshot contains rendered content');
  fs.writeFileSync(path.join(OUTPUT,engine+'-'+scenario+'.png'),screenshot);
  const compactRows=previewRequests.filter(row=>row.scenario===scenario&&row.relative===compactExpected.relative_url);
  check(compactRows.length>=1&&compactRows.every(row=>row.sha256===compactExpected.web_sha256),'real visible compact requests use unchanged content-addressed WebP bytes');
  const rows=requests.filter(row=>row.scenario===scenario);
  equal(rows.length,1,'one actual request despite repeated inspector redraw/quality updates');
  equal(rows[0].relative,expected.relative_url,'actual same-origin request uses content-addressed manifest path');
  equal(browserArtURLs.length,1,'browser itself emitted exactly one external-art request');
  equal(new URL(browserArtURLs[0]).origin,new URL(url).origin,'full-art HTTP remains on the document origin');
  equal(new URL(browserArtURLs[0]).pathname,'/orafold-delivery/'+scenario+'/'+expected.relative_url,'full-art URL retains the deployed site subdirectory');
  if(scenario==='success')equal(rows[0].sha256,expected.web_sha256,'server actually supplied original verified WebP bytes');
  if(scenario==='corrupt'){equal(rows[0].bytes,expected.bytes,'corrupt HTTP body preserves expected length');check(rows[0].sha256!==expected.web_sha256,'real corrupt response has wrong SHA');}
  if(scenario==='offline')equal(rows[0].status,404,'offline fixture really responds 404');
  if(scenario==='redirect'){
   equal(rows[0].status,302,'redirect fixture really responds 302');
   equal(requests.filter(row=>row.scenario==='success').length,0,'Web fetch refuses redirect before any redirected asset request');
  }
  if(scenario==='oversized')check(rows[0].bytes>8*1024*1024,'actual Web response exceeds enforced body limit');
  await tap('modal_close');
  equal((await q()).deck_ids,before.deck_ids,'closing inspector preserves deck');
  if(scenario==='success'){
   const uncached=cards.find(candidate=>previewManifest.entries[candidate.id]?.delivery==='external'&&!previewRequests.some(row=>row.relative===previewManifest.entries[candidate.id].relative_url));
   check(!!uncached,'a genuine not-yet-fetched compact card exists for cancellation');
   await tap('search',false);await page.keyboard.press('ControlOrMeta+A');await page.keyboard.insertText(uncached.name);await tap('search_apply');
   await wait(id=>window.orafoldQA.art_delivery?.active==='compact|'+id,uncached.id);
   const prior=await q();await tap('builder_back');await wait(()=>window.orafoldQA.page==='lobby');
   await wait(count=>window.orafoldQA.art_delivery.cancelled>count&&window.orafoldQA.art_delivery.active===''&&window.orafoldQA.art_delivery.queued===0,prior.art_delivery.cancelled);
   equal((await q()).deck_ids,before.deck_ids,'leaving a real pending compact request preserves deck state');
   await tap('collection');await tap('search',false);await page.keyboard.insertText(uncached.name);await tap('search_apply');
   await wait(id=>window.orafoldQA.library_art?.[id]?.state==='ready',uncached.id);
   equal((await q()).library_art[uncached.id].pixels,[previewManifest.entries[uncached.id].width,previewManifest.entries[uncached.id].height],'returning to a cancelled real card resumes and displays its compact image');
   equal(requests.filter(row=>row.scenario===scenario).length,1,'compact cancellation/resumption never requests another full illustration');
  }

  const unhandledRejections=await page.evaluate(()=>window.__orafoldArtUnhandledRejections);
  equal(unhandledRejections,[],'no unhandled promise rejections, including intentional fetch failures');
  equal(errors,[],'no unexpected browser script exceptions');
  check(!consoleErrors.some(value=>/SCRIPT ERROR|Parse Error|Compile Error|resources still in use|instances leaked/.test(value)),'no Godot script/resource errors');
  const result={engine,scenario,assertions,failures:0,browser_version:browser.version(),playwright:require('playwright/package.json').version,build_info:JSON.parse(fs.readFileSync(path.join(BUILD,'build-info.json'),'utf8')),preview:preview.inspection.art,result:after.inspection.art,requests:rows,preview_requests:previewRequests.filter(row=>row.scenario===scenario),browser_art_urls:browserArtURLs,console_errors:consoleErrors,page_error_records:pageErrorRecords,expected_network_errors:expectedNetworkErrors,unhandled_rejections:unhandledRejections,simulated:true,real_device:false};
  fs.writeFileSync(path.join(OUTPUT,engine+'-'+scenario+'.json'),JSON.stringify(result,null,2));
  console.log('ART BROWSER',engine,scenario,assertions,'assertions, 0 failures');
  return result;
 }catch(error){
  fs.writeFileSync(path.join(OUTPUT,engine+'-'+scenario+'-failure.json'),JSON.stringify({error:String(error),assertions,errors,consoleErrors,pageErrorRecords,expectedNetworkErrors,unhandledRejections:page?await page.evaluate(()=>window.__orafoldArtUnhandledRejections).catch(()=>null):null,qa:page?await page.evaluate(()=>window.orafoldQA).catch(()=>null):null},null,2));throw error;
 }finally{await browser.close();}
}
(async()=>{
 const server=http.createServer(serve);await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 try{
  const results=[];
  const engines=(process.env.QA_ENGINES||'chromium,webkit').split(','),scenarios=(process.env.ART_SCENARIOS||'success,offline,corrupt,redirect,oversized').split(',');
  for(const engine of engines)assert(['chromium','webkit'].includes(engine),'unsupported browser engine');
  for(const scenario of scenarios)assert(['success','offline','corrupt','redirect','oversized'].includes(scenario),'unsupported art scenario');
  for(const engine of engines)for(const scenario of scenarios){
   requests.length=0;previewRequests.length=0;results.push(await run(engine,'http://127.0.0.1:'+server.address().port+'/',scenario));
  }
  fs.writeFileSync(path.join(OUTPUT,'results.json'),JSON.stringify({results,engines,scenarios,assertions:results.reduce((sum,row)=>sum+row.assertions,0),failures:0,scope:'Only the listed actual exported Web PCK scenarios, same-origin HTTP and visible browser input; simulated browsers, no physical device claim'},null,2));
 }finally{await new Promise(resolve=>server.close(resolve));}
})().catch(error=>{console.error(error);process.exitCode=1;});
