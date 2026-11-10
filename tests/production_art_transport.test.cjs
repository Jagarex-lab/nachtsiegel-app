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
const prefix='https://art.example.test/game/art/full/';
function fixture(){
 const calls=[];
 const original=function(resource,options){calls.push({resource,options});return Promise.resolve({status:200});};
 const window={location:{href:'https://art.example.test/game/?qa=1',origin:'https://art.example.test'},fetch:original};
 const context=vm.createContext({window,URL,Symbol,Map,Array});
 const run=code=>vm.runInContext(code.replaceAll('__ART_PREFIX__',JSON.stringify(prefix)),context);
 return {calls,original,window,run};
}
test('own same-origin art refuses redirects without mutating caller options',async()=>{
 const f=fixture();assert.equal(f.run(install),true);
 const options={method:'GET',headers:{'X-Fixture':'present'}};
 await f.window.fetch(prefix+'a'.repeat(64)+'.webp',options);
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
 await f.window.fetch({url:prefix+'b.webp'},{method:'GET'});
 assert.equal(f.calls[0].options.redirect,'error');assert.equal(f.calls[1].options.redirect,'error');
});
test('multiple installs release independently and restore original fetch',()=>{
 const f=fixture();f.run(install);const wrapper=f.window.fetch;f.run(install);
 assert.equal(f.window.fetch,wrapper);f.run(release);assert.equal(f.window.fetch,wrapper);
 f.run(release);assert.equal(f.window.fetch,f.original);
 assert.equal(f.window[Symbol.for('orafold.art.fetch.guard.v1')],undefined);
 f.run(release);assert.equal(f.window.fetch,f.original);
});
