'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),vm=require('node:vm');
const {campaignHeaderReady}=require('../../tools/premium/campaign_header_contract.cjs');
const nav=['Kapitelübersicht','Rückblick','Charaktere','Leseeinstellungen','Hauptmenü'];
function portrait(){return {q:{hosted_page:'campaign',layout_size:[390,844],portrait:true,hosted_actions:nav.map((text,i)=>({text,disabled:false,rect:i===4?[16,205,358,52]:[16+(i%2)*183,85+Math.floor(i/2)*60,175,52]}))},c:{screen:'overview',logical_viewport:[390,844],compact:true,flags:{}}};}
function landscape(){return {q:{hosted_page:'campaign',layout_size:[844,390],portrait:false,hosted_actions:nav.map((text,i)=>({text,disabled:false,rect:[12+i*165,60,157,52]}))},c:{screen:'overview',logical_viewport:[844,390],compact:false,flags:{}}};}
function fixture(size={width:390,height:844},rows=3){
 const store={'orafold.campaign.v2':'original campaign save','orafold.economy.sandbox.production':'original economy save'};Object.defineProperty(store,'getItem',{value:key=>store[key]??null});
 const canvas={width:size.width*2,height:size.height*2,getBoundingClientRect:()=>({width:size.width,height:size.height})};
 const sandbox={window:{},document:{querySelector:()=>canvas},localStorage:store};
 const predicate=vm.runInNewContext('('+campaignHeaderReady.toString()+')',sandbox);
 const sample={size,nav,rows};
 return {sample,sandbox,canvas,store,set(state){sandbox.window.orafoldQA=state.q;sandbox.window.orafoldCampaignQA=state.c;return predicate(sample);}};
}
test('actual CI old Shell844x390 with new Campaign390x844 is rejected before fresh portrait acceptance',()=>{
 const f=fixture(),mixed=landscape();mixed.c=portrait().c;
 assert.deepEqual(mixed.q.hosted_actions[2].rect,[342,60,157,52],'exact CI Charaktere rectangle');
 assert.equal(f.set(mixed),false);assert.equal(f.set(mixed),false);
 assert.equal(f.set(portrait()),false);const ready=f.set(portrait());assert.equal(ready.readiness.matching_pairs,2);assert.equal(ready.q.layout_size[0],390);
});
test('one repeated publication pair never counts as two matching layouts',()=>{
 const f=fixture(),state=portrait();assert.equal(f.set(state),false);
 for(let i=0;i<20;i++)assert.equal(f.set(state),false);
 assert.equal(f.sample.matching_pairs,1);assert(f.set(portrait()));
});
test('freshness requires both channels rather than only a fresh Shell or Campaign report',()=>{
 const f=fixture(),first=portrait();assert.equal(f.set(first),false);
 assert.equal(f.set({q:portrait().q,c:first.c}),false);
 assert.equal(f.set({q:first.q,c:portrait().c}),false);
 assert.equal(f.sample.matching_pairs,1);assert(f.set(portrait()));
});
test('coherent dimensions cannot hide invalid44px, disabled, outside or missing navigation',()=>{
 const changes=[s=>s.q.hosted_actions[2].rect[2]=43,s=>s.q.hosted_actions[2].rect[3]=43,s=>s.q.hosted_actions[2].rect[0]=-1,s=>s.q.hosted_actions[2].rect[0]=342,s=>s.q.hosted_actions[2].disabled=true,s=>s.q.hosted_actions.splice(2,1),s=>s.q.hosted_actions[2].rect[0]=NaN];
 for(const mutate of changes){const f=fixture();for(let i=0;i<3;i++){const s=portrait();mutate(s);assert.equal(f.set(s),false);}assert.equal(f.sample.matching_pairs,0);}
});
test('consistent viewport but wrong HFlow row count never becomes ready',()=>{
 const f=fixture();for(let i=0;i<3;i++){const s=portrait();s.q.hosted_actions[2].rect[1]=s.q.hosted_actions[3].rect[1]=85;assert.equal(f.set(s),false);}assert.equal(f.sample.matching_pairs,0);
});
test('viewport, compact, portrait and actual backing must all agree with requested CSS dimensions',()=>{
 for(const mutate of [s=>s.q.layout_size=[844,390],s=>s.c.logical_viewport=[844,390],s=>s.q.portrait=false,s=>s.c.compact=false]){const f=fixture();for(let i=0;i<2;i++){const s=portrait();mutate(s);assert.equal(f.set(s),false);}}
 for(const axis of ['width','height']){const f=fixture();f.canvas[axis]/=2;assert.equal(f.set(portrait()),false);assert.equal(f.set(portrait()),false);}
});
test('any intervening mixed or bad layout resets the two-publication requirement',()=>{
 const f=fixture();assert.equal(f.set(portrait()),false);const bad=portrait();bad.c.compact=false;assert.equal(f.set(bad),false);
 assert.equal(f.set(portrait()),false);assert(f.set(portrait()));
});
test('the exact matched snapshot and saved bytes are returned without product mutation or later reread',()=>{
 const f=fixture(),first=portrait();assert.equal(f.set(first),false);const second=portrait(),original=structuredClone(second),ready=f.set(second);
 assert.equal(ready.q,second.q);assert.equal(ready.c,second.c);assert.deepEqual(second,original);
 f.sandbox.window.orafoldQA=landscape().q;f.store['orafold.campaign.v2']='later save';
 assert.equal(ready.q.layout_size[0],390);assert.equal(ready.campaign_store,'original campaign save');assert.equal(ready.economies['orafold.economy.sandbox.production'],'original economy save');
});
test('actual landscape navigation accepts one row only after two complete fresh pairs',()=>{
 const f=fixture({width:844,height:390},1);assert.equal(f.set(landscape()),false);const ready=f.set(landscape());assert(ready);assert.equal(ready.q.portrait,false);assert.equal(ready.c.compact,false);
});
