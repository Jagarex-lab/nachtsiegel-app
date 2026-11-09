'use strict';
const fs=require('node:fs'),path=require('node:path');
const {ROOT,SOURCE,load}=require('./reference.cjs');
const clone=x=>JSON.parse(JSON.stringify(x));
function products(){const E=load(),cases=[];
 for(const seed of [0,1,1000,12345,8802026,-1,2147483648,4294967295])for(const level of [1,2,5]){
  const deck=[...E.START],b=E.createBattle(deck,seed,level),initial=clone(E.snapshot(b)),steps=[];
  function action(command,...args){const before=clone(E.snapshot(b)),v=E[command](b,...args);steps.push({command,args,value:v,before,after:clone(E.snapshot(b))});return v;}
  for(let turn=0;turn<180&&!b.winner;turn++){
   if(b.active!=='hero')throw Error('AI did not return control');
   if(b.hero.phase==='draw'){
    while(b.hero.hand.length+Math.min(b.hero.pendingDraw,b.hero.deck.length)>6)action('burn','hero',0);
    action('finishDraw','hero');
   }
   for(let k=0;k<8&&!b.winner;k++){
    const p=b.hero;
    if(p.pendingTarget){action('chooseStrikeTarget','hero',b.enemy.lanes.findIndex(Boolean));continue;}
    if(p.pendingShift){action('skipShift','hero');continue;}
    const lane=p.lanes.findIndex(x=>!x),i=p.hand.findIndex(id=>E.BYID[id].cost<=p.energy);
    if(p.summons>=2||lane<0||i<0)break;
    action('play','hero',i,lane);
   }
   if(!b.winner)action('endTurn','hero');
  }
  if(!b.winner)throw Error('Fixture did not finish');
  cases.push({seed,level,deck,initial,steps,winner:b.winner});
 }
 return clone({source:SOURCE,schema_version:1,cases});
}
if(require.main===module){const p=path.join(ROOT,'tests/fixtures/legacy/full_matches_v1.json'),bytes=JSON.stringify(products())+'\n';if(process.argv.includes('--write-new')){if(fs.existsSync(p))throw Error('Golden exists');fs.writeFileSync(p,bytes);}else if(fs.readFileSync(p,'utf8')!==bytes)throw Error('Match fixture drift');console.log('FULL MATCHES:24 complete original-engine duels');}
module.exports={products};
