'use strict';
// Additional P01-P04 goldens. Existing PR #2 outputs are never regenerated here.
const fs=require('node:fs'),path=require('node:path');
const {ROOT,SOURCE,load}=require('./reference.cjs');
const clone=v=>JSON.parse(JSON.stringify(v));
function runtime(snapshot){
 const b=clone(snapshot);
 for(const side of ['hero','enemy']){delete b[side].deckCount;delete b[side].handCount;for(const u of b[side].lanes)if(u){delete u.baseHp;delete u.baseAtk;}}
 Object.assign(b,{events:[],log:[],actions:[],queue:[]});return b;
}
function phases(events){return events.filter(e=>/^(ANGRIFFSPHASE|ENDPHASE|Zug \d+: Beginnphase|Nachziehphase beendet:)/.test(e.message)).map(e=>({kind:e.message.startsWith('ANGRIFF')?'phase_attack':e.message.startsWith('ENDPHASE')?'phase_end':e.message.startsWith('Zug ')?'begin':'draw_finished',state:e.state}));}
function products(){
 const E=load(),seeds=[0,1,-1,1000,12345,8802026,2147483648,4294967295,4294967296];
 const randoms=[],openings=[],begins=[],advances=[],damage=[];
 for(const seed of seeds){
  let r=E.rng(seed);const values=Array.from({length:20},()=>r());
  randoms.push({id:'rng.'+seed,seed,values,states:values.map(x=>x*4294967296)});
  for(const [id,deck] of [['start',E.START],...E.PRESETS.map(p=>[p.id,p.cards])]){
   r=E.rng(seed);const input=[...deck],shuffled=E.shuffle(input,r);randoms.push({id:`shuffle.${seed}.${id}`,seed,input,shuffled});
  }
  for(const level of [1,2,5,30]){
   const full=E.createBattle(E.START,seed,level),initial=clone(full.initialState),b=runtime(initial);
   E.begin(b,b.coin);
   openings.push({id:`opening.${seed}.${level}`,seed,level,deck:clone(E.START),initial,after_begin:clone(E.snapshot(b)),phases:phases(b.events),boundary:'after_begin_before_optional_enemy_ai'});
  }
 }
 function clean(){const full=E.createBattle(E.START,1,2);const b=runtime(full.initialState);b.active='hero';for(const side of ['hero','enemy'])Object.assign(b[side],{phase:'main',turns:1,pendingDraw:0,drawDone:true,hand:[],deck:[...E.START],discard:[],hp:35,maxHp:35,block:0,ward:0,resonance:0,energy:10});return b;}
 for(const side of ['hero','enemy'])for(const resonance of [0,4,5,9,10,14,15])for(const first of [true,false]){
  const b=clean();b.active=side;b.coin=first?(side==='hero'?'enemy':'hero'):side;
  Object.assign(b[side],{turns:first?0:1,block:7,ward:24,resonance,burstUsed:true,cycled:true,tacticUsed:true,fortifyUsed:true,summons:2,attune:'ash'});
  const before=clone(E.snapshot(b));E.begin(b,side);
  begins.push({id:`begin.${side}.${resonance}.${first}`,side,before,after:clone(E.snapshot(b)),phases:phases(b.events)});
 }
 for(const side of ['hero','enemy'])for(const style of ['empty','waiting','ready','protected','lethal']){
  const b=clean();b.active=side;
  const op=side==='hero'?'enemy':'hero';
  if(style!=='empty')b[side].lanes[0]={id:'ash-1',hp:4,atk:style==='lethal'?40:3,summoned:style==='waiting',stun:0};
  if(style==='protected')Object.assign(b[op],{block:1,ward:2});
  const before=clone(E.snapshot(b)),first=b.events.length;
  const accepted=E.endTurn(b,side);const emitted=b.events.slice(first);
  const transitions=phases(emitted);
  // Actual original log snapshots expose the boundary before automatic enemyTurn.
  // Never replace the reference closure or reimplement the phase transition.
  const ownPhases=transitions.slice(0,4);
  let boundary=E.snapshot(b);
  if(side==='hero'&&b.winner===null){
   const next=transitions.findIndex(e=>e.kind==='begin');
   boundary=transitions[next+1]?.kind==='draw_finished'?transitions[next+1].state:transitions[next].state;
  }
  advances.push({id:`advance.${side}.${style}`,side,before,accepted,after:clone(boundary),phases:clone(ownPhases),boundary:'before_optional_enemy_ai'});
 }
 for(const block of [0,3])for(const ward of [0,4])for(const n of [-1,0,2,2.8,5,10,100])for(const pierce of [false,true]){
  const p={hp:35,block,ward},before={...p},lost=E.damage(p,n,pierce);
  damage.push({id:`damage.${block}.${ward}.${n}.${pierce}`,before,amount:n,pierce,lost,after:p});
 }
 return clone({schema_version:1,source:SOURCE,notice:'New immutable P01-P04 boundaries, not full createBattle/AI or replay parity. Existing PR #2 goldens remain unchanged.',randoms,openings,begins,advances,damage});
}
function main(){
 const file=path.join(ROOT,'tests/fixtures/legacy/engine_p01_p04.json'),bytes=JSON.stringify(products(),null,2)+'\n';
 if(process.argv.includes('--write-new')){if(fs.existsSync(file))throw Error('Refusing to overwrite existing golden; add a versioned reviewed fixture instead');fs.writeFileSync(file,bytes);}
 else if(!fs.existsSync(file)||fs.readFileSync(file,'utf8')!==bytes)throw Error('P01-P04 golden drift (no implicit overwrite)');
 const data=JSON.parse(bytes);console.log('ENGINE GOLDENS:',Object.fromEntries(['randoms','openings','begins','advances','damage'].map(k=>[k,data[k].length])));
}
if(require.main===module)main();
module.exports={products,runtime,phases};
