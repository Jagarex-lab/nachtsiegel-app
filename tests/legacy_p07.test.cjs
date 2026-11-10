'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {ROOT,SOURCE,load}=require('../tools/legacy/reference.cjs'),{products}=require('../tools/legacy/generate_p07.cjs'),{products:edges}=require('../tools/legacy/generate_p07_edges.cjs'),{difference}=require('../tools/legacy/compare.cjs');
test('P07 goldens reproduce pinned JS bytes without replacing inherited fixtures',()=>{
 for(const [name,fn]of [['p07_v1.json',products],['p07_edges_v1.json',edges]]){
  const f=fn();assert.deepEqual(f,fn());assert.deepEqual(f.source,SOURCE);
  assert.equal(fs.readFileSync(path.join(ROOT,'tests/fixtures/legacy',name),'utf8'),JSON.stringify(f,null,2)+'\n');
 }
});
test('all100 cards execute real mixed-order two-summon chains on both sides',()=>{
 const all=products().cases,E=load();
 for(const side of ['hero','enemy'])for(const c of E.CARDS){
  const item=all.find(x=>x.id===`card_chain.${side}.${c.id}`);assert(item);
  assert(item.steps[0].result.value);assert(item.steps[1].result.value);
  const step=item.steps[1];assert.equal(step.after[side].lanes[2].id,c.id);assert.equal(step.after[side].attune,c.order);assert.equal(step.after[side].summons,2);
  assert.notEqual(step.before[side].attune,c.order);
 }
});
test('all12 directed reactions, same-order no-reaction and resource caps are represented',()=>{
 const all=products().cases;
 for(const side of ['hero','enemy'])for(const from of ['ash','tide','thorn','veil'])for(const to of ['ash','tide','thorn','veil'])for(const res of [0,14,15]){
  const step=all.find(c=>c.id===`reaction.${side}.${from}.${to}.res${res}`).steps[0];assert(step.result.value);
  const extra=from!==to?2+(['thorn>tide','tide>ash'].includes(from+'>'+to)?1:0):0;
  assert.equal(step.after[side].resonance,Math.min(15,res+extra));
 }
});
test('lethal reaction pays/places/attunes but prevents summon effect and followups',()=>{
 for(const c of products().cases.filter(c=>c.id.startsWith('lethal_reaction.'))){const step=c.steps[0],side=c.side;assert(step.result.value);assert.equal(step.after.winner,side);assert.equal(step.before[side].deck.length,step.after[side].deck.length);assert.equal(step.after[side].pendingTarget,null);assert(step.after[side].lanes[2]);assert.equal(step.after[side].attune,step.after[side].lanes[2].id.split('-')[0]);assert.equal(step.after[side==='hero'?'enemy':'hero'].discard.length,0);}
});
test('pending choice permits burst but rejects move/fortify; no fabricated blanket lock',()=>{
 for(const c of products().cases.filter(c=>c.id.startsWith('pending.'))){assert.equal(c.steps[0].result.value,c.id.endsWith('.burst'));}
});
test('positive burst reset, no tactic formation bonus, all rejected actions immutable',()=>{
 for(const c of edges().cases.filter(c=>c.id.startsWith('reset_to_legal_burst.'))){assert.equal(c.steps[3].result.value,false);assert.equal(c.steps.at(-1).result.value,true);}
 for(const c of edges().cases.filter(c=>c.id.startsWith('formation_vs_tactic.'))){assert.equal(c.steps[0].after[c.side].resonance,1);assert.equal(c.steps[1].result.value,false);}
 for(const c of [...products().cases,...edges().cases])for(const s of c.steps)if(s.result.value===false){assert.equal(s.reference_mutates_on_reject,false);assert.equal(difference(s.before,s.after),null);}
});
test('P07 reactions and special actions consume no original LCG RNG draws',()=>{
 let calls=0;const E=load({onImul:(a,b)=>{if(b===1664525)calls++;}}),{runtime}=require('../tools/legacy/generate_engine.cjs');
 const selected=products().cases.filter(c=>c.id.startsWith('reaction.')&&c.id.endsWith('.res0')||c.id.startsWith('burst.')&&c.id.includes('.n1.res15')||c.id.startsWith('move.')||c.id.startsWith('fortify.'));
 for(const c of selected){const step=c.steps[0];const b=runtime(step.before);E[step.command](b,...step.args);}
 assert(selected.length>40);assert.equal(calls,0);
});
