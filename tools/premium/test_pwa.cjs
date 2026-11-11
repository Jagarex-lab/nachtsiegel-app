'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const cp=require('node:child_process');
const source=fs.readFileSync('web/pwa/app-mode.js','utf8');
function environment(options={}) {
 const window=new EventTarget(),document=new EventTarget(),media=new EventTarget();
 let registered=[];
 media.matches=!!options.standalone;
 Object.assign(window,{matchMedia:()=>media,isSecureContext:options.secure!==false});
 Object.assign(document,{fullscreenEnabled:options.supported!==false,fullscreenElement:null,querySelector:()=>options.worker?{content:options.worker}:null,documentElement:{}});
 if(options.supported!==false)document.documentElement.requestFullscreen=async()=>{if(options.denied)throw Error('denied');document.fullscreenElement=document.documentElement;document.dispatchEvent(new Event('fullscreenchange'));};
 document.exitFullscreen=async()=>{document.fullscreenElement=null;document.dispatchEvent(new Event('fullscreenchange'));};
 const navigator={userAgent:options.ios?'iPhone Safari':'Chromium',platform:options.ipad?'MacIntel':'Linux',maxTouchPoints:options.ipad?5:0};
 if(options.worker)navigator.serviceWorker={register:async(...args)=>{registered.push(args);return {update:async()=>{}};}};
 vm.runInNewContext(source,{window,document,navigator,Event,console});
 return {window,document,navigator,media,registered,app:window.orafoldApp};
}
test('reviewed Safari viewport bridge remains byte-identical',()=>{
 const before=cp.execFileSync('git',['show','10782185cf41f2013607ba47da0bbfcb737e89e2:web/shell.html'],{encoding:'utf8'});
 const after=fs.readFileSync('web/shell.html','utf8');
 const block=s=>s.match(/\/\/ ORAFOLD_VIEWPORT_BEGIN[\s\S]*?\/\/ ORAFOLD_VIEWPORT_END/)[0];
 assert.equal(block(after),block(before));
 assert.ok(after.includes(source));
});
test('fullscreen toggle enters and leaves browser fullscreen',async()=>{
 const {app}=environment();assert.equal(app.state().fullscreen,false);
 await app.toggleFullscreen();assert.equal(app.state().fullscreen,true);
 await app.toggleFullscreen();assert.equal(app.state().fullscreen,false);
});
test('denied fullscreen is non-blocking and explained',async()=>{
 const {app}=environment({denied:true});await app.toggleFullscreen();
 assert.equal(app.state().fullscreen,false);assert.match(app.state().status,/nicht freigegeben/);
});
test('iPhone unsupported fullscreen offers real installation instructions',async()=>{
 const {app}=environment({ios:true,supported:false});await app.toggleFullscreen();
 assert.equal(app.state().ios,true);assert.match(app.state().status,/Home-Bildschirm/);
 assert.equal(app.state().fullscreen,false);
});
test('iPadOS desktop UA and standalone app state are recognized',()=>{
 const {app}=environment({ipad:true,standalone:true});assert.equal(app.state().ios,true);assert.equal(app.state().standalone,true);
});
test('install prompt requires browser offer, may be cancelled, and is single-use',async()=>{
 const {app,window}=environment();let calls=0;
 const event=new Event('beforeinstallprompt',{cancelable:true});
 event.prompt=async()=>{calls++;};event.userChoice=Promise.resolve({outcome:'dismissed'});
 window.dispatchEvent(event);assert.equal(event.defaultPrevented,true);assert.equal(app.state().installAvailable,true);
 await app.install();assert.equal(calls,1);assert.equal(app.state().installAvailable,false);assert.match(app.state().status,/abgebrochen/);
 await app.install();assert.equal(calls,1);
});
test('service worker is opt-in for staged secure Alpha exports only',async()=>{
 const missing=environment();missing.window.dispatchEvent(new Event('load'));assert.equal(missing.registered.length,0);
 const insecure=environment({worker:'./worker.js',secure:false});insecure.window.dispatchEvent(new Event('load'));assert.equal(insecure.registered.length,0);
 const ready=environment({worker:'./worker.js'});ready.window.dispatchEvent(new Event('load'));await new Promise(setImmediate);
 assert.equal(ready.registered.length,1);assert.equal(ready.registered[0][0],'./worker.js');assert.equal(ready.registered[0][1].updateViaCache,'none');
});
