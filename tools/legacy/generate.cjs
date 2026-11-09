'use strict';
const fs=require('node:fs'),path=require('node:path');
const {ROOT,SOURCE,load,verifyCheckout}=require('./reference.cjs');
const {scenarios}=require('./scenarios.cjs');
const clone=v=>JSON.parse(JSON.stringify(v));
function products(){
  const E=load();
  const envelope=data=>({schema_version:1,source:SOURCE,...clone(data)});
  const rules=E.CARDS.map(({name,desc,...rule})=>rule);
  const labels=Object.fromEntries(E.CARDS.map(c=>[c.id,{name:c.name,description:c.desc}]));
  const decks=[{id:'start',cards:[...E.START]},...E.PRESETS.map(p=>({id:p.id,cards:[...p.cards]}))];
  const cases=[];
  const own=Object.fromEntries(E.CARDS.map(c=>[c.id,3]));
  function validation(id,deck,owned=null){cases.push({id,deck,owned,expected_error:E.validateDeck(deck,owned)});}
  validation('length.19',E.START.slice(0,19));validation('length.20',E.START.slice(0,20));validation('length.25',E.START);validation('length.26',[...E.START,'ash-6']);
  validation('type.null',null);validation('type.string','ash-0');
  validation('unknown',[...E.START.slice(0,19),'missing-id']);
  for(const rarity of ['common','rare','epic','legendary']){
    const id=E.CARDS.find(c=>c.rarity===rarity).id;
    const limit=rarity==='legendary'?1:3;
    const rest=E.START.filter(c=>c!==id);
    validation(`copies.${rarity}.at_limit`,[...Array(limit).fill(id),...rest.slice(0,20-limit)]);
    validation(`copies.${rarity}.over_limit`,[...Array(limit+1).fill(id),...rest.slice(0,19-limit)]);
  }
  validation('ownership.exact',E.START,Object.fromEntries(E.START.map(id=>[id,1])));
  validation('ownership.empty',E.START,{});
  validation('ownership.missing_one',E.START,{...own,[E.START[0]]:0});
  validation('ownership.insufficient_copies',[...Array(3).fill('ash-0'),...E.START.filter(id=>id!=='ash-0').slice(0,17)],{...own,'ash-0':2});
  for(const deck of decks)validation('preset.'+deck.id,deck.cards,own);
  const opening=[];
  for(const seed of [1,2147483648])for(const level of [1,2,5]){
    const b=E.createBattle(E.START,seed,level);
    opening.push({seed,level,initial:clone(b.initialState),ready:clone(E.snapshot(b)),events:clone(b.events)});
  }
  const files={
    'tests/fixtures/legacy/cards.json':envelope({cards:E.CARDS,orders:E.ORDERS}),
    'tests/fixtures/legacy/decks.json':envelope({start:E.START,presets:E.PRESETS,validation_cases:cases}),
    'tests/fixtures/legacy/transitions.json':envelope({setup_notice:'Controlled states are synthetic and not full-match replay exports. All outputs are from the pinned JS engine. No Godot transition parity is claimed.',commands:['play','endTurn','burst','recover','burn','finishDraw','moveCreature','skipShift','chooseStrikeTarget','tacticalMove','fortify'],openings:opening,cases:scenarios(E)}),
    'data/legacy/cards.json':envelope({ruleset_id:'duel-deck-34b3062',runtime_enabled:false,cards:rules}),
    'data/legacy/display_de.json':envelope({locale:'de',cards:labels,orders:E.ORDERS,decks:Object.fromEntries([{id:'start',name:'START',description:'Original START deck'},...E.PRESETS].map(p=>[p.id,{name:p.name,description:p.description}]))}),
    'data/legacy/decks.json':envelope({ruleset_id:'duel-deck-34b3062',decks})
  };
  return Object.fromEntries(Object.entries(files).map(([name,data])=>[name,JSON.stringify(data,null,2)+'\n']));
}
function main(){
  const args=process.argv.slice(2);const checkout=args.indexOf('--verify-checkout');
  if(checkout>=0){if(!args[checkout+1])throw Error('Missing checkout path');verifyCheckout(args[checkout+1]);}
  const check=args.includes('--check');const files=products();
  for(const [name,bytes] of Object.entries(files)){
    const dest=path.join(ROOT,name);
    if(check){if(!fs.existsSync(dest)||fs.readFileSync(dest,'utf8')!==bytes)throw Error('Generated data drift: '+name);}
    else{fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes);}
  }
  const fixture=JSON.parse(files['tests/fixtures/legacy/transitions.json']);
  console.log(`LEGACY GENERATOR: ${Object.keys(files).length} files ${check?'verified byte-for-byte':'generated'}; ${fixture.cases.length} controlled cases, ${fixture.cases.reduce((n,c)=>n+c.steps.length,0)} steps, ${fixture.openings.length} openings; pinned ${SOURCE.commit}`);
}
if(require.main===module)main();
module.exports={products};
