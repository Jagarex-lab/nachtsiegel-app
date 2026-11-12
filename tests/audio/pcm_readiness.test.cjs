'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs');
const {freshPcmReady,silencePcmReady}=require('./pcm_readiness.cjs');
function fixture(){
 const current={state:'running',current_time:14,generation:4,epoch:1,destination_sources:1};
 const probe={contexts:[current],meterErrors:[],peak:0,rms:0,meterMessages:Array.from({length:30},(_,i)=>({context:0,generation:4,at:11+i*.08,maxRms:.02}))};
 return {probe,audio:{unlocked:true,suspended:false,active_voices:0,settings:{muted:false,master:1,music:.37},music:{playing:1,suspended:false}},sample:{before:[{current_time:9,generation:4}],cutoffs:[{current_time:10,generation:4}],quiet:[{current_time:10,generation:4,epoch:1}]}};
}
function observe(value){
 return vm.runInNewContext('('+freshPcmReady.toString()+')',{window:{__audioQAProbe:()=>value.probe,orafoldQA:{audio:value.audio}}})(value.sample);
}
test('fresh audio-thread PCM proves continuing music even when instantaneous analyser samples are zero',()=>{
 const value=fixture(),result=observe(value);assert(result);assert(result.observations[0].positive_span>=1);assert(result.observations[0].positive_blocks>=6);assert.equal(result.probe.rms,0);
});
test('actual retained5654 failed resume report has fresh audible PCM, without relabelling its CI failure',()=>{
 const value=JSON.parse(fs.readFileSync(new URL('./fixtures/5654-resume-pcm.json',require('node:url').pathToFileURL(__filename))));
 // Static counterexample from the recorded earlier no-voice pause endpoint;
 // this is not a newly observed resume or a passing replacement for its CI run.
 value.sample.quiet=value.sample.cutoffs;
 assert.match(value.provenance.original_failure,/Timeout 10000ms/);assert.equal(value.provenance.job_id,130758059381);
 assert.equal(value.probe.rms,0);const result=observe(value);assert(result);assert.equal(result.observations[0].positive_blocks,122);assert(result.observations[0].positive_span>10);
});
test('silent output never passes using historical peaks or already consumed blocks',()=>{
 const value=fixture();value.sample.cutoffs[0].current_time=14;value.probe.peak=.9;assert.equal(observe(value),false);
 value.probe.meterMessages=value.probe.meterMessages.map(block=>({...block,at:15,maxRms:0}));value.probe.contexts[0].current_time=16;assert.equal(observe(value),false);
});
test('old generations, old epochs, future blocks and nonfinite PCM cannot prove resumed output',()=>{
 for(const mutate of [v=>v.probe.meterMessages.forEach(b=>b.generation=3),v=>v.probe.contexts[0].epoch=14,v=>v.probe.meterMessages.forEach(b=>b.at=15),v=>v.probe.meterMessages.forEach(b=>b.maxRms=NaN),v=>v.probe.meterMessages.forEach(b=>b.at=Infinity)]){
  const value=fixture();mutate(value);assert.equal(observe(value),false);
 }
});
test('one UI-confirm cue cannot satisfy a full second of positive PCM',()=>{
 const value=fixture();value.probe.meterMessages=value.probe.meterMessages.slice(0,6);assert.equal(observe(value),false);
});
test('old sparse UI output cannot satisfy readiness after the first no-voice observation',()=>{
 const value=fixture();delete value.sample.quiet;value.audio.active_voices=1;assert.equal(observe(value),false);
 value.audio.active_voices=0;assert.equal(observe(value),false,'the first quiet poll arms an actual new cutoff');
 assert.equal(value.sample.quiet[0].current_time,14);assert.equal(observe(value),false,'previous UI blocks spanning seconds remain excluded');
 value.probe.contexts[0].current_time=17;value.probe.meterMessages=Array.from({length:30},(_,i)=>({context:0,generation:4,at:14.2+i*.08,maxRms:.02}));
 assert(observe(value),'new continuing music after quiescence can pass');
 value.audio.suspended=true;assert.equal(observe(value),false);value.audio.suspended=false;
 assert.equal(observe(value),false,'another pause invalidates the previous quiet boundary');
});
test('freshness starts after the completed action as well as its pre-action marker',()=>{
 const value=fixture();value.sample.cutoffs[0].current_time=13.5;assert.equal(observe(value),false,'opening/click audio before completion is excluded');
});
test('muting, pausing, stopped music, transient voices or a disconnected graph never pass',()=>{
 for(const mutate of [v=>v.audio.unlocked=false,v=>v.audio.suspended=true,v=>v.audio.settings.muted=true,v=>v.audio.settings.master=0,v=>v.audio.settings.music=0,v=>v.audio.music.playing=0,v=>v.audio.music.suspended=true,v=>v.audio.active_voices=1,v=>v.probe.contexts[0].state='suspended',v=>v.probe.contexts[0].destination_sources=0]){
  const value=fixture();mutate(value);assert.equal(observe(value),false);
 }
});
test('a still-playing pool is isolated only with actual muted SFX/UI buses, zero gains and no ambience',()=>{
 const make=()=>{const v=fixture();v.audio.active_voices=2;Object.assign(v.audio.settings,{sfx:0,ui:0,ambience:0});v.audio.buses={sfx:{muted:true},ui:{muted:true},ambience:{muted:true}};return v;};
 assert(observe(make()),'the actual UI/SFX-only pool is inaudible with both verified gates');
 for(const mutate of [v=>v.audio.settings.sfx=.1,v=>v.audio.settings.ui=.1,v=>v.audio.settings.ambience=.1,v=>v.audio.buses.sfx.muted=false,v=>v.audio.buses.ui.muted=false,v=>v.audio.buses.ambience.muted=false]){
  const v=make();mutate(v);assert.equal(observe(v),false,'partial or contradictory mute never provides isolation');
 }
});
test('an independent observer error fails instead of accepting runtime flags',()=>{
 const value=fixture();value.probe.meterErrors=['meter processor failed'];assert.throws(()=>observe(value),/Independent PCM observer failed/);
});
test('a real new routing generation can pass only with its own fresh post-epoch PCM',()=>{
 const value=fixture();value.probe.contexts[0].generation=5;value.probe.contexts[0].epoch=11;
 assert.equal(observe(value),false);value.probe.contexts[0].current_time=17;
 value.probe.meterMessages=Array.from({length:30},(_,i)=>({context:0,generation:5,at:14.2+i*.08,maxRms:.02}));assert(observe(value));
});
function silentFixture(rate,count){
 const step=2048/rate;
 const probe={contexts:[{state:'running',current_time:12,generation:4,epoch:1,destination_sources:1,sample_rate:rate}],meterMessages:Array.from({length:count},(_,i)=>({context:0,generation:4,at:11+i*step,maxRms:0}))};
 return {probe,sample:{since:[10],last:0}};
}
function observeSilence(value){
 return vm.runInNewContext('('+silencePcmReady.toString()+')',{window:{__audioQAProbe:()=>value.probe,orafoldQA:{}},performance:{now:()=>1000},console:{debug(){}}})(value.sample);
}
test('48kHz and96kHz actual block intervals retain six-block and0.2second silence requirements',()=>{
 assert(observeSilence(silentFixture(48000,6)));
 const short=silentFixture(96000,8);assert.equal(observeSilence(short),false,'eight96kHz blocks span only0.149seconds');
 assert(observeSilence(silentFixture(96000,11)),'eleven actual96kHz blocks span0.213seconds');
});
test('a positive or invalid block resets the consecutive silence suffix',()=>{
 for(const amplitude of [.02,NaN,-.1]){
  const value=silentFixture(96000,20);value.probe.meterMessages[16].maxRms=amplitude;assert.equal(observeSilence(value),false);
  value.probe.meterMessages.push(...Array.from({length:11},(_,i)=>({context:0,generation:4,at:11.5+i*.02134,maxRms:0})));assert(observeSilence(value));
 }
});
test('old generation, pre-cutoff and future silent blocks cannot prove current silence',()=>{
 for(const mutate of [v=>v.probe.meterMessages.forEach(b=>b.generation=3),v=>v.sample.since[0]=12,v=>v.probe.meterMessages.forEach(b=>b.at+=10)]){
  const value=silentFixture(48000,12);mutate(value);assert.equal(observeSilence(value),false);
 }
});
