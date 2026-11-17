'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),http=require('node:http'),crypto=require('node:crypto');
const {requiredFiles,verifyExecutables}=require('../../tools/release/public_integrity.cjs');
const sha=value=>crypto.createHash('sha256').update(value).digest('hex');
async function server(run){
 const bodies={'index.html':'<html>exact candidate</html>','build-info.json':'{"commit":"candidate"}','orafold-a.js':'exact entry script','orafold-a.pck':'exact packed game','orafold-a.wasm':'exact executable','manifest.webmanifest':'{"display":"standalone"}'};
 const app=http.createServer((request,response)=>{const name=new URL(request.url,'http://localhost').pathname.slice(1);if(name==='redirect.js'){response.writeHead(302,{Location:'/index.html'});return response.end();}if(!Object.hasOwn(bodies,name)){response.writeHead(404);return response.end('missing');}response.end(bodies[name]);});
 await new Promise(resolve=>app.listen(0,'127.0.0.1',resolve));
 const candidate={schema:1,commit:'a'.repeat(40),public_url:`http://127.0.0.1:${app.address().port}/`};
 const evidence={schema:1,candidate,files:Object.fromEntries(Object.entries(bodies).map(([name,bytes])=>[name,sha(bytes)]))};
 try{await run({bodies,candidate,evidence});}finally{await new Promise(resolve=>app.close(resolve));}
}
test('actual HTTP executable bytes all match the exact provenance',async()=>server(async({candidate,evidence})=>{const files=await verifyExecutables(candidate,evidence);assert.equal(files.length,6);assert(files.every(file=>file.bytes>0&&file.sha256===evidence.files[file.file]));}));
test('stale index with fresh metadata cannot pass the public probe',async()=>server(async({bodies,candidate,evidence})=>{bodies['index.html']='<html>old release</html>';await assert.rejects(verifyExecutables(candidate,evidence),/SHA256: index.html/);}));
test('stale PCK, WASM and entry JS are each rejected',async()=>{for(const name of ['orafold-a.pck','orafold-a.wasm','orafold-a.js'])await server(async({bodies,candidate,evidence})=>{bodies[name]='wrong revision';await assert.rejects(verifyExecutables(candidate,evidence),new RegExp('SHA256: '+name.replaceAll('.','\\.')));});});
test('missing executable and oversized responses fail closed',async()=>server(async({bodies,candidate,evidence})=>{delete bodies['orafold-a.pck'];await assert.rejects(verifyExecutables(candidate,evidence),/fetch succeeds/);bodies['orafold-a.pck']='exact packed game';await assert.rejects(verifyExecutables(candidate,evidence,{maxBytes:3}),/size bound/);}));
test('wrong candidate, absent executable, weak hash and unsafe filenames fail before fetch',async()=>server(async({candidate,evidence})=>{
 for(const mutate of [e=>e.candidate={...candidate,commit:'b'.repeat(40)},e=>delete e.files['orafold-a.wasm'],e=>e.files['index.html']='bad',e=>e.files['../escape.js']=sha('bad'),e=>e.files['orafold%2fother.js']=sha('bad')]){const bad=structuredClone(evidence);mutate(bad);assert.throws(()=>requiredFiles(candidate,bad));}
}));
test('unexpected same-origin file redirects cannot substitute another executable',async()=>server(async({candidate,evidence})=>{delete evidence.files['orafold-a.js'];evidence.files['redirect.js']=sha('<html>exact candidate</html>');await assert.rejects(verifyExecutables(candidate,evidence),/different file/);}));
test('nested exported executables are verified, including their real streamed bytes',async()=>server(async({bodies,candidate,evidence})=>{
 for(const name of ['orafold-a.js','orafold-a.pck','orafold-a.wasm']){bodies['runtime/'+name]=bodies[name];delete bodies[name];evidence.files['runtime/'+name]=evidence.files[name];delete evidence.files[name];}
 const files=await verifyExecutables(candidate,evidence);assert.equal(files.filter(file=>file.file.startsWith('runtime/')).length,3);
 bodies['runtime/orafold-a.wasm']='stale nested executable';await assert.rejects(verifyExecutables(candidate,evidence),/SHA256: runtime\/orafold-a.wasm/);
}));
