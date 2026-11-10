'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {ROOT,SOURCE,load}=require('./reference.cjs');
const clone=v=>JSON.parse(JSON.stringify(v));
function products(){
 const cases=[];
 for(const seed of [0,1,-1,1000,12345,8802026,2147483648,4294967295,4294967296])for(const level of [1,2,5,30]){
  let calls=0,state=null;
  const observed=load({onImul:(a,b,result)=>{if(b===1664525){calls++;state=(result+1013904223)>>>0;}}});
  const b=observed.createBattle(observed.START,seed,level),plain=load();
  assert.deepEqual(clone(b.initialState),clone(plain.createBattle(plain.START,seed,level).initialState),'observer cannot change reference state');
  const r=plain.rng(seed);for(let i=0;i<calls;i++)r();const next=r();
  cases.push({id:`opening.${seed}.${level}`,seed,level,calls,state,next_state:next*4294967296});
 }
 return {schema_version:1,source:SOURCE,notice:'Observed native Math.imul calls of unchanged source, filtered to its LCG multiplier. No reference source rewriting.',cases};
}
function main(){const file=path.join(ROOT,'tests/fixtures/legacy/rng_consumption_v1.json'),bytes=JSON.stringify(products(),null,2)+'\n';if(process.argv.includes('--write-new')){if(fs.existsSync(file))throw Error('Refusing to overwrite golden');fs.writeFileSync(file,bytes);}else if(!fs.existsSync(file)||fs.readFileSync(file,'utf8')!==bytes)throw Error('RNG consumption golden drift');console.log('RNG CONSUMPTION: 36 observed call-count/state/next-state vectors');}
if(require.main===module)main();module.exports={products};
