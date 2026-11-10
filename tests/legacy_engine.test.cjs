'use strict';
const crypto=require('node:crypto');
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process');
const {ROOT,SOURCE,verify,load}=require('../tools/legacy/reference.cjs');
const {products:engine}=require('../tools/legacy/generate_engine.cjs');
const {products:combat}=require('../tools/legacy/generate_combat.cjs');
const {products:turns}=require('../tools/legacy/generate_turns.cjs');
const {products:consumption}=require('../tools/legacy/generate_rng_consumption.cjs');
const {products:queueWinner}=require('../tools/legacy/generate_queue_winner.cjs');
const {difference}=require('../tools/legacy/compare.cjs');
function json(p){return JSON.parse(fs.readFileSync(path.join(ROOT,p),'utf8'));}
test('new engine/combat goldens reproduce pinned JS without touching old goldens',()=>{
 for(const [name,produce] of [['engine_p01_p04.json',engine],['combat_p04_v1.json',combat],['turns_p03_v1.json',turns],['rng_consumption_v1.json',consumption],['queue_winner_p04_v1.json',queueWinner]]){
  const generated=produce();assert.deepEqual(generated,produce());
  assert.equal(fs.readFileSync(path.join(ROOT,'tests/fixtures/legacy',name),'utf8'),JSON.stringify(generated,null,2)+'\n');
 }
 const files=['cards.json','decks.json','transitions.json'];
 const baseline=json('docs/migration/foundations-evidence/results.json').implementation_sha256;
 for(const name of files){const p='tests/fixtures/legacy/'+name;assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(ROOT,p))).digest('hex'),baseline[p]);}
});
test('reference corruption, changed RNG values, missing fields and changed card IDs are detected',()=>{
 const bytes=fs.readFileSync(path.join(ROOT,'tests/reference/duel_deck/engine.js'));
 assert.throws(()=>verify({...SOURCE,commit:'0'.repeat(40)},bytes));
 assert.throws(()=>verify(SOURCE,Buffer.concat([bytes,Buffer.from(' ')])));
 const original=engine();const changed=structuredClone(original);changed.randoms[0].states[0]++;
 assert(difference(original,changed));changed.randoms[0].states[0]--;
 changed.randoms[0].values[0]+=.001;assert(difference(original,changed));
 const without=structuredClone(original);delete without.openings[0].initial.coin;assert(difference(original,without));
 const wrong=structuredClone(original);wrong.openings[0].initial.hero.deck[0]='wrong-id';assert(difference(original,wrong));
});
test('RNG goldens are exact uint32 fractions, shuffles consume n-1 samples, both coin sides covered',()=>{
 const data=engine(),E=load();
 for(const item of data.randoms){
  const r=E.rng(item.seed);
  if(item.values){for(let i=0;i<item.values.length;i++){assert.equal(item.values[i],r());assert.equal(item.states[i]/4294967296,item.values[i]);assert(Number.isInteger(item.states[i]));}}
  else assert.deepEqual(Array.from(E.shuffle(item.input,r)),item.shuffled);
 }
 assert.equal(new Set(data.openings.map(o=>o.initial.coin)).size,2);
 for(const o of data.openings){assert.equal(o.initial.hero.deck.length,25);assert.equal(o.initial.enemy.deck.length,25);assert.equal(o.after_begin[o.initial.coin].hand.length,3);}
});
test('new fixture writer refuses implicit golden replacement',()=>{
 for(const file of ['generate_engine.cjs','generate_combat.cjs','generate_turns.cjs','generate_rng_consumption.cjs','generate_queue_winner.cjs']){
  const r=cp.spawnSync(process.execPath,[path.join(ROOT,'tools/legacy',file),'--write-new'],{cwd:ROOT,encoding:'utf8'});
  assert.notEqual(r.status,0);assert.match(r.stderr,/Refusing to overwrite/);
 }
});
test('FIFO golden is bounded at100 and captures original death and harvest states',()=>{
 const data=combat();assert.equal(data.combats.length,122);assert.equal(data.queues.length,8);
 for(const q of data.queues){
  assert.equal(q.deaths.length,Math.min(100,q.batch.length));assert.equal(q.remaining_queue,0);assert.equal(q.resolving,false);assert.equal(q.pending_death,null);
  assert.equal(q.limited,q.batch.length>100);
  for(let i=0;i<q.deaths.length;i++){assert.equal(q.deaths[i].pendingDeath.card,q.batch[i].unit.id);assert.equal(q.deaths[i].pendingDeath.side,q.batch[i].side);}
 }
 const draw=data.combats.filter(c=>c.id.startsWith('combat.draw.'));assert.equal(draw.length,2);for(const d of draw)assert.equal(d.after.winner,'draw');
});

test('manual phase sequences retain both states through multiple original turn boundaries',()=>{
 const data=turns();assert.equal(data.cases.length,2);
 for(const c of data.cases){assert(c.steps.length>=12);for(let i=1;i<c.steps.length;i++)assert.equal(difference(c.steps[i-1].after,c.steps[i].before),null);assert(c.steps.some(s=>s.command==='play'));assert(c.steps.some(s=>s.command==='finishDraw'));assert(c.steps.some(s=>s.command==='endTurn'));}
});

test('observed LCG calls match exact setup count including double enemy shuffle',()=>{
 const vectors=consumption().cases;assert.equal(vectors.length,36);
 for(const v of vectors){const count=1+(v.level<=2?75:95)+24+24;assert.equal(v.calls,count);}
});
