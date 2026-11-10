'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),vm=require('node:vm'),cp=require('node:child_process');
const ROOT=path.resolve(__dirname,'../..');
const COMMIT='34b3062c3f22c0950d9323ad9b97b17c41d1d14f';
const SHA256='abf880e049080a7ec39a43fefa805ba9e8de18f7638633bef6d7096dc5a78dd1';
const BLOB='d3f48929c334052b2e4062264fe5c9ac39b49c6a';
const SOURCE={repository:'https://github.com/Jagarex-lab/duel-deck',commit:COMMIT,path:'engine.js',git_blob:BLOB,sha256:SHA256};
function verify(source,bytes){
  for(const [key,value] of Object.entries(SOURCE))if(source[key]!==value)throw Error('Reference pin mismatch: '+key);
  if(crypto.createHash('sha256').update(bytes).digest('hex')!==SHA256)throw Error('Reference engine SHA-256 mismatch');
  if(crypto.createHash('sha1').update(Buffer.concat([Buffer.from(`blob ${bytes.length}\0`),bytes])).digest('hex')!==BLOB)throw Error('Reference git blob mismatch');
}
function load(options={}){
  const dir=path.join(ROOT,'tests/reference/duel_deck');
  const source=JSON.parse(fs.readFileSync(path.join(dir,'source.lock.json'),'utf8'));
  if(source.schema_version!==1)throw Error('Unsupported reference lock schema');
  const bytes=fs.readFileSync(path.join(dir,'engine.js'));verify(source,bytes);
  // Fresh VM every time, so caller mutation cannot taint subsequent generations.
  const context={module:{exports:{}}};
  // Optional read-only test instrumentation: same source bytes and native result.
  if(options.onImul){const observedMath=Object.create(Math);observedMath.imul=(a,b)=>{const result=Math.imul(a,b);options.onImul(a,b,result);return result;};context.Math=observedMath;}
  vm.runInNewContext(bytes.toString('utf8'),context,{filename:'pinned-duel-deck/engine.js',timeout:5000});
  return context.module.exports;
}
function verifyCheckout(repo){
  const head=cp.execFileSync('git',['-C',repo,'rev-parse','HEAD'],{encoding:'utf8'}).trim();
  if(head!==COMMIT)throw Error('Checkout is not pinned commit '+COMMIT);
  verify(SOURCE,cp.execFileSync('git',['-C',repo,'show',`${COMMIT}:engine.js`]));
  verify(SOURCE,fs.readFileSync(path.join(repo,'engine.js')));
}
module.exports={ROOT,SOURCE,verify,load,verifyCheckout};
