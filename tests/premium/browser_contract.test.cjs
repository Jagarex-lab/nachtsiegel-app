'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {masterActionGeometry}=require('../../tools/premium/master_input_contract.cjs');
const {nativeGeometry,assertNativeCapture,nativeCapture}=require('../../tools/premium/native_capture_contract.cjs');
const {clearTouchPoint,scrollGesture,assertPanContext,heldPanQuiet,settleHeldPan,battleGeometry,artReady,fullArtReady,premiumArt,playability}=require('../../tools/premium/browser_contract.cjs');
const vm=require('node:vm');
function fixture(){
 const board={};for(const [side,y]of [['enemy',48],['hero',140]])for(let lane=0;lane<5;lane++)board[side+lane]=[10+lane*164,y,156,84];
 const actions={};for(const [id,x,y,w]of [['menu',0,0,44],['actions',650,330,90],['end',650,230,180],['inspect',740,330,90]])actions[id]={rect:[x,y,w,44],disabled:false};
 const hand=Array.from({length:6},(_,i)=>({id:'card-'+i,rect:[10+i*96,242,88,123]}));
 return {page:'battle',portrait:false,battle:{hero:{hand:hand.map(c=>c.id)}},actions,board,hand,selected:-1,battle_art:hand.map(c=>({card_id:c.id,zone:'hand',visible:true,display_role:'hand',frame_concept:'folded',rarity:'common',title_fits:true,profile:'compact',status:'final',pending:false,pixels:[512,384],frame_rect:c.rect,illustration_rect:[c.rect[0]+3,c.rect[1]+20,82,73],visible_art_fraction:.55}))};
}
test('the real runner accepts ten distinct44px paths and six portrait cards',()=>{assert.equal(battleGeometry(fixture(),[0,0,844,390],{requireSix:true}).hand_cards,6);});
test('old wide text-strip hands fail rather than passing as premium cards',()=>{const q=fixture();q.hand[0].rect[2]=138;q.hand[0].rect[3]=70;assert.throws(()=>battleGeometry(q,[0,0,844,390]),/portrait collectible/);});
test('a concealed or overlapping path never passes touch geometry',()=>{const q=fixture();q.board.hero1=q.board.hero0;assert.throws(()=>battleGeometry(q,[0,0,844,390]));});
test('occluded hand cards need an exposed44px region rather than an AABB center',()=>{assert.deepEqual(clearTouchPoint([0,0,80,112],[[40,0,80,112]]),null);assert(clearTouchPoint([0,0,90,126],[[70,0,90,126]]));});
test('mobile scroll gestures use real unoccupied canvas space in the correct direction',()=>{
 const q={actions:{card:{rect:[10,1000,180,250]},visible:{rect:[10,100,180,250]}},action_visibility:{card:{clip_rect:[0,100,390,600]},visible:{clip_rect:[0,100,390,600]}}};
 const down=scrollGesture(q,'card');assert(down.to.y<down.from.y);assert(down.from.x>190,'the initial touch avoids the visible card');
 q.actions.card.rect[1]=-300;const up=scrollGesture(q,'card');assert(up.to.y>up.from.y);
 q.actions.card.rect=[-50,120,44,44];assert.throws(()=>scrollGesture(q,'card'),/horizontal clipping/);
 q.actions.cover={rect:[0,100,390,600]};q.action_visibility.cover={clip_rect:[0,100,390,600]};q.actions.card.rect=[10,1000,180,250];assert.throws(()=>scrollGesture(q,'card'),/outside action buttons/);
});
test('short settings panels use the remaining clipped distance instead of oscillating by147px',()=>{
 const q={actions:{faction_morph:{rect:[48,332,367,44]}},action_visibility:{faction_morph:{clip_rect:[48,50,748,245]}}};
 const gesture=scrollGesture(q,'faction_morph'),distance=gesture.from.y-gesture.to.y;
 assert(distance>81&&distance<120,'the actual81px overflow is exposed without a147px overshoot');
 q.actions.faction_morph.rect[1]=40;
 const correction=scrollGesture(q,'faction_morph');assert(correction.to.y-correction.from.y<40,'a small reverse correction cannot overshoot the other edge');
});
test('partly visible library portraits need44px while ordinary actions need their full button',()=>{
 const q={actions:{card_actual:{rect:[8,280,179,250]}},action_visibility:{card_actual:{clip_rect:[8,50,374,245]}}};
 const small=scrollGesture(q,'card_actual');assert(small.from.y-small.to.y<60,'oversized portrait is exposed through a modest real pan');
});
test('scrolling may never silently open a wrong inspector or switch a dialog or page',()=>{
 const before={page:'collection',modal:false,modal_version:0},same={...before};assertPanContext(before,same,'card_actual');
 for(const after of [{...same,modal:true,modal_version:2,inspection:{id:'wrong'}},{...same,page:'settings'},{...same,modal_version:1},{...same,inspection:{id:'wrong'}}])assert.throws(()=>assertPanContext(before,after,'card_actual'),/scrolling/);
 const modal={page:'settings',modal:true,modal_version:3};assertPanContext(modal,{...modal},'difficulty');assert.throws(()=>assertPanContext(modal,{...modal,modal:false},'difficulty'),/scrolling/);
});
function quietFixture(){
 let clock=0;const sandbox={window:{orafoldQA:null},performance:{now:()=>clock}};
 const predicate=vm.runInNewContext('('+heldPanQuiet.toString()+')',sandbox);
 const sample={id:'faction_morph',context:{page:'settings',modal:true,modal_version:3,inspection_id:undefined},previous:null,last:null,count:0,since:0};
 const q=y=>({page:'settings',modal:true,modal_version:3,actions:{faction_morph:{rect:[48,y,367,44]}}});
 return {sample,q,set(value,time){sandbox.window.orafoldQA=value;clock=time;return predicate(sample);}};
}
test('held pan requires four freshly published frames and real quiet time before release',()=>{
 const stale=quietFixture(),same=stale.q(81);assert.equal(stale.set(same,0),false);
 assert.equal(stale.set(same,10000),false,'re-reading one canvas report cannot count as new frames');
 const f=quietFixture();assert.equal(f.set(f.q(81),0),false);
 for(const t of [50,100,150])assert.equal(f.set(f.q(81),t),false,'four rapid fresh reports alone cannot prove250ms quiet');
 const ready=f.set(f.q(81),250);assert.equal(ready.fresh_samples,5);assert.equal(ready.held_quiet_ms,250);
});
test('real CI overshoot positions reset the held-pan quiet window; context and missing targets fail',()=>{
 const f=quietFixture();let t=0;
 for(const y of [351,55,-389,-119,19,351]){assert.equal(f.set(f.q(y),t),false);t+=50;}
 for(const time of [400,500])assert.equal(f.set(f.q(351),time),false);
 assert.equal(f.set(f.q(351),600).fresh_samples,4);
 for(const mutate of [q=>q.page='battle',q=>q.modal=false,q=>q.modal_version=4,q=>q.inspection={id:'wrong'},q=>delete q.actions.faction_morph,q=>q.actions.faction_morph.rect[0]=NaN]){
  const bad=quietFixture(),q=bad.q(81);mutate(q);assert.throws(()=>bad.set(q,0));
 }
});
test('held-pan observer is bounded and disposes its read-only browser handle on failure',async()=>{
 let disposed=false;
 const page={async waitForFunction(fn,sample,options){assert.equal(fn,heldPanQuiet);assert.equal(sample.id,'faction_morph');assert.equal(options.timeout,10000);return {async jsonValue(){throw new Error('readback failed');},async dispose(){disposed=true;}};}};
 await assert.rejects(settleHeldPan(page,'faction_morph',{page:'settings',modal:true,modal_version:3}),/readback failed/);assert(disposed);
});
test('permanent log buttons fail the deliberately compact battle composition',()=>{const q=fixture();q.actions.log={rect:[44,0,70,44]};assert.throws(()=>battleGeometry(q,[0,0,844,390]),/secondary log/);});
test('missing sixth card and clipped primary action fail',()=>{const q=fixture();q.hand.pop();assert.throws(()=>battleGeometry(q,[0,0,844,390],{requireSix:true}),/six cards/);q.actions.end.rect[0]=800;assert.throws(()=>battleGeometry(q,[0,0,844,390]),/inside the usable viewport/);});
test('all visible illustrations must finish with exact delivered geometry',()=>{const q=fixture(),sizes=Object.fromEntries(q.hand.map(c=>[c.id,[512,384]]));assert(artReady(q,sizes));q.battle_art[5].pending=true;assert(!artReady(q,sizes));q.battle_art[5].pending=false;q.battle_art[2].pixels=[128,96];assert(!artReady(q,sizes));});
test('full inspector uses delivery ready and actual full pixels, distinct from final status',()=>{
 const q={inspection:{id:'actual-card',art:{state:'ready',status:'final',profile:'full',visible:true,draw_count:1,card_id:'actual-card',requested_card_id:'actual-card',preview_only:false,pixels:[1448,1086]}}},expected={'actual-card':[1448,1086]};
 assert(fullArtReady(q,expected));
 for(const mutate of [value=>value.inspection.art.state='final',value=>value.inspection.art.preview_only=true,value=>value.inspection.art.pixels=[512,384],value=>value.inspection.id='unknown',value=>value.inspection.art.card_id='previous-card',value=>value.inspection.art.draw_count=0,value=>value.inspection.art.visible=false]){const bad=structuredClone(q);mutate(bad);assert(!fullArtReady(bad,expected));}
});
test('a bound image alone is insufficient if art remains an invisible strip',()=>{const q=fixture();assert.equal(premiumArt(q,[0,0,844,390]).count,6);q.battle_art[0].visible_art_fraction=.12;assert.throws(()=>premiumArt(q,[0,0,844,390]),/at least one quarter/);});
test('unknown frames, escaped illustrations, clipped titles and missing roles fail',()=>{for(const mutate of [q=>q.battle_art[0].frame_concept='fake',q=>q.battle_art[0].illustration_rect[0]=-20,q=>q.battle_art[0].title_fits=false,q=>delete q.battle_art[0].display_role]){const q=fixture();mutate(q);assert.throws(()=>premiumArt(q,[0,0,844,390]));}});
test('availability cues must match actual legal-play probes and explain unavailable cards',()=>{
 const q=fixture();q.battle.stage='battle';q.battle.active='hero';q.battle.hero.phase='main';q.legal_plays=q.hand.map((_,index)=>({index,lanes:index%2?[0,2]:[]}));
 q.hand.forEach((card,index)=>Object.assign(card,{availability_shown:true,playable:index%2===1,unavailable_reason:index%2?'':'Energie fehlt'}));
 assert.deepEqual(playability(q),{available:3,unavailable:3});
 for(const mutate of [value=>value.hand[0].playable=true,value=>value.hand[0].unavailable_reason='',value=>value.hand[0].availability_shown=false]){const bad=structuredClone(q);mutate(bad);assert.throws(()=>playability(bad));}
});

test('Master550 CI difficulty below the real settings clip requires a pan before any tap',()=>{
 const state={actions:{difficulty:{rect:[48,399,367,44],disabled:false}},action_visibility:{difficulty:{clip_rect:[48,50,748,315],visible_rect:[0,0,0,0]}}};
 const unchanged=structuredClone(state);assert.equal(masterActionGeometry(state,'difficulty',[0,0,844,390]).reachable,false);
 const gesture=scrollGesture(state,'difficulty');assert(gesture.to.y<gesture.from.y,'the actual visible scroll surface moves toward the real target');
 const dy=gesture.to.y-gesture.from.y,r=state.actions.difficulty.rect;r[1]+=dy;state.action_visibility.difficulty.visible_rect=[...r];
 assert(masterActionGeometry(state,'difficulty',[0,0,844,390]).reachable,'a deliberate controlled pan can expose the complete44px button');assert.equal(unchanged.actions.difficulty.rect[1],399);
});
test('Master550 requires ancestor visibility even when a button AABB fits inside the screen',()=>{
 const state={actions:{difficulty:{rect:[48,340,367,44],disabled:false}},action_visibility:{difficulty:{clip_rect:[48,50,748,315],visible_rect:[48,340,367,25]}}};
 assert.equal(masterActionGeometry(state,'difficulty',[0,0,844,390]).reachable,false);
});
test('Master550 geometry preserves full-card and44CSS assertions and never mutates observations',()=>{
 const state={actions:{card_real:{rect:[8,104,179,250],disabled:false}},action_visibility:{card_real:{clip_rect:[8,104,374,684],visible_rect:[8,104,179,250]}}},before=structuredClone(state);
 assert(masterActionGeometry(state,'card_real',[0,0,390,844]).reachable);assert.deepEqual(state,before);
 for(const change of [s=>s.actions.card_real.disabled=true,s=>s.actions.card_real.rect[2]=43,s=>s.action_visibility.card_real.visible_rect[3]=44]){const bad=structuredClone(state);change(bad);assert.equal(masterActionGeometry(bad,'card_real',[0,0,390,844]).reachable,false);}
});
test('Master550 refuses missing real clip diagnostics instead of trusting a stale viewport fallback',()=>{
 assert.throws(()=>masterActionGeometry({actions:{difficulty:{rect:[48,60,367,44],disabled:false}}},'difficulty',[0,0,844,390]),/ancestor clipping/);
});
function captureFixture(factor=2){
 const viewport={width:844,height:390},metrics={dpr:factor,inner:[844,390],body_width:844,canvas:{css:[0,0,844,390],backing:[844*factor,390*factor]}};
 const png=Buffer.alloc(24);Buffer.from([137,80,78,71,13,10,26,10]).copy(png);png.writeUInt32BE(844*factor,16);png.writeUInt32BE(390*factor,20);
 return {viewport,metrics,png};
}
test('native capture accepts actual DPR1/2/3 backing and matching PNG without changing observations',()=>{
 for(const factor of [1,2,3]){const {viewport,metrics,png}=captureFixture(factor),original=structuredClone(metrics);assert(assertNativeCapture(metrics,structuredClone(metrics),png,viewport,factor));assert.deepEqual(metrics,original);}
});
test('an upscaled DPR2-sized PNG never masks actual DPR1 or low-resolution canvas rendering',()=>{
 const {viewport,metrics,png}=captureFixture();
 const lowDpr=structuredClone(metrics);lowDpr.dpr=1;lowDpr.canvas.backing=[844,390];assert.throws(()=>assertNativeCapture(lowDpr,lowDpr,png,viewport,2),/browser DPR/);
 for(const axis of [0,1]){const low=structuredClone(metrics);low.canvas.backing[axis]/=2;assert.throws(()=>nativeGeometry(low,viewport,2),/backing renders both axes/);}
});
test('screenshot cannot alter DPR, canvas CSS/backing, window or body geometry or fake native dimensions',()=>{
 const {viewport,metrics,png}=captureFixture();
 for(const mutate of [m=>m.dpr=1,m=>m.canvas.css[2]=800,m=>m.canvas.backing[1]=390,m=>m.body_width=900,m=>m.inner[0]=900,m=>m.canvas=null]){const bad=structuredClone(metrics);mutate(bad);assert.throws(()=>assertNativeCapture(metrics,bad,png,viewport,2));}
 const small=Buffer.from(png);small.writeUInt32BE(844,16);assert.throws(()=>assertNativeCapture(metrics,metrics,small,viewport,2),/native context pixel width/);assert.throws(()=>assertNativeCapture(metrics,metrics,Buffer.alloc(24),viewport,2),/actual PNG/);
});
test('native capture uses device-scale Playwright with the exact existing deadline and preserves before/after receipts',async()=>{
 const {viewport,metrics,png}=captureFixture(),calls=[],receipts=[];
 const page={viewportSize:()=>viewport,evaluate:async fn=>{assert.equal(typeof fn,'function');calls.push('read');return structuredClone(metrics);},screenshot:async options=>{calls.push(options);return png;}};
 assert.equal(await nativeCapture(page,{factor:2,timeout:45000,receipts,tag:'actual'}),png);assert.deepEqual(calls,['read',{scale:'device',timeout:45000},'read']);assert.equal(receipts[0].validated,true);assert.deepEqual(receipts[0].before,receipts[0].after);
});
test('native capture rejects pre-existing low DPR before capture and retains failed post-capture geometry',async()=>{
 const {viewport,metrics,png}=captureFixture(),receipts=[];let reads=0,shots=0;
 const page={viewportSize:()=>viewport,evaluate:async()=>{const m=structuredClone(metrics);if(++reads===2)m.dpr=1;return m;},screenshot:async()=>{shots++;return png;}};
 await assert.rejects(nativeCapture(page,{factor:2,timeout:30000,receipts,tag:'regression'}),/browser DPR/);assert.equal(shots,1);assert.equal(receipts[0].after.dpr,1);assert(!receipts[0].validated);
 reads=1;await assert.rejects(nativeCapture(page,{factor:2,timeout:30000,receipts,tag:'preexisting'}),/browser DPR/);assert.equal(shots,1);
});
