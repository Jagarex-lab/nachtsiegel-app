'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {ROOT,SOURCE,load,verify}=require('../tools/legacy/reference.cjs');
const {products}=require('../tools/legacy/generate.cjs');
const {canonical,difference}=require('../tools/legacy/compare.cjs');
const read=name=>JSON.parse(fs.readFileSync(path.join(ROOT,name),'utf8'));
const plain=value=>JSON.parse(JSON.stringify(value));
test('reference pin rejects wrong commit, changed bytes and changed blob',()=>{
 const bytes=fs.readFileSync(path.join(ROOT,'tests/reference/duel_deck/engine.js'));
 verify(SOURCE,bytes);
 assert.throws(()=>verify({...SOURCE,commit:'0'.repeat(40)},bytes),/pin mismatch/);
 assert.throws(()=>verify(SOURCE,Buffer.concat([bytes,Buffer.from('\n')])) ,/SHA-256 mismatch/);
 assert.throws(()=>verify({...SOURCE,git_blob:'0'.repeat(40)},bytes),/pin mismatch/);
 const E=load();E.CARDS[0].hp=999;assert.notEqual(load().CARDS[0].hp,999,'fresh VM isolates reference mutation');
});
test('all six generated outputs are deterministic and current, byte for byte',()=>{
 const first=products(),second=products();assert.deepEqual(first,second);
 for(const [file,content] of Object.entries(first))assert.equal(fs.readFileSync(path.join(ROOT,file),'utf8'),content,file);
});
test('100 rule records and separated original labels match every upstream field',()=>{
 const original=plain(load().CARDS),rules=read('data/legacy/cards.json'),text=read('data/legacy/display_de.json');
 assert.equal(rules.runtime_enabled,false);assert.equal(rules.cards.length,100);
 assert.equal(new Set(rules.cards.map(c=>c.id)).size,100);
 assert.equal(rules.cards.filter(c=>c.rarity==='legendary').length,4);
 assert.equal(rules.cards.filter(c=>c.kind==='creature').length,100);
 for(const [i,c] of original.entries()){
  const {name,desc,...rule}=c;assert.deepEqual(rules.cards[i],rule,c.id);
  assert.deepEqual(text.cards[c.id],{name,description:desc},c.id);
  assert(!Object.hasOwn(rules.cards[i],'name'));assert(!Object.hasOwn(rules.cards[i],'desc'));
 }
 assert.deepEqual(read('tests/fixtures/legacy/cards.json').cards,original);
 assert.equal(rules.cards.find(c=>c.id==='tide-12').atk,2);
 assert.equal(rules.cards.find(c=>c.id==='veil-18').cost,2);
});
test('five original decks preserve order, size, IDs and original validation outcomes',()=>{
 const E=load(),data=read('data/legacy/decks.json'),fixture=read('tests/fixtures/legacy/decks.json');
 assert.equal(data.decks.length,5);
 const expected=[{id:'start',cards:plain(E.START)},...plain(E.PRESETS).map(p=>({id:p.id,cards:p.cards}))];
 assert.deepEqual(data.decks,expected);
 for(const d of data.decks){assert.equal(d.cards.length,25);assert.equal(E.validateDeck(d.cards),'');}
 for(const v of fixture.validation_cases)assert.equal(E.validateDeck(v.deck,v.owned),v.expected_error,v.id);
});
test('canonical comparison preserves JSON types, null/missing and array order',()=>{
 assert.equal(difference({a:1,b:{z:null,x:[1,2]}},{b:{x:[1,2],z:null},a:1}),null);
 assert.equal(difference(1,1.0),null);assert.equal(difference(-0,0),null);
 for(const [e,a,why] of [[{hp:1},{},'missing'],[{hp:null},{},'null is not missing'],[{hand:[1,2]},{hand:[2,1]},'order'],[{id:'ash-0'},{id:'ash-1'},'id'],[{hp:1},{hp:'1'},'type'],[true,1,'bool'],[{a:1},{a:1,b:2},'extra']])assert(difference(e,a),why);
 assert.equal(difference({'a/b~':1},{'a/b~':2}).path,'$/a~1b~0');
 for(const value of [undefined,NaN,Infinity,2**53,1n,new Date()])assert.throws(()=>canonical(value));
 assert.notEqual(JSON.stringify({a:1,b:2}),JSON.stringify({b:2,a:1}),'raw serialization remains distinct');
});
test('transition fixture covers all 11 commands, legal and rejected; all effects and reactions',()=>{
 const t=read('tests/fixtures/legacy/transitions.json'),steps=t.cases.flatMap(c=>c.steps);
 for(const command of t.commands){assert(steps.some(s=>s.command===command&&s.accepted),command+' accepted');assert(steps.some(s=>s.command===command&&!s.accepted),command+' rejected');}
 for(const effect of Object.keys(load().KINDS))assert(t.cases.some(c=>c.id==='effect.summon.'+effect),effect);
 assert.equal(t.cases.filter(c=>c.id.startsWith('reaction.')).length,12);
 assert.equal(t.openings.length,6);assert.equal(new Set(t.openings.map(o=>o.initial.coin)).size,2);
 for(const step of steps){assert(step.before.hero&&step.before.enemy);assert(step.after.hero&&step.after.enemy);assert.equal(step.before.hero.lanes.length,5);if(!step.accepted)assert.equal(difference(step.before,step.after),null,'rejection must not mutate state');}
 const after=id=>t.cases.find(c=>c.id===id).steps[0].after;
 assert.equal(after('attack.hero.protected').enemy.hp,32);
 assert.equal(after('attack.enemy.protected').hero.hp,32);
 assert.equal(after('attack.hero.newly_summoned').enemy.hp,35);
 assert.equal(after('attack.hero.empty').enemy.hp,25);
 assert.equal(after('attack.hero.occupied').enemy.hp,35);
 assert.equal(after('draw.fatigue.empty').hero.hp,32);
 assert.equal(after('draw.effect.empty_no_fatigue').hero.hp,35);
 assert.equal(after('victory.path.enemy').winner,'enemy');
 assert.equal(after('effect.drain.absorbed_no_heal').hero.hp,20);
 assert.equal(after('effect.ward.cap').hero.ward,25);
 assert.equal(after('effect.weave.cap').hero.resonance,15);
 assert.equal(after('begin.energy.resonance_15').hero.energy,5);
 assert.equal(after('block.retained_during_other_begin').hero.block,8);
 assert.equal(after('victory.stops_later_lanes').enemy.lanes[1].hp,4);
 for(const id of ['legacy_edge.burn_has_no_winner_guard','legacy_edge.skip_has_no_winner_guard','legacy_edge.recover_while_target_pending'])assert.equal(t.cases.find(c=>c.id===id).steps[0].accepted,true,id+' is preserved, not hardened');
});
test('reordered object fields pass, missing HP, changed target and shuffled deck fail on actual fixtures',()=>{
 const t=read('tests/fixtures/legacy/transitions.json');const original=t.cases.find(c=>c.id==='play.valid.cost_and_hand').steps[0].after;
 const reordered=Object.fromEntries(Object.entries(original).reverse());assert.equal(difference(original,reordered),null);
 const changed=plain(original);delete changed.hero.hp;assert.equal(difference(original,changed).reason,'missing_or_extra_field');
 const shuffled=plain(original);[shuffled.hero.deck[0],shuffled.hero.deck[1]]=[shuffled.hero.deck[1],shuffled.hero.deck[0]];assert(difference(original,shuffled));
 const target=plain(original);target.hero.lanes[0].id='veil-1';assert(difference(original,target));
});

test('legacy namespace is confined to explicit archive runtime and historical deck validation; seven-card prototype stays isolated',()=>{
 function walk(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(entry=>entry.isDirectory()?walk(path.join(dir,entry.name)):[path.join(dir,entry.name)]);}
 const files=[path.join(ROOT,'project.godot'),...walk(path.join(ROOT,'scripts')).filter(p=>p.endsWith('.gd')&&!p.includes(path.join('scripts','legacy')+path.sep)&&!p.includes(path.join('scripts','alpha')+path.sep)),...walk(path.join(ROOT,'scenes')).filter(p=>p.endsWith('.tscn'))];
 for(const file of files){
  const relative=path.relative(ROOT,file),content=fs.readFileSync(file,'utf8');
  if(relative===path.join('scripts','production','profile_store.gd')){
   // The production store must still validate preserved historical decks. This
   // precise dependency does not activate the Legacy catalog in the collection.
   assert.deepEqual(content.match(/res:\/\/(?:scripts|data)\/legacy\/[^"\s]+/g),['res://scripts/legacy/deck_validator.gd'],relative);
   assert.match(content,/if mode=="legacy":return LegacyValidator\.new\(\)\.validate\(ids\)/);
  }else assert(!/res:\/\/(?:scripts|data)\/legacy\//.test(content),relative);
 }
});
