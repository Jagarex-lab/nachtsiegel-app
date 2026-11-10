'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const read=p=>JSON.parse(fs.readFileSync(path.resolve(__dirname,'../..',p),'utf8'));
const source=read('data/alpha/cards.json');
const metadata=read('data/card_system/alpha_species.json');
const registry=read('data/card_system/registry.json');
const pilot=read('data/card_system/pilot.json');

test('all 37 current creatures have one or two valid equal-rank species and a rationale',()=>{
  const creatures=source.cards.filter(c=>c.kind==='creature');
  assert.equal(creatures.length,37);
  assert.deepEqual(Object.keys(metadata.species_by_card_id).sort(),creatures.map(c=>c.id).sort());
  assert.deepEqual(Object.keys(metadata.rationale_de_by_card_id).sort(),creatures.map(c=>c.id).sort());
  for(const card of creatures){
    const types=metadata.species_by_card_id[card.id];
    assert(types.length>=1&&types.length<=2,card.id);
    assert.equal(new Set(types).size,types.length,card.id);
    for(const type of types)assert(Object.hasOwn(registry.species,type),card.id+': '+type);
    assert(metadata.rationale_de_by_card_id[card.id].includes(card.name),card.id);
  }
  assert.equal(Object.keys(registry.species).length,12,'full registry is supported without fabricating 12 species in this small pool');
});

test('editorial overlay preserves all existing pilot creature identities and excludes noncreatures',()=>{
  const creatures=pilot.cards.filter(c=>c.kind==='creature');
  assert.equal(creatures.length,5);
  for(const card of creatures)assert.deepEqual(metadata.species_by_card_id[card.id],card.species,card.id);
  for(const card of source.cards.filter(c=>c.kind!=='creature'))assert(!Object.hasOwn(metadata.species_by_card_id,card.id),card.id);
  assert.equal(metadata.status,'active_editorial_metadata_no_species_trigger_hooks');
  assert(metadata.scope_de.includes('noch nicht implementiert'));
  assert(metadata.equal_rank_de.includes('gleichwertig'));
});
