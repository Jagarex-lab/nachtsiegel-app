'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {clearTouchPoint,scrollGesture,battleGeometry,artReady,fullArtReady,premiumArt,playability}=require('../../tools/premium/browser_contract.cjs');
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
