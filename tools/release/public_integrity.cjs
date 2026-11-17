'use strict';
// Streaming read-only verification of actual published executable bytes.
// Metadata alone cannot prove that a CDN serves the matching index/PCK/WASM.
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
function requiredFiles(candidate,evidence){
 assert.equal(evidence?.schema,1,'known release-evidence schema');
 assert.deepEqual(evidence.candidate,candidate,'public release candidate matches exactly');
 const files=evidence.files;
 assert(files&&typeof files==='object'&&!Array.isArray(files),'published file digests are required');
 for(const [name,digest]of Object.entries(files)){
  assert(name&& !name.startsWith('/')&&!name.includes('\\')&&!/[\0:?#%]/.test(name),'safe literal release path');
  assert(name.split('/').every(part=>part&&part!=='.'&&part!=='..'),'canonical relative release path');
  assert(typeof digest==='string'&&/^[0-9a-f]{64}$/.test(digest),'full SHA256 release digest');
 }
 assert(Object.hasOwn(files,'index.html')&&Object.hasOwn(files,'build-info.json'),'published entry and identity hashes');
 const names=Object.keys(files);
 assert.equal(names.filter(name=>name.endsWith('.pck')).length,1,'one actual published PCK');
 assert.equal(names.filter(name=>name.endsWith('.wasm')).length,1,'one actual published WASM');
 assert(names.some(name=>name.endsWith('.js')),'an actual entry script is hashed');
 return Object.fromEntries(Object.entries(files).filter(([name])=>name==='index.html'||/\.(?:js|json|webmanifest|pck|wasm)$/.test(name)));
}
async function verifyFile(baseURL,name,expected,{fetchImpl=fetch,commit,maxBytes=2_000_000_000}={}){
 const root=new URL(baseURL),url=new URL(name.split('/').map(encodeURIComponent).join('/'),root);
 url.searchParams.set('release',commit||'integrity');
 const response=await fetchImpl(url,{headers:{'Cache-Control':'no-cache'},signal:AbortSignal.timeout(120000)});
 assert(response.ok,'published executable fetch succeeds: '+name);
 const resolved=new URL(response.url);
 assert.equal(resolved.origin,root.origin,'published executable stays on the expected public origin');
 assert.equal(resolved.pathname,url.pathname,'published executable does not redirect to a different file');
 assert(response.body,'published executable has an actual response stream');
 const digest=crypto.createHash('sha256');let bytes=0;
 for await(const chunk of response.body){bytes+=chunk.byteLength;assert(bytes<=maxBytes,'published executable exceeds size bound');digest.update(chunk);}
 assert(bytes>0,'published executable is nonempty: '+name);
 const actual=digest.digest('hex');assert.equal(actual,expected,'published executable SHA256: '+name);
 return {file:name,bytes,sha256:actual};
}
async function verifyExecutables(candidate,evidence,options={}){
 const files=requiredFiles(candidate,evidence),verified=[];
 for(const [name,digest]of Object.entries(files))verified.push(await verifyFile(candidate.public_url,name,digest,{...options,commit:candidate.commit}));
 return verified;
}
module.exports={requiredFiles,verifyFile,verifyExecutables};
