'use strict';
const fs=require('node:fs'),path=require('node:path');
const {ROOT,SOURCE,load}=require('./reference.cjs'),{runtime}=require('./generate_engine.cjs'),{compress}=require('./generate_p05_p06.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
function products(){const E=load(),base=JSON.parse(fs.readFileSync(path.join(ROOT,'tests/fixtures/legacy/transitions.json'),'utf8')).cases[0].steps[0].before,cases=[];
 for(const side of ['hero','enemy'])for(const route of ['recover-harvest','recycle-harvest','recycle-draw']){
  const b=runtime(base),op=side==='hero'?'enemy':'hero',effect=route.endsWith('draw')?'draw':'harvest',id=E.CARDS.find(c=>c.order==='ash'&&c.effect===effect).id;
  b.active=side;b[side].hand=[id];b[side].deck=[];b[side].discard=[];b[side].resonance=route.startsWith('recover')?15:0;
  b[op].lanes[2]={id:'ash-24',hp:11,atk:40,summoned:false,stun:0};const steps=[];
  function apply(command,args){const before=clone(E.snapshot(b)),first=b.events.length,v=E[command](b,...args),after=clone(E.snapshot(b));steps.push({command,args,before,after,result:v===undefined?{type:'undefined'}:{type:typeof v,value:v},reference_mutates_on_reject:v===false&&JSON.stringify(before)!==JSON.stringify(after),state_sequence:compress([{state:before,pendingDeath:null},...b.events.slice(first).map(e=>({state:clone(e.state),pendingDeath:clone(e.pendingDeath??null)})),{state:after,pendingDeath:clone(b.pendingDeath??null)}])});}
  apply('play',[side,0,2]);apply('attackPhase',[op]);
  if(route.startsWith('recover'))apply('recover',[side]);else{apply('begin',[side]);if(side==='hero')apply('finishDraw',[side]);}
  apply('play',[side,0,2]);apply('attackPhase',[op]);
  cases.push({id:`lifecycle.${side}.${route}`,side,card_id:null,setup_kind:'synthetic_controlled_state',steps});
 }
 return clone({schema_version:1,source:SOURCE,notice:'Repeated same card ID dies, returns through actual recover/recycle and dies again as a fresh unit; no physical-instance conflation.',cases});}
function main(){const file=path.join(ROOT,'tests/fixtures/legacy/p05_p06_lifecycle_v1.json'),bytes=JSON.stringify(products(),null,2)+'\n';if(process.argv.includes('--write-new')){if(fs.existsSync(file))throw Error('Refusing to overwrite golden');fs.writeFileSync(file,bytes);}else if(!fs.existsSync(file)||fs.readFileSync(file,'utf8')!==bytes)throw Error('P05/P06 lifecycle drift');console.log('P05/P06 LIFECYCLE:6 repeated death/recover/recycle cases');}
if(require.main===module)main();module.exports={products};
