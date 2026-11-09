'use strict';
const fs=require('node:fs'),path=require('node:path');
const {ROOT,SOURCE,load}=require('./reference.cjs');
const {runtime,phases}=require('./generate_engine.cjs');
const clone=v=>JSON.parse(JSON.stringify(v));
function products(){
 const E=load(),base=JSON.parse(fs.readFileSync(path.join(ROOT,'tests/fixtures/legacy/transitions.json'),'utf8')).cases[0].steps[0].before;
 const cases=[];
 for(const first of ['hero','enemy']){
  let b=runtime(base);b.active=first;
  const passive=E.CARDS.filter(c=>c.order==='ash'&&['haste','retaliate','harvest'].includes(c.effect)).map(c=>c.id);
  for(const side of ['hero','enemy'])Object.assign(b[side],{hand:[passive[0],passive[1]],energy:10,lanes:Array(5).fill(null),discard:[],attune:null});
  const steps=[];
  function apply(command,args){
   const before=clone(E.snapshot(b)),start=b.events.length;const result=E[command](b,...args);
   let after=clone(E.snapshot(b));let p=phases(b.events.slice(start));
   if(command==='endTurn'&&args[0]==='hero'){
    const i=p.findIndex(e=>e.kind==='begin');
    if(i>=0){const next=p[i+1]?.kind==='draw_finished'?p[i+1]:p[i];after=clone(next.state);p=p.slice(0,i+(next.kind==='draw_finished'?2:1));}
   }
   steps.push({command,args,accepted:result!==false,after,phases:clone(p),before});b=runtime(after);
  }
  for(let turn=0;turn<8&&!b.winner;turn++){
   const side=b.active,p=b[side];
   if(p.phase==='draw')apply('finishDraw',[side]);
   for(let attempt=0;attempt<2;attempt++){
    const own=b[side];const index=own.hand.findIndex(id=>{const c=E.BYID[id];return ['haste','retaliate','harvest'].includes(c.effect)&&c.cost<=own.energy&&(!own.attune||own.attune===c.order)});
    const lane=own.lanes.findIndex(u=>!u);
    if(index<0||lane<0||own.summons>=2)break;
    apply('play',[side,index,lane]);
   }
   apply('endTurn',[side]);
  }
  cases.push({id:'turns.manual_boundaries.first_'+first,notice:'Stateful controller uses only supported passives; optional original AI execution is observed only up to the captured pre-AI boundary.',steps});
 }
 return clone({schema_version:1,source:SOURCE,cases});
}
function main(){const file=path.join(ROOT,'tests/fixtures/legacy/turns_p03_v1.json'),bytes=JSON.stringify(products(),null,2)+'\n';if(process.argv.includes('--write-new')){if(fs.existsSync(file))throw Error('Refusing to overwrite golden');fs.writeFileSync(file,bytes);}else if(!fs.existsSync(file)||fs.readFileSync(file,'utf8')!==bytes)throw Error('Turn golden drift');const data=JSON.parse(bytes);console.log(`TURN GOLDENS: ${data.cases.length} stateful boundary sequences, ${data.cases.reduce((n,c)=>n+c.steps.length,0)} transitions`);}
if(require.main===module)main();module.exports={products};
