'use strict';
const fs=require('node:fs'),path=require('node:path');
const {ROOT,SOURCE,load}=require('./reference.cjs'),{runtime}=require('./generate_engine.cjs'),{compress}=require('./generate_p05_p06.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
function products(){
 const E=load(),base=JSON.parse(fs.readFileSync(path.join(ROOT,'tests/fixtures/legacy/transitions.json'),'utf8')).cases[0].steps[0].before,cases=[],orders=E.ORDERS.map(o=>o.id);
 const by=(order,effect)=>E.CARDS.find(c=>c.order===order&&c.effect===effect).id;
 const unit=(id='ash-1',extra={})=>({id,hp:E.BYID[id].hp,atk:E.BYID[id].atk,summoned:false,stun:0,...extra});
 function add(id,side,setup,commands){
  const b=runtime(base);b.active=side;for(const who of ['hero','enemy'])Object.assign(b[who],{hand:[],discard:[],deck:[...E.START],lanes:Array(5).fill(null),hp:25,maxHp:35,resonance:0,energy:20,phase:'main',attune:null});setup(b);const steps=[];
  const apply=(command,args)=>{const before=clone(E.snapshot(b)),first=b.events.length,v=E[command](b,...args),after=clone(E.snapshot(b));steps.push({command,args,before,after,result:v===undefined?{type:'undefined'}:{type:typeof v,value:v},reference_mutates_on_reject:v===false&&JSON.stringify(before)!==JSON.stringify(after),state_sequence:compress([{state:before,pendingDeath:null},...b.events.slice(first).map(e=>({state:clone(e.state),pendingDeath:clone(e.pendingDeath??null)})),{state:after,pendingDeath:clone(b.pendingDeath??null)}])});};
  if(typeof commands==='function')commands(b,apply);else for(const [cmd,...args]of commands)apply(cmd,args);
  cases.push({id,side,steps});
 }
 for(const side of ['hero','enemy']){
  const op=side==='hero'?'enemy':'hero';
  for(const from of orders)for(const to of orders){
   for(const res of [0,14,15])add(`reaction.${side}.${from}.${to}.res${res}`,side,b=>{b[side].attune=from;b[side].resonance=res;b[side].ward=24;b[side].hp=34;b[side].hand=[by(to,'harvest')];b[op].block=1;b[op].ward=2;b[op].weak=5;},[['play',side,0,2]]);
  }
  // Real two-summon chain for every card, all16 effects after an actual different order.
  for(const card of E.CARDS){const from=orders[(orders.indexOf(card.order)+1)%4];add(`card_chain.${side}.${card.id}`,side,b=>{b[side].hand=[by(from,'harvest'),card.id];b[side].resonance=12;b[op].lanes[2]=unit(by('thorn','harvest'),{hp:1});b[side].lanes[0]=unit();},(b,a)=>{a('play',[side,0,1]);a('play',[side,0,2]);if(b[side].pendingTarget)a('chooseStrikeTarget',[side,2]);if(b[side].pendingShift)a('moveCreature',[side,0,4]);a('attackPhase',[side]);});}
  for(const to of ['tide','veil'])for(const effect of ['draw','pierce','strike'])add(`lethal_reaction.${side}.${to}.${effect}`,side,b=>{b[side].attune='ash';b[side].hand=[by(to,effect)];b[op].hp=1;b[op].lanes[2]=unit(by('thorn','harvest'),{hp:1});},[['play',side,0,2],['play',side,0,3],['burst',side,to]]);
  for(const order of orders)for(const n of [0,1,3,5])for(const res of [14,15])add(`burst.${side}.${order}.n${n}.res${res}`,side,b=>{b[side].resonance=res;b[side].ward=24;b[op].block=2;b[op].ward=3;b[op].weak=8;for(let i=0;i<n;i++)b[side].lanes[i]=unit(by(order,'harvest'),{hp:1});if(n<5)b[side].lanes[4]=unit(by(orders[(orders.indexOf(order)+1)%4],'harvest'),{hp:1});},[['burst',side,order],['burst',side,order]]);
  for(const pending of ['target','shift'])for(const action of ['burst','tacticalMove','fortify'])add(`pending.${side}.${pending}.${action}`,side,b=>{b[side].resonance=15;b[side].lanes[0]=unit(by('veil','harvest'));if(pending==='target')b[side].pendingTarget={power:3,sourceLane:0};else b[side].pendingShift={origin:1};},[[action,side,...(action==='burst'?['veil']:action==='fortify'?[0]:[0,1])]]);
  for(const action of ['burst','tacticalMove','fortify'])for(const bad of ['phase','inactive','winner','used','resource'])add(`reject.${side}.${action}.${bad}`,side,b=>{b[side].resonance=15;b[side].lanes[0]=unit();if(bad==='phase')b[side].phase='draw';if(bad==='inactive')b.active=op;if(bad==='winner')b.winner=op;if(bad==='used')b[side][{burst:'burstUsed',tacticalMove:'tacticUsed',fortify:'fortifyUsed'}[action]]=true;if(bad==='resource')b[side].resonance=0;},[[action,side,...(action==='burst'?['ash']:action==='fortify'?[0]:[0,1])]]);
  add(`move.${side}.indices_and_flags`,side,b=>{b[side].resonance=15;b[side].lanes[0]=unit('ash-1',{summoned:true,stun:2});b[side].lanes[2]=unit();},[['tacticalMove',side,-1,0],['tacticalMove',side,0,1.5],['tacticalMove',side,0,4],['tacticalMove',side,0,2],['tacticalMove',side,1,0],['tacticalMove',side,0,1],['tacticalMove',side,1,0],['attackPhase',side]]);
  for(const hp of [1,4,20])add(`fortify.${side}.hp${hp}`,side,b=>{b[side].resonance=15;b[side].ward=24;b[side].lanes[0]=unit('ash-1',{hp});},[['fortify',side,-1],['fortify',side,5],['fortify',side,1.5],['fortify',side,1],['fortify',side,0],['fortify',side,0]]);
  add(`burst.${side}.wrong_order`,side,b=>{b[side].resonance=15;b[side].lanes[0]=unit();},[['burst',side,'unknown'],['burst',side,'tide'],['burst',side,null]]);
  add(`burst.${side}.lethal_protection`,side,b=>{b[side].resonance=15;b[side].lanes[0]=unit();b[op].hp=1;b[op].block=2;b[op].ward=3;},[['burst',side,'ash'],['fortify',side,0]]);
  add(`reset.${side}`,side,b=>{b[side].resonance=15;b[side].lanes[0]=unit();b[side].hand=[by('tide','harvest')];},[['tacticalMove',side,0,1],['fortify',side,1],['begin',side],...(side==='hero'?[['finishDraw',side]]:[]),['tacticalMove',side,1,0],['fortify',side,0],['play',side,0,2]]);
  add(`burst_reset.${side}`,side,b=>{b[side].resonance=15;b[side].lanes[0]=unit();b[side].hand=[by('ash','weave'),by('ash','weave')];},[['burst',side,'ash'],['play',side,0,1],['play',side,0,2],['burst',side,'ash'],['begin',side],...(side==='hero'?[['finishDraw',side]]:[]),['burst',side,'ash']]);
  add(`combo.${side}.recover_burst_move_fortify`,side,b=>{b[side].resonance=15;b[side].lanes[0]=unit(by('tide','harvest'));b[side].discard=['ash-1','veil-1'];},[['recover',side],['burst',side,'tide'],['tacticalMove',side,0,1],['fortify',side,1]]);
 }
 return clone({schema_version:1,source:SOURCE,notice:'P07 original-reference synthetic state transitions; all distinct full event states + pendingDeath, adjacent identical observations compressed. No P11 ABI claim.',cases});
}
function main(){const file=path.join(ROOT,'tests/fixtures/legacy/p07_v1.json'),bytes=JSON.stringify(products(),null,2)+'\n';if(process.argv.includes('--write-new')){if(fs.existsSync(file))throw Error('Refusing to overwrite golden');fs.writeFileSync(file,bytes);}else if(fs.readFileSync(file,'utf8')!==bytes)throw Error('P07 golden drift');const f=JSON.parse(bytes);console.log(`P07: ${f.cases.length} cases / ${f.cases.reduce((n,c)=>n+c.steps.length,0)} transitions`);}
if(require.main===module)main();module.exports={products};
