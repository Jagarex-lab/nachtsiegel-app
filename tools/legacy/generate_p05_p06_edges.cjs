'use strict';
const fs=require('node:fs'),path=require('node:path');
const {ROOT,SOURCE,load}=require('./reference.cjs'),{runtime}=require('./generate_engine.cjs'),{compress}=require('./generate_p05_p06.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
function products(){
 const E=load(),base=JSON.parse(fs.readFileSync(path.join(ROOT,'tests/fixtures/legacy/transitions.json'),'utf8')).cases[0].steps[0].before,cases=[];
 const by=effect=>E.CARDS.find(c=>c.effect===effect&&c.order==='ash').id;
 const unit=(id='ash-1',hp=4)=>({id,hp,atk:E.BYID[id].atk,summoned:false,stun:0});
 function add(id,side,setup,commands){const b=runtime(base);b.active=side;for(const who of ['hero','enemy'])Object.assign(b[who],{hand:[],lanes:Array(5).fill(null),discard:[],energy:20});setup(b);const steps=[];for(const [command,...args]of commands){const before=clone(E.snapshot(b)),first=b.events.length,v=E[command](b,...args),after=clone(E.snapshot(b));steps.push({command,args,before,after,result:v===undefined?{type:'undefined'}:{type:typeof v,value:v},reference_mutates_on_reject:v===false&&JSON.stringify(before)!==JSON.stringify(after),state_sequence:compress([{state:before,pendingDeath:null},...b.events.slice(first).map(e=>({state:clone(e.state),pendingDeath:clone(e.pendingDeath??null)})),{state:after,pendingDeath:clone(b.pendingDeath??null)}])});}cases.push({id,side,card_id:null,setup_kind:'synthetic_controlled_state',steps});}
 for(const side of ['hero','enemy']){
  const op=side==='hero'?'enemy':'hero';
  add('strike.tie_and_offlane.'+side,side,b=>{b[side].hand=[by('strike')];b[op].lanes[1]=unit('ash-1',2);b[op].lanes[4]=unit('ash-1',2);},side==='hero'?[['play',side,0,2],['chooseStrikeTarget',side,4]]:[['play',side,0,2]]);
  add('shift.no_formation.'+side,side,b=>{b[side].hand=[by('shift')];b[side].lanes[1]=unit();b[op].lanes[0]=unit();},side==='hero'?[['play',side,0,2],['moveCreature',side,1,0]]:[['play',side,0,2]]);
  add('shift.resonance_cap.'+side,side,b=>{b[side].hand=[by('shift')];b[side].lanes[1]=unit();b[side].lanes[3]=unit();b[side].resonance=15;b[op].lanes[4]=unit();},side==='hero'?[['play',side,0,2],['moveCreature',side,1,4]]:[['play',side,0,2]]);
  add('recover.reset.'+side,side,b=>{b[side].resonance=15;b[side].discard=['ash-1','veil-1','tide-1'];},[['recover',side],['begin',side],...(side==='hero'?[['finishDraw',side]]:[]),['recover',side]]);
  add('fatigue.lethal.'+side,side,b=>{b[side].phase='draw';b[side].pendingDraw=3;b[side].deck=[];b[side].hp=1;b[side].block=20;b[side].ward=20;},[['finishDraw',side]]);
  add('effect.invalid_placement.'+side,side,b=>{b[side].hand=[by('strike')];b[side].lanes[2]=unit();},[['play',side,0,-1],['play',side,0,5],['play',side,0,1.5],['play',side,0,2]]);
  add('begin.first_overflow.'+side,side,b=>{b[side].turns=0;b[side].hand=E.START.slice(0,6);},[['begin',side]]);
 }
 return clone({schema_version:1,source:SOURCE,notice:'Additional targeted P05/P06 edges; original v1 goldens unchanged.',cases});
}
function main(){const file=path.join(ROOT,'tests/fixtures/legacy/p05_p06_edges_v1.json'),bytes=JSON.stringify(products(),null,2)+'\n';if(process.argv.includes('--write-new')){if(fs.existsSync(file))throw Error('Refusing to overwrite golden');fs.writeFileSync(file,bytes);}else if(!fs.existsSync(file)||fs.readFileSync(file,'utf8')!==bytes)throw Error('P05/P06 edge golden drift');console.log('P05/P06 EDGES:14 targeted cases');}
if(require.main===module)main();module.exports={products};
