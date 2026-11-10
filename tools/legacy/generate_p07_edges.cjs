'use strict';
const fs=require('node:fs'),path=require('node:path');
const {ROOT,SOURCE,load}=require('./reference.cjs'),{runtime}=require('./generate_engine.cjs'),{compress}=require('./generate_p05_p06.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
function products(){
 const E=load(),base=JSON.parse(fs.readFileSync(path.join(ROOT,'tests/fixtures/legacy/transitions.json'),'utf8')).cases[0].steps[0].before,cases=[];
 const unit=(id='ash-1',extra={})=>({id,hp:E.BYID[id].hp,atk:E.BYID[id].atk,summoned:false,stun:0,...extra});
 function add(id,side,setup,commands){const b=runtime(base);b.active=side;for(const who of ['hero','enemy'])Object.assign(b[who],{hand:[],lanes:Array(5).fill(null),deck:[...E.START],discard:[],resonance:15,energy:20,hp:25,maxHp:35,attune:null,phase:'main'});setup(b);const steps=[];for(const [command,...args]of commands){const before=clone(E.snapshot(b)),first=b.events.length,v=E[command](b,...args),after=clone(E.snapshot(b));steps.push({command,args,before,after,result:v===undefined?{type:'undefined'}:{type:typeof v,value:v},reference_mutates_on_reject:v===false&&JSON.stringify(before)!==JSON.stringify(after),state_sequence:compress([{state:before,pendingDeath:null},...b.events.slice(first).map(e=>({state:clone(e.state),pendingDeath:clone(e.pendingDeath??null)})),{state:after,pendingDeath:clone(b.pendingDeath??null)}])});}cases.push({id,side,steps});}
 for(const side of ['hero','enemy']){
  const op=side==='hero'?'enemy':'hero';
  for(const res of [0,4,5,9,10,14,15])for(const level of [1,5])add(`threshold.${side}.${res}.level${level}`,side,b=>{b.level=level;Object.assign(b[side],{resonance:res,ward:24,turns:2,attune:'veil',burstUsed:true,tacticUsed:true,fortifyUsed:true,cycled:true,summons:2});},[['begin',side]]);
  add(`reset_to_legal_burst.${side}`,side,b=>{b[side].lanes[0]=unit();b[side].hand=['ash-21','ash-21'];},[['burst',side,'ash'],['play',side,0,1],['play',side,0,2],['burst',side,'ash'],['begin',side],...(side==='hero'?[['finishDraw',side]]:[]),['burst',side,'ash']]);
  add(`formation_vs_tactic.${side}`,side,b=>{b[side].resonance=4;b[side].lanes[0]=unit();b[side].lanes[2]=unit('thorn-1');},[['tacticalMove',side,0,1],['fortify',side,1]]);
  for(const order of ['ash','tide','thorn','veil'])add(`burst_first_rally_chain.${side}.${order}`,side,b=>{b[side].hand=[E.CARDS.find(c=>c.order===order&&c.effect==='rally').id];b[side].lanes[1]=unit(order+'-0',{hp:1,stun:1,summoned:true});b[op].weak=9;},[['burst',side,order],['play',side,0,2],['attackPhase',side]]);
  add(`reaction_death_and_harvest.${side}`,side,b=>{b[side].resonance=0;b[side].attune='tide';b[side].hand=['ash-0'];const id=E.CARDS.find(c=>c.effect==='harvest').id;b[op].lanes[2]=unit(id,{hp:1});b[side].lanes[0]=unit(id,{hp:1});},[['play',side,0,1],...(side==='hero'?[['chooseStrikeTarget',side,2]]:[]),['attackPhase',side]]);
 }
 return clone({schema_version:1,source:SOURCE,notice:'Additional P07 threshold/flag-reset/action-formation/queue edges; previous goldens unchanged.',cases});
}
function main(){const file=path.join(ROOT,'tests/fixtures/legacy/p07_edges_v1.json'),bytes=JSON.stringify(products(),null,2)+'\n';if(process.argv.includes('--write-new')){if(fs.existsSync(file))throw Error('Refusing to overwrite golden');fs.writeFileSync(file,bytes);}else if(fs.readFileSync(file,'utf8')!==bytes)throw Error('P07 edge golden drift');const f=JSON.parse(bytes);console.log(`P07 edges: ${f.cases.length} cases / ${f.cases.reduce((n,c)=>n+c.steps.length,0)} transitions`);}
if(require.main===module)main();module.exports={products};
