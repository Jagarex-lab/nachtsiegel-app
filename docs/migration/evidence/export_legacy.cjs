// Audit-only exporter/probe. Does not edit either game's sources or saves.
// node docs/migration/evidence/export_legacy.cjs /path/to/duel-deck output.json
'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const cp=require('node:child_process'),crypto=require('node:crypto');
const repo=path.resolve(process.argv[2]),out=path.resolve(process.argv[3]);
const E=require(path.join(repo,'engine.js'));
let assertions=0;
function check(actual,expected){assert.deepEqual(actual,expected);assertions++;}
function battle(){const b=E.createBattle(E.START,1,2);for(const side of ['hero','enemy'])Object.assign(b[side],{lanes:Array(5).fill(null),hp:35,maxHp:35,block:0,ward:0,weak:0,resonance:0,seals:0});return b;}
const vectors=[];
for(const side of ['hero','enemy'])for(const mode of ['empty','protected','occupied','newly_summoned']){
  const b=battle(),other=side==='hero'?'enemy':'hero';
  b[side].lanes[0]={id:'ash-1',hp:4,atk:10,summoned:mode==='newly_summoned',stun:0};
  if(mode==='protected')Object.assign(b[other],{block:3,ward:4});
  if(mode==='occupied')b[other].lanes[0]={id:'ash-1',hp:4,atk:1,summoned:false,stun:0};
  E.attackPhase(b,side);
  const expectedHP=mode==='empty'?25:mode==='protected'?32:35;
  check(b[other].hp,expectedHP);
  check(b[other].lanes[0],null);
  vectors.push({side,mode,attack:10,initial_hp:35,block:mode==='protected'?3:0,ward:mode==='protected'?4:0,target_hp:mode==='occupied'?4:null,legacy_hp:b[other].hp,legacy_block:b[other].block,legacy_ward:b[other].ward});
}
for(const [n,pierce,expected] of [[2,false,{hp:35,block:1,ward:4}],[5,false,{hp:35,block:0,ward:2}],[10,false,{hp:32,block:0,ward:0}],[10,true,{hp:25,block:3,ward:4}]]){
  const p={hp:35,block:3,ward:4};E.damage(p,n,pierce);check(p,expected);
}
// Each actual card definition can be summoned; this is smoke coverage, not
// semantic proof of every effect and not a Godot parity assertion.
for(const c of E.CARDS){const b=battle();Object.assign(b.hero,{phase:'main',hand:[c.id],energy:10,summons:0});b.active='hero';check(E.play(b,'hero',0,2),true);}
const data={schema:'legacy-parity-audit/1',source:{repository:'Jagarex-lab/duel-deck',commit:cp.execFileSync('git',['-C',repo,'rev-parse','HEAD'],{encoding:'utf8'}).trim(),engine_sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(repo,'engine.js'))).digest('hex')},cards:E.CARDS,presets:E.PRESETS,start:E.START,vectors,probe_assertions:assertions};
fs.writeFileSync(out,JSON.stringify(data,null,2)+'\n');
console.log(`LEGACY AUDIT PROBES: ${assertions} assertions, 0 failures; ${E.CARDS.length} actual cards, ${vectors.length} attack vectors`);
