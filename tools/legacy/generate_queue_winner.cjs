'use strict';
const fs=require('node:fs'),path=require('node:path');
const {ROOT,SOURCE,load}=require('./reference.cjs'),{runtime}=require('./generate_engine.cjs');
const clone=v=>JSON.parse(JSON.stringify(v));
function products(){const E=load(),base=JSON.parse(fs.readFileSync(path.join(ROOT,'tests/fixtures/legacy/transitions.json'),'utf8')).cases[0].steps[0].before,cases=[];
 for(const side of ['hero','enemy']){
  const b=runtime(base);b[side].hp=0;const before=clone(E.snapshot(b));
  const card=E.CARDS.find(c=>c.effect==='haste');
  const death={type:'death',side,unit:{id:'ash-1',hp:0,atk:1,summoned:false,stun:0},lane:1};
  b.queue=[{type:'summon',side,card,lane:0}];E.enqueue(b,death);
  cases.push({id:'queue.decisive_summon.'+side,before,batch:[{type:'summon',side,card_id:card.id,lane:0},death],after:clone(E.snapshot(b)),remaining_queue:b.queue.length});
 }
 return {schema_version:1,source:SOURCE,notice:'Actual original passive summon checks winner and discards remaining queued work.',cases};}
function main(){const file=path.join(ROOT,'tests/fixtures/legacy/queue_winner_p04_v1.json'),bytes=JSON.stringify(products(),null,2)+'\n';if(process.argv.includes('--write-new')){if(fs.existsSync(file))throw Error('Refusing to overwrite golden');fs.writeFileSync(file,bytes);}else if(!fs.existsSync(file)||fs.readFileSync(file,'utf8')!==bytes)throw Error('Queue winner golden drift');console.log('QUEUE WINNER: 2 original result-abort vectors');}
if(require.main===module)main();module.exports={products};
