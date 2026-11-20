'use strict';
// Assertions observe the real Godot inspector. Every action remains real browser
// input supplied by its caller; this helper never invokes a game/model callback.
const assert=require('node:assert/strict');
const contains=(outer,inner)=>Array.isArray(outer)&&Array.isArray(inner)&&inner.every(Number.isFinite)&&inner[2]>0&&inner[3]>0&&inner[0]>=outer[0]-.75&&inner[1]>=outer[1]-.75&&inner[0]+inner[2]<=outer[0]+outer[2]+.75&&inner[1]+inner[3]<=outer[1]+outer[3]+.75;
function assertCardInspection(state,card,viewport){
 const face=state.inspection,bounds=[0,0,viewport.width,viewport.height];
 assert(state.modal&&face,'a real card inspector is visible');
 assert.equal(face.id,card.id,'the enlarged card keeps its original identity');
 assert.equal(face.title,card.name,'the enlarged card prints the complete original name');
 assert.equal(face.rules,String(card.text_de??card.description??''),'all original mechanical rules remain on the card');
 assert(contains(bounds,face.card_rect),'the complete card contour is inside the viewport');
 assert(Math.abs(face.card_rect[2]/face.card_rect[3]-63/88)<.002,'the real card keeps its63:88 aspect ratio');
 assert(Math.abs(face.card_aspect-63/88)<.002,'the actual renderer reports the same63:88 card aspect');
 assert(contains(face.card_rect,face.title_rect),'the actual title control stays inside the card');
 assert(contains(face.card_rect,face.rules_rect),'printed rules scroll only inside the actual card');
 assert(Number.isFinite(face.rules_font_size)&&face.rules_font_size>=13,'printed rules use at least13 CSS pixels');
 assert.equal(face.keyword_definitions_in_card,false,'keyword definitions are separate from the printed card');
 assert(face.rules_scroll&&Number.isFinite(face.rules_scroll.offset),'the actual printed-rules scroll control is reported');
 const close=state.actions.modal_close?.rect;
 assert(contains(bounds,close)&&close[2]>=43.9&&close[3]>=43.9,'the explicit close control is visible and at least44 CSS pixels');
 return face;
}
function assertUnchangedGame(before,after,label='card inspection'){
 assert.deepEqual(after.battle,before.battle,label+': complete model is unchanged');
 assert.equal(after.command_count,before.command_count,label+': no game command was issued');
 assert.deepEqual(after.deck_ids,before.deck_ids,label+': deck data is unchanged');
 assert.deepEqual(after.opening_marks,before.opening_marks,label+': exchange marks are unchanged');
 assert.equal(after.page,before.page,label+': navigation is unchanged');
}
async function waitForCardInspection(page,id,timeout=90000){
 const handle=await page.waitForFunction(sample=>{
  const q=window.orafoldQA,face=q?.inspection;if(!q||q===sample.previous)return false;sample.previous=q;
  if(!q.modal||face?.id!==sample.id||!face.card_rect||!face.rules_rect||!face.title_rect)return false;
  const rect=face.card_rect;if(rect[2]<=0||rect[3]<=0)return false;
  sample.count=sample.last&&rect.every((n,i)=>Math.abs(n-sample.last[i])<.25)?sample.count+1:1;sample.last=[...rect];
  return sample.count>=3;
 },{id,previous:null,last:null,count:0},{timeout});
 await handle.dispose();
}
async function openHandInspection({page,read,tap,index,cards,timeout=90000}){
 const before=await read(),hand=before.hand[index];
 assert(!before.modal,'opening a hand inspector starts without another modal');
 assert(hand&&cards[hand.id],'the tapped hand card has a real catalog definition');
 assert.equal(hand.id,before.battle.hero.hand[index],'the tapped control is the actual hand card');
 await tap(hand.rect,index,hand.id);await waitForCardInspection(page,hand.id,timeout);
 const inspected=await read();assertCardInspection(inspected,cards[hand.id],page.viewportSize());
 assertUnchangedGame(before,inspected,'first hand tap');
 assert.equal(inspected.selected,before.selected,'an inspection tap does not arm or play a card');
 return {before,inspected,card:cards[hand.id],index};
}
async function selectInspectedHand({page,read,action,opened,timeout=90000}){
 assert((await read()).inspection?.id===opened.card.id,'explicit selection belongs to the inspected card');
 await action('inspect_select');
 await page.waitForFunction(index=>{const q=window.orafoldQA;return !q.modal&&q.selected===index;},opened.index,{timeout});
 const selected=await read();assertUnchangedGame(opened.before,selected,'explicit card selection');
 return selected;
}
async function selectHandCard(options){
 const opened=await openHandInspection(options);
 await selectInspectedHand({...options,opened});return opened;
}
module.exports={assertCardInspection,assertUnchangedGame,waitForCardInspection,openHandInspection,selectInspectedHand,selectHandCard};
