'use strict';
// Geometry and presentation contracts used by the real browser runner. They
// accept only read-only observations from the actual canvas, never a model API.
const assert=require('node:assert/strict');
const EPS=1.1;
function rect(value,label='rectangle'){
 assert(Array.isArray(value)&&value.length===4&&value.every(Number.isFinite),label+' is four finite CSS coordinates');
 assert(value[2]>0&&value[3]>0,label+' has positive area');return value;
}
function encloses(outer,inner,tolerance=EPS){
 return inner[0]>=outer[0]-tolerance&&inner[1]>=outer[1]-tolerance&&inner[0]+inner[2]<=outer[0]+outer[2]+tolerance&&inner[1]+inner[3]<=outer[1]+outer[3]+tolerance;
}
function overlap(a,b){return Math.max(0,Math.min(a[0]+a[2],b[0]+b[2])-Math.max(a[0],b[0]))*Math.max(0,Math.min(a[1]+a[3],b[1]+b[3])-Math.max(a[1],b[1]));}
function touchRect(value,viewport,label){
 rect(value,label);assert(value[2]>=43.9&&value[3]>=43.9,label+' has at least44 CSS pixels per axis');
 assert(encloses(viewport,value),label+' is inside the usable viewport');return value;
}
function clearTouchPoint(target,occluders=[],minimum=44){
 rect(target);const half=minimum/2;
 if(target[2]<minimum-.1||target[3]<minimum-.1)return null;
 const xs=[target[0]+half,target[0]+target[2]/2,target[0]+target[2]-half,...occluders.flatMap(r=>[r[0]-half,r[0]+r[2]+half])];
 const ys=[target[1]+half,target[1]+target[3]/2,target[1]+target[3]-half,...occluders.flatMap(r=>[r[1]-half,r[1]+r[3]+half])];
 for(const y of ys)for(const x of xs){const candidate=[x-half,y-half,minimum,minimum];if(encloses(target,candidate,.1)&&occluders.every(other=>overlap(candidate,other)<.1))return [x,y];}
 return null;
}
function battleGeometry(q,viewport,{minimumHandAspect=.57,maximumHandAspect=.90,requireSix=false}={}){
 assert(q?.page==='battle'&&q.battle,'a real battle is displayed');
 assert(!q.portrait&&!q.actions.rotate_menu,'no blocking portrait guide in landscape');
 const board=Object.entries(q.board||{});assert.equal(board.length,10,'five actual paired lanes');
 for(const [id,value]of board)touchRect(value,viewport,id);
 for(const side of ['hero','enemy']){
  const laneRects=Array.from({length:5},(_,i)=>{assert(q.board[side+i],side+' lane '+i+' exists');return q.board[side+i];});
  for(let i=1;i<5;i++)assert(laneRects[i][0]>laneRects[i-1][0],side+' lanes preserve left-to-right logical order');
  for(let i=0;i<5;i++)for(let j=i+1;j<5;j++)assert(overlap(laneRects[i],laneRects[j])<1,side+' lane hit regions do not overlap');
 }
 for(let i=0;i<5;i++)assert(overlap(q.board['hero'+i],q.board['enemy'+i])<1,'opposing lane hit regions do not overlap '+i);
 for(const id of ['menu','actions','end','inspect']){
  assert(q.actions[id],id+' primary UI exists');touchRect(q.actions[id].rect,viewport,id);
 }
 for(const id of ['log','restart'])assert(!q.actions[id],'secondary '+id+' does not permanently occupy the arena');
 if(requireSix)assert.equal(q.hand.length,6,'six cards reached through real draw commands');
 const hand=q.hand||[];assert(hand.length>0,'actual hand is visible');
 for(let i=0;i<hand.length;i++){
  const r=touchRect(hand[i].rect,viewport,'hand '+i),ratio=r[2]/r[3];
  assert(ratio>=minimumHandAspect&&ratio<=maximumHandAspect,'hand '+i+' is a portrait collectible card rather than a text strip');
  const higher=hand.filter((_,j)=>j!==i&&(j>i&&q.selected!==i||j===q.selected)).map(c=>c.rect);
  assert(clearTouchPoint(r,higher),'hand '+i+' exposes a reliable44CSS touch area');
 }
 return {board_slots:board.length,hand_cards:hand.length,minimum_hand_height:Math.min(...hand.map(c=>c.rect[3])),maximum_hand_aspect:Math.max(...hand.map(c=>c.rect[2]/c.rect[3]))};
}
function artReady(q,expected,requiredZones=['hand','board']){
 const cards=(q.battle_art||[]).filter(row=>row.card_id&&row.visible&&requiredZones.includes(row.zone));
 return cards.length>0&&cards.every(row=>{
  const size=expected[row.card_id];return size&&row.profile==='compact'&&row.status==='final'&&!row.pending&&row.pixels?.[0]===size[0]&&row.pixels?.[1]===size[1];
 });
}
function premiumArt(q,viewport){
 const cards=(q.battle_art||[]).filter(row=>row.card_id&&row.visible&&['hand','board'].includes(row.zone));
 assert(cards.length,'actual visible renderer reports exist');
 for(const row of cards){
  assert(['hand','board'].includes(row.display_role),'actual role is explicit for '+row.card_id);
  assert(['reliquary','prismatic','folded'].includes(row.frame_concept),'actual selected frame concept is reported');
  assert(['common','rare','epic','legendary'].includes(row.rarity),'actual rarity is reported');
  if(row.display_role==='hand')assert(row.title_fits===true,'the actual full hand-card title fits its renderer '+row.card_id);
  rect(row.illustration_rect,'illustration '+row.card_id);rect(row.frame_rect,'frame '+row.card_id);
  assert(encloses(row.frame_rect,row.illustration_rect),'illustration stays inside card contour');
  assert(encloses(viewport,row.frame_rect),'card contour remains inside viewport');
  assert(Number.isFinite(row.visible_art_fraction)&&row.visible_art_fraction>=.25,'illustration occupies at least one quarter of compact card '+row.card_id);
 }
 return {count:cards.length,minimum_visible_art_fraction:Math.min(...cards.map(row=>row.visible_art_fraction)),roles:[...new Set(cards.map(row=>row.display_role))],concepts:[...new Set(cards.map(row=>row.frame_concept))]};
}
function playability(q){
 assert(q.battle.stage==='battle'&&q.battle.active==='hero'&&q.battle.hero.phase==='main','playability is checked in a real player action phase');
 const legal=Object.fromEntries(q.legal_plays.map(row=>[row.index,row.lanes.length>0]));
 for(let index=0;index<q.hand.length;index++){
  const card=q.hand[index];assert(card.availability_shown===true,'hand '+index+' displays an explicit availability cue');
  assert.equal(card.playable,legal[index],'hand '+index+' cue matches the actual model legal-play probe');
  if(!card.playable)assert(typeof card.unavailable_reason==='string'&&card.unavailable_reason.length>0,'unavailable hand card has an actual explanatory reason');
 }
 return {available:q.hand.filter(card=>card.playable).length,unavailable:q.hand.filter(card=>!card.playable).length};
}
module.exports={rect,encloses,overlap,touchRect,clearTouchPoint,battleGeometry,artReady,premiumArt,playability};
