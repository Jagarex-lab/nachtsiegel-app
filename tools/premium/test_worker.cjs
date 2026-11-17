'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync('web/pwa/service-worker.js','utf8');
const origin='https://jagarex-lab.github.io',scope=origin+'/nachtsiegel-app/';
function environment(options={}) {
 const listeners={},calls=[],cacheCalls=[],mutations=[];
 const cached={kind:'cached branding'},fresh={kind:'actual network response'};
 const self={registration:{scope},location:{origin},addEventListener:(name,handler)=>{listeners[name]=handler;},
  skipWaiting:async()=>{mutations.push('skipWaiting');},clients:{claim:async()=>{mutations.push('claim');}}};
 const caches={
  open:async name=>{cacheCalls.push(['open',name]);return {
   addAll:async names=>{cacheCalls.push(['addAll',names]);},
   match:async request=>{cacheCalls.push(['match',request.url]);return options.brandMiss?undefined:cached;}
  };},
  keys:async()=>['orafold-brand-old','orafold-brand-'+'a'.repeat(40),'another-app-cache'],
  delete:async name=>{cacheCalls.push(['delete',name]);}
 };
 const fetch=async(request,init)=>{
  calls.push({request,init});
  if(options.networkFailure)throw new Error('Network unavailable');
  return fresh;
 };
 vm.runInNewContext(source.replaceAll('__COMMIT__','a'.repeat(40)),{self,caches,fetch,URL});
 function request(path,{method='GET',mode='cors'}={}) {
  let response;
  const input={url:new URL(path,scope).href,method,mode};
  listeners.fetch({request:input,respondWith:value=>{assert.equal(response,undefined,'respondWith exactly once');response=value;}});
  return {input,response};
 }
 return {listeners,request,calls,cacheCalls,mutations,cached,fresh};
}
test('same-scope navigation fetches the actual request with no-store',async()=>{
 const e=environment();
 for(const path of ['./','./?qa=1','./index.html?release=abc']) {
  const {input,response}=e.request(path,{mode:'navigate'});
  assert.equal(await response,e.fresh);assert.equal(e.calls.at(-1).request,input);
  assert.equal(e.calls.at(-1).init.cache,'no-store');
 }
 assert.deepEqual(e.cacheCalls,[],'HTML is never cached or read from Cache Storage');
});
test('build metadata bypasses cache with and without a commit query',async()=>{
 const e=environment();
 for(const path of ['./build-info.json','./build-info.json?release='+'a'.repeat(40)]) {
  const {response}=e.request(path);assert.equal(await response,e.fresh);
  assert.equal(e.calls.at(-1).init.cache,'no-store');
 }
 assert.deepEqual(e.cacheCalls,[]);
});
test('fingerprinted Godot resources and all illustrations retain browser delivery',()=>{
 const e=environment();
 for(const path of ['./orafold-aaaaaaaaaaaa.wasm','./orafold-aaaaaaaaaaaa.pck','./orafold-aaaaaaaaaaaa.js','./illustrations/card-42.webp','./manifest.webmanifest']) {
  assert.equal(e.request(path).response,undefined,path+' is not intercepted');
 }
 assert.deepEqual(e.calls,[]);assert.deepEqual(e.cacheCalls,[]);
});
test('foreign origins, neighbouring scopes and non-GET requests are untouched',()=>{
 const e=environment();
 for(const path of ['https://example.org/nachtsiegel-app/','https://jagarex-lab.github.io/another-game/','https://jagarex-lab.github.io/nachtsiegel-app-archive/']) {
  assert.equal(e.request(path,{mode:'navigate'}).response,undefined);
 }
 assert.equal(e.request('./build-info.json',{method:'POST'}).response,undefined);
 assert.equal(e.request('./',{method:'HEAD',mode:'navigate'}).response,undefined);
 assert.deepEqual(e.calls,[]);assert.deepEqual(e.cacheCalls,[]);
});
test('branding stays in the tiny cache and a miss uses the network',async()=>{
 const hit=environment();
 assert.equal(await hit.request('./app-icon-192.png').response,hit.cached);
 assert.deepEqual(hit.calls,[]);
 const miss=environment({brandMiss:true});
 assert.equal(await miss.request('./apple-touch-icon.png').response,miss.fresh);
 assert.equal(miss.calls.length,1);assert.equal(miss.calls[0].init,undefined);
});
test('install and activation touch only own branding caches',async()=>{
 const e=environment();
 let install,activate;
 e.listeners.install({waitUntil:promise=>{install=promise;}});await install;
 const batch=e.cacheCalls.find(call=>call[0]==='addAll')[1];
 assert.equal(batch.length,3);assert(batch.every(path=>path.endsWith('.png')));
 e.listeners.activate({waitUntil:promise=>{activate=promise;}});await activate;
 const deleted=e.cacheCalls.filter(call=>call[0]==='delete').map(call=>call[1]);
 assert.deepEqual(deleted,['orafold-brand-old']);
 assert.deepEqual(e.mutations,['skipWaiting','claim']);
});
test('network errors reject only the requested navigation or metadata fetch',async()=>{
 const e=environment({networkFailure:true});
 for(const [path,mode]of [['./','navigate'],['./build-info.json','cors']]) {
  await assert.rejects(e.request(path,{mode}).response,/Network unavailable/);
 }
 assert.deepEqual(e.cacheCalls,[],'no stale HTML fallback');
 assert.deepEqual(e.mutations,[],'no running client is reloaded, closed or messaged');
 // A resource fetch for an already running game remains outside this worker.
 assert.equal(e.request('./orafold-aaaaaaaaaaaa.pck').response,undefined);
});
