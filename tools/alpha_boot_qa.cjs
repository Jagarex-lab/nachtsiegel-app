'use strict';
// Regression for observed WASM startup traps: fresh process/origin state per boot.
const {webkit,devices}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
(async()=>{
 const results=[],count=Number(process.env.QA_BOOT_COUNT||6);
 assert(Number.isInteger(count)&&count>0&&count<=30);
 const targets=[{mode:'alpha',url:process.env.GAME_URL||'http://127.0.0.1:8788/'}];
 if(process.env.ARCHIVE_URL)targets.push({mode:'archive',url:process.env.ARCHIVE_URL});
 for(let i=0;i<count;i++){
  const t=targets[i%targets.length],url=new URL(t.url);url.searchParams.set('qa','1');
  const browser=await webkit.launch({headless:true}),started=Date.now(),errors=[];
  try{
   const context=await browser.newContext({...devices['iPhone 13'],viewport:{width:844,height:390},deviceScaleFactor:3}),page=await context.newPage();
   page.on('pageerror',e=>errors.push(e.stack||String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
   if(process.env.EXPECTED_COMMIT){const info=await page.request.get(new URL('build-info.json',url).href);assert.equal((await info.json()).commit,process.env.EXPECTED_COMMIT);}
   await page.goto(url.href,{waitUntil:'networkidle'});
   await page.waitForFunction(()=>window.orafoldQA?.page==='lobby'||window.nachtsiegelHub?.page==='start'||/out of bounds|null reference/i.test(document.querySelector('#status')?.textContent||''),undefined,{timeout:90000});
   const state=await page.evaluate(()=>({alpha:window.orafoldQA?.page,archive:window.nachtsiegelHub?.page,status:document.querySelector('#status')?.textContent||''}));
   assert.equal(errors.length,0,JSON.stringify({errors,state}));assert.equal(state[t.mode],t.mode==='alpha'?'lobby':'start');
   results.push({iteration:i,mode:t.mode,runtime:browser.version(),playwright:require('playwright/package.json').version,source_commit:process.env.EXPECTED_COMMIT,elapsed_ms:Date.now()-started,errors});
   console.log('COLD BOOT PASS',i,t.mode,browser.version());await context.close();
  }finally{await browser.close();}
 }
 fs.writeFileSync('work/alpha/cold-boot-results.json',JSON.stringify(results,null,2));console.log(`COLD BOOT: ${results.length} fresh WebKit processes, 0 failures`);
})().catch(e=>{console.error(e);process.exit(1)});
