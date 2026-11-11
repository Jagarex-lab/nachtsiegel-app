'use strict';
// Evaluate the exact embedded Web guard. Actual network behavior is checked by
// browser_art_delivery_qa.cjs, not established by this function-boundary fixture.
const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const source=fs.readFileSync(path.join(__dirname,'../scripts/production/art_delivery.gd'),'utf8');
const install=source.match(/const WEB_FETCH_GUARD := """([\s\S]*?)"""/)[1];
const release=source.match(/const WEB_FETCH_RELEASE := """([\s\S]*?)"""/)[1];
const prefix='https://art.example.test/game/art/';
function fixture(transport=null){
 const calls=[];
 const original=function(resource,options){calls.push({resource,options});return transport ? transport(resource,options) : Promise.resolve({status:200});};
 const window={location:{href:'https://art.example.test/game/?qa=1',origin:'https://art.example.test'},fetch:original};
 const context=vm.createContext({window,URL,Symbol,Map,Set,Array,AbortController,Response,ReadableStream});
 const run=code=>vm.runInContext(code.replaceAll('__ART_PREFIX__',JSON.stringify(prefix)),context);
 return {calls,original,window,run};
}
test('own same-origin art refuses redirects without mutating caller options',async()=>{
 const f=fixture();assert.equal(f.run(install),true);
 const options={method:'GET',headers:{'X-Fixture':'present'}};
 await f.window.fetch(prefix+'full/'+'a'.repeat(64)+'.webp',options);
 const actual=f.calls[0].options;
 assert.equal(actual.redirect,'error');assert.equal(actual.mode,'same-origin');assert.equal(actual.credentials,'omit');
 assert.equal(actual.headers,options.headers);assert.equal(actual.method,'GET');
 assert.equal(options.redirect,undefined);assert.equal(options.mode,undefined);
});
test('unrelated engine and cross-origin calls preserve their original options',async()=>{
 const f=fixture();f.run(install);
 const options={method:'GET',credentials:'same-origin'};
 for(const url of ['https://art.example.test/game/orafold.wasm','https://art.example.test/game/orafold.pck','https://other.example.test/game/art/full/a.webp'])await f.window.fetch(url,options);
 assert.equal(f.calls.length,3);for(const call of f.calls)assert.equal(call.options,options);
});
test('relative art URLs and Request-shaped inputs receive the same guard',async()=>{
 const f=fixture();f.run(install);
 await f.window.fetch('art/full/a.webp');
 await f.window.fetch({url:prefix+'preview/b.webp'},{method:'GET'});
 assert.equal(f.calls[0].options.redirect,'error');assert.equal(f.calls[1].options.redirect,'error');
});
test('multiple installs release independently, abort owned work and restore original fetch',async()=>{
 const f=fixture();f.run(install);const wrapper=f.window.fetch;f.run(install);
 await f.window.fetch(prefix+'preview/a.webp');
 const signal=f.calls[0].options.signal;
 assert.equal(f.window.fetch,wrapper);f.run(release);assert.equal(f.window.fetch,wrapper);assert.equal(signal.aborted,false);
 f.run(release);assert.equal(f.window.fetch,f.original);
 assert.equal(signal.aborted,true);
 assert.equal(f.window[Symbol.for('orafold.art.fetch.guard.v2')],undefined);
 f.run(release);assert.equal(f.window.fetch,f.original);
});
test('per-URL completion drops controllers and cancellation aborts only its image',async()=>{
 const f=fixture();f.run(install);
 const first=prefix+'preview/a.webp',second=prefix+'full/b.webp';
 await f.window.fetch(first);await f.window.fetch(second);
 const guard=f.window[Symbol.for('orafold.art.fetch.guard.v2')];
 assert.equal(guard.controllers.size,2);
 guard.finish(first,true);assert.equal(f.calls[0].options.signal.aborted,true);assert.equal(f.calls[1].options.signal.aborted,false);
 guard.finish(second,false);assert.equal(guard.controllers.size,0);assert.equal(f.calls[1].options.signal.aborted,false);
 f.run(release);
});

test('owner cancellation before headers settles as empty failure without rejecting the freed engine request',async()=>{
 const f=fixture((_resource,options)=>new Promise((_resolve,reject)=>options.signal.addEventListener('abort',()=>reject(options.signal.reason),{once:true})));
 f.run(install);const url=prefix+'preview/slow-before-headers.webp',pending=f.window.fetch(url);
 f.window[Symbol.for('orafold.art.fetch.guard.v2')].finish(url,true);
 const response=await pending;
 assert.equal(response.status,499);assert.equal(response.ok,false);assert.equal((await response.arrayBuffer()).byteLength,0);
 assert.equal(f.calls[0].options.signal.aborted,true);assert.equal(f.window[Symbol.for('orafold.art.fetch.guard.v2')].controllers.size,0);
});
test('owner cancellation during streamed body closes the outstanding reader without logging an abort rejection',async()=>{
 const f=fixture((_resource,options)=>Promise.resolve(new Response(new ReadableStream({start(stream){
  stream.enqueue(new Uint8Array([11,22,33]));options.signal.addEventListener('abort',()=>stream.error(options.signal.reason),{once:true});
 }}),{status:200,headers:{'Content-Type':'image/webp'}})));
 f.run(install);const url=prefix+'preview/slow-body.webp',response=await f.window.fetch(url),reader=response.body.getReader();
 assert.deepEqual(Array.from((await reader.read()).value),[11,22,33]);
 const pending=reader.read();f.window[Symbol.for('orafold.art.fetch.guard.v2')].finish(url,true);
 assert.deepEqual(await pending,{done:true,value:undefined});assert.equal(f.calls[0].options.signal.aborted,true);
});
test('genuine fetch failures and body failures still reject without an owner cancellation',async()=>{
 const networkError=new Error('actual network failure'),f=fixture(()=>Promise.reject(networkError));f.run(install);
 await assert.rejects(f.window.fetch(prefix+'full/network.webp'),error=>error===networkError);
 const bodyError=new Error('actual body failure'),g=fixture(()=>Promise.resolve(new Response(new ReadableStream({start(stream){stream.error(bodyError);}}),{status:200})));g.run(install);
 const response=await g.window.fetch(prefix+'preview/broken-body.webp');
 await assert.rejects(response.arrayBuffer(),error=>error===bodyError);
});
