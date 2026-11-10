'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {ROOT,load,SOURCE}=require('../tools/legacy/reference.cjs');
const {products,compress}=require('../tools/legacy/generate_p05_p06.cjs');
const {products:edges}=require('../tools/legacy/generate_p05_p06_edges.cjs');
const {products:lifecycle}=require('../tools/legacy/generate_p05_p06_lifecycle.cjs');
const {difference}=require('../tools/legacy/compare.cjs');
test('P05/P06 fixtures reproduce original JS byte-for-byte, without rewriting old goldens',()=>{
 for(const [name,fn]of [['p05_p06_v1.json',products],['p05_p06_edges_v1.json',edges],['p05_p06_lifecycle_v1.json',lifecycle]]){
  const data=fn();assert.deepEqual(data,fn());assert.deepEqual(data.source,SOURCE);
  assert.equal(fs.readFileSync(path.join(ROOT,'tests/fixtures/legacy',name),'utf8'),JSON.stringify(data,null,2)+'\n');
 }
});
test('all100 actual cards and16 effects are represented on both sides, as first summons',()=>{
 const E=load(),all=products().cases;
 for(const side of ['hero','enemy'])for(const card of E.CARDS){
  const item=all.find(c=>c.id===`card.${side}.${card.id}`);assert(item,side+'/'+card.id);
  const step=item.steps[0];assert.equal(step.result.value,true);assert.equal(step.command,'play');
  assert.equal(step.after[side].lanes[2].id,card.id);assert.equal(step.after[side].energy,20-card.cost);assert.equal(step.after[side].summons,1);
 }
 assert.equal(new Set(E.CARDS.map(c=>c.effect)).size,16);
});
test('ordered state-sequence comparison detects field tampering and event reordering',()=>{
 const sequence=products().cases[0].steps[0].state_sequence;assert(sequence.length>1);
 const changed=structuredClone(sequence);changed[1].state.hero.energy++;
 assert(difference(sequence,changed));
 const wrong=structuredClone(sequence).reverse();assert(difference(sequence,wrong));
 const a={state:{hp:1},pendingDeath:null},b={state:{hp:2},pendingDeath:null};
 assert.deepEqual(compress([a,a,b,b,a]),[a,b,a],'only adjacent identical observations collapse');
});
test('known raw finishDraw rejection mutations are explicitly isolated, not misreported as immutable',()=>{
 const all=products().cases;const found=all.flatMap(c=>c.steps.filter(s=>s.reference_mutates_on_reject).map(s=>({id:c.id,step:s})));
 assert.equal(found.length,2);for(const {id,step}of found){assert(id.startsWith('draw.recycle_before_reject.'));assert.equal(step.result.value,false);assert.equal(step.after[step.args[0]].cycles,1);assert.equal(step.after[step.args[0]].hp,34);assert(difference(step.before,step.after));}
});
test('effect-side tie breaking and off-lane user targets match actual reference',()=>{
 const all=edges().cases;
 const hero=all.find(c=>c.id==='strike.tie_and_offlane.hero').steps.at(-1).after;
 const enemy=all.find(c=>c.id==='strike.tie_and_offlane.enemy').steps.at(-1).after;
 assert.equal(hero.enemy.lanes[4],null);assert(hero.enemy.lanes[1]);
 assert.equal(enemy.hero.lanes[1],null);assert(enemy.hero.lanes[4]);
});

test('same card may die again after actual recovery/recycling without duplicate-death conflation',()=>{
 const all=lifecycle().cases;assert.equal(all.length,6);
 for(const c of all){assert(c.steps[0].result.value);const after=c.steps.at(-1).after;assert.equal(after[c.side].discard.length,1);assert.equal(after[c.side].lanes[2],null);assert(c.steps.some(s=>s.command==='recover'||s.command==='begin'));}
});
