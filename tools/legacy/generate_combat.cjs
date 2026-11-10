'use strict';
const fs=require('node:fs'),path=require('node:path');
const {ROOT,SOURCE,load}=require('./reference.cjs');
const {runtime}=require('./generate_engine.cjs');
const clone=v=>JSON.parse(JSON.stringify(v));
function products(){
 const E=load();const base=JSON.parse(fs.readFileSync(path.join(ROOT,'tests/fixtures/legacy/transitions.json'),'utf8')).cases[0].steps[0].before;
 function clean(){const b=runtime(base);for(const side of ['hero','enemy'])Object.assign(b[side],{hand:[],discard:[],lanes:Array(5).fill(null)});return b;}
 function deaths(events){return events.filter(e=>e.pendingDeath&&e.message.endsWith(' fällt.')).map(e=>({pendingDeath:e.pendingDeath,state:e.state}));}
 const combats=[],queues=[];
 for(let seed=1;seed<=120;seed++){
  const b=clean(),r=E.rng(Math.imul(seed,2654435761)>>>0),side=seed%2?'hero':'enemy';b.active=side;
  for(const who of ['hero','enemy']){
   Object.assign(b[who],{hp:1+Math.floor(r()*35),block:Math.floor(r()*8),ward:Math.floor(r()*13),weak:Math.floor(r()*5),resonance:Math.floor(r()*16),seals:Math.floor(r()*2)});
   for(let lane=0;lane<5;lane++)if(r()<.8){const c=E.CARDS[Math.floor(r()*100)];b[who].lanes[lane]={id:c.id,hp:1+Math.floor(r()*12),atk:Math.floor(r()*11),summoned:r()<.25,stun:r()<.2?1:0};}
  }
  const before=clone(E.snapshot(b));E.attackPhase(b,side);
  combats.push({id:'combat.mixed.'+seed,side,before,after:clone(E.snapshot(b)),deaths:clone(deaths(b.events))});
 }
 // Simultaneous zero HP is reached through a real original lane hit/check.
 for(const side of ['hero','enemy']){
  const b=clean(),op=side==='hero'?'enemy':'hero';b.active=side;b[side].hp=0;b[op].hp=1;
  b[side].lanes[0]={id:'ash-1',hp:4,atk:2,summoned:false,stun:0};
  const before=clone(E.snapshot(b));E.attackPhase(b,side);
  combats.push({id:'combat.draw.'+side,side,before,after:clone(E.snapshot(b)),deaths:clone(deaths(b.events))});
 }
 for(const count of [1,2,100,101])for(const deferred of [false,true]){
  const b=clean();const batch=Array.from({length:count},(_,i)=>({type:'death',side:i%2?'enemy':'hero',unit:{id:E.CARDS[i%100].id,hp:-i,atk:1,summoned:false,stun:0},lane:i%5}));
  const before=clone(E.snapshot(b));let error=null;
  try{
   if(deferred){b.resolving=true;for(const event of batch.slice(0,-1))E.enqueue(b,event);b.resolving=false;E.enqueue(b,batch.at(-1));}
   else{b.queue=batch.slice(0,-1);E.enqueue(b,batch.at(-1));}
  }catch(e){error=e.message;}
  queues.push({id:`queue.${count}.${deferred}`,before,batch:clone(batch),deferred_prefix:deferred,after:clone(E.snapshot(b)),deaths:clone(deaths(b.events)),limited:error!==null,remaining_queue:b.queue.length,resolving:b.resolving,pending_death:b.pendingDeath??null,error});
 }
 return clone({schema_version:1,source:SOURCE,notice:'Synthetic P04 combat/queue inputs executed by pinned JS, not naturally dealt matches.',combats,queues});
}
function main(){const file=path.join(ROOT,'tests/fixtures/legacy/combat_p04_v1.json'),bytes=JSON.stringify(products(),null,2)+'\n';if(process.argv.includes('--write-new')){if(fs.existsSync(file))throw Error('Refusing to overwrite golden');fs.writeFileSync(file,bytes);}else if(!fs.existsSync(file)||fs.readFileSync(file,'utf8')!==bytes)throw Error('Combat golden drift');const data=JSON.parse(bytes);console.log(`COMBAT GOLDENS: ${data.combats.length} mixed/draw cases, ${data.queues.length} FIFO/limit cases`);}
if(require.main===module)main();module.exports={products};
