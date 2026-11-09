'use strict';
const fs=require('node:fs'),path=require('node:path');
const {ROOT,SOURCE,load}=require('./reference.cjs');
const {runtime}=require('./generate_engine.cjs');
const {difference}=require('./compare.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
function compress(points){const out=[];for(const point of points)if(!out.length||difference(out.at(-1),point))out.push(point);return out;}
function products(){
 const E=load(),base=JSON.parse(fs.readFileSync(path.join(ROOT,'tests/fixtures/legacy/transitions.json'),'utf8')).cases[0].steps[0].before;
 const cases=[];const by=(effect,order='ash')=>E.CARDS.find(c=>c.effect===effect&&c.order===order).id;
 const unit=(id='ash-1',extra={})=>({id,hp:E.BYID[id].hp,atk:E.BYID[id].atk,summoned:false,stun:0,...extra});
 function make(side){const b=runtime(base);b.active=side;for(const who of ['hero','enemy'])Object.assign(b[who],{hand:[],discard:[],deck:[...E.START],lanes:Array(5).fill(null),hp:35,maxHp:35,energy:20,phase:'main',resonance:0,attune:null});return b;}
 function add(id,side,setup,commands,card_id=null){
  const b=make(side);setup(b);const steps=[];
  function apply(command,args){
   const before=clone(E.snapshot(b)),begin=b.events.length;
   const value=E[command](b,...args),after=clone(E.snapshot(b));
   const sequence=compress([{state:before,pendingDeath:null},...b.events.slice(begin).map(e=>({state:clone(e.state),pendingDeath:clone(e.pendingDeath??null)})),{state:after,pendingDeath:clone(b.pendingDeath??null)}]);
   steps.push({command,args,result:value===undefined?{type:'undefined'}:{type:typeof value,value},before,after,state_sequence:sequence,reference_mutates_on_reject:value===false&&difference(before,after)!==null});
  }
  if(typeof commands==='function')commands(b,apply);else for(const [command,...args]of commands)apply(command,args);
  cases.push({id,side,card_id,setup_kind:'synthetic_controlled_state',steps});
 }
 for(const side of ['hero','enemy']){
  const op=side==='hero'?'enemy':'hero';
  for(const card of E.CARDS)add(`card.${side}.${card.id}`,side,b=>{
   b[side].hand=[card.id];b[side].hp=20;b[side].lanes[1]=unit('ash-1',{hp:2});b[side].lanes[3]=unit('veil-1');
   b[op].lanes[2]=unit('ash-1',{hp:2});b[op].lanes[4]=unit('ash-1',{hp:6});b[op].block=2;b[op].ward=3;
  },(b,apply)=>{apply('play',[side,0,2]);if(b[side].pendingTarget){apply('chooseStrikeTarget',[side,0]);apply('chooseStrikeTarget',[side,2]);apply('chooseStrikeTarget',[side,2]);}if(b[side].pendingShift){apply('moveCreature',[side,2,4]);apply('moveCreature',[side,1,4]);apply('skipShift',[side]);}},card.id);
  for(const effect of Object.keys(E.KINDS))add(`edge.cap_or_absent.${side}.${effect}`,side,b=>{
   b[side].hand=[by(effect)];b[side].resonance=14;b[side].ward=24;b[op].weak=8;b[op].block=20;b[op].ward=20;
   if(effect==='draw'){b[side].deck=[];b[side].discard=['ash-1'];}
  },[['play',side,0,0]]);
  for(const [name,block,ward,hp] of [['absorbed',10,10,35],['partial',1,1,35],['overkill',0,0,1]])add(`drain.${side}.${name}`,side,b=>{b[side].hand=[by('drain')];b[side].hp=20;b[op].block=block;b[op].ward=ward;b[op].hp=hp;},[['play',side,0,2]]);
  for(const lane of [0,2,4])add(`neighbors.${side}.${lane}`,side,b=>{b[side].hand=[by('rally')];for(const n of [lane-1,lane+1])if(n>=0&&n<5)b[side].lanes[n]=unit();},[['play',side,0,lane]]);
  add(`silence.readiness.${side}`,side,b=>{b[side].hand=[by('silence')];b[op].lanes[2]=unit(by('haste'),{summoned:true,stun:2});},[['play',side,0,2],['attackPhase',op],['attackPhase',op],['attackPhase',op]]);
  add(`shift.targets.${side}`,side,b=>{b[side].hand=[by('shift')];b[side].lanes[1]=unit();b[side].lanes[3]=unit('veil-1');},(b,a)=>{a('play',[side,0,2]);if(b[side].pendingShift){for(const x of [[0,4],[1,2],[1,5],[1,1.5]])a('moveCreature',[side,...x]);a('moveCreature',[side,1,4]);a('moveCreature',[side,1,0]);}});
  add(`target.invalid.${side}`,side,b=>{b[side].pendingTarget={power:3,sourceLane:2};b[op].lanes[2]=unit(by('harvest'),{hp:1});},[['chooseStrikeTarget',side,-1],['chooseStrikeTarget',side,5],['chooseStrikeTarget',side,1.5],['chooseStrikeTarget',side,0],['chooseStrikeTarget',side,2],['chooseStrikeTarget',side,2]]);
  const pairs=[['guard','ward'],['weave','pulse'],['rally','haste'],['draw','draw'],['silence','strike'],['shift','pulse'],['drain','mend'],['pierce','strike']];
  for(const [first,second]of pairs)add(`combo.${side}.${first}.${second}`,side,b=>{b[side].hand=[by(first),by(second)];b[side].hp=15;b[side].lanes[0]=unit();b[op].lanes[4]=unit(by('harvest'),{hp:2});b[op].ward=3;},(b,a)=>{for(const lane of [1,2]){a('play',[side,0,lane]);if(b[side].pendingTarget)a('chooseStrikeTarget',[side,4]);if(b[side].pendingShift)a('skipShift',[side]);}});
  for(const missing of [0,1,3])for(const fatigue of [0,2,3])add(`draw.${side}.missing_${missing}.fatigue_${fatigue}`,side,b=>{b[side].phase='draw';b[side].pendingDraw=3;b[side].deck=E.START.slice(0,3-missing);b[side].fatigue=fatigue;b[side].block=10;b[side].ward=10;},[['finishDraw',side]]);
  add(`draw.overflow.${side}`,side,b=>{b[side].phase='draw';b[side].pendingDraw=1;b[side].hand=E.START.slice(0,6);},[['finishDraw',side],['burn',side,-1],['burn',side,1.5],['burn',side,0],['burn',side,0],['finishDraw',side]]);
  add(`draw.recycle_before_reject.${side}`,side,b=>{b[side].phase='draw';b[side].pendingDraw=1;b[side].hand=E.START.slice(0,6);b[side].deck=[];b[side].discard=['ash-1','veil-1'];},[['finishDraw',side],['burn',side,0],['finishDraw',side]]);
  for(const seed of [-1,0,12345])for(const cycles of [0,1,3,4294967295])add(`recycle.${side}.${seed}.${cycles}`,side,b=>{b.seed=seed;b[side].phase='draw';b[side].pendingDraw=3;b[side].deck=[];b[side].discard=['ash-1','tide-1','veil-1','ash-2'];b[side].cycles=cycles;b[side].ward=10;b[side].block=10;},[['finishDraw',side]]);
  add(`recycle.lethal.${side}`,side,b=>{b[side].phase='draw';b[side].pendingDraw=1;b[side].deck=[];b[side].discard=['ash-1'];b[side].hp=1;},[['finishDraw',side]]);
  add(`fatigue.progression.${side}`,side,b=>{b[side].phase='draw';b[side].pendingDraw=1;b[side].deck=[];},[['finishDraw',side],['begin',side],['finishDraw',side],['begin',side],['finishDraw',side],['begin',side],['finishDraw',side]]);
  add(`begin.overflow_and_recycle.${side}`,side,b=>{b[side].hand=E.START.slice(0,6);b[side].deck=[];b[side].discard=['ash-1','tide-1'];b[side].block=7;},[['begin',side]]);
  for(const round of [1,2,2147483648])for(const seed of [-1,12345])add(`recover.${side}.${seed}.${round}`,side,b=>{b.seed=seed;b.round=round;b[side].resonance=15;b[side].discard=['ash-1','tide-1','veil-1','ash-2'];},[['recover',side],['recover',side]]);
  for(const kind of ['resource','hand','phase','discard','winner','pending'])add(`recover.edge.${side}.${kind}`,side,b=>{b[side].resonance=5;b[side].discard=['ash-1'];if(kind==='resource')b[side].resonance=4;if(kind==='hand')b[side].hand=E.START.slice(0,6);if(kind==='phase')b[side].phase='draw';if(kind==='discard')b[side].discard=[];if(kind==='winner')b.winner=op;if(kind==='pending')b[side].pendingTarget={power:2,sourceLane:0};},[['recover',side]]);
  add(`effect.draw.handcap.${side}`,side,b=>{b[side].hand=[by('draw'),...E.START.slice(0,5)];},[['play',side,0,2]]);
  add(`pierce.lethal.${side}`,side,b=>{b[side].hand=[by('pierce')];b[op].hp=1;b[op].ward=25;b[op].block=25;},[['play',side,0,2]]);
 }
 return clone({schema_version:1,source:SOURCE,notice:'P05/P06 synthetic original-engine transitions. Canonical event-state sequences preserve every distinct full state + pendingDeath, collapse only identical consecutive snapshots; not P11 message/ABI compatibility.',cases});
}
function main(){const file=path.join(ROOT,'tests/fixtures/legacy/p05_p06_v1.json'),bytes=JSON.stringify(products(),null,2)+'\n';if(process.argv.includes('--write-new')){if(fs.existsSync(file))throw Error('Refusing to overwrite golden');fs.writeFileSync(file,bytes);}else if(!fs.existsSync(file)||fs.readFileSync(file,'utf8')!==bytes)throw Error('P05/P06 golden drift');const d=JSON.parse(bytes);console.log(`P05/P06 GOLDENS: ${d.cases.length} cases, ${d.cases.reduce((n,c)=>n+c.steps.length,0)} transitions; 200 original card/side cases`);}
if(require.main===module)main();module.exports={products,compress};
