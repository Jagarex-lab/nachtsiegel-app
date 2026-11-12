'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {audioTargetVisible}=require('./product_geometry.cjs');
const viewport={width:1100,height:800};
function fixture(rect=[832,748,248,44],clip=[8,8,1084,784]){
 return {actions:{end:{rect,disabled:false}},action_visibility:{end:{clip_rect:clip,visible_rect:rect}}};
}
test('the fully visible eight-pixel battle gutter is valid rather than causing twelve useless wheel events',()=>{
 assert(audioTargetVisible(fixture(),'end',viewport));
 assert(audioTargetVisible(fixture([8,8,44,44]),'end',viewport),'top HUD controls need no invented55pixel gap');
});
test('a genuinely ancestor-clipped or viewport-clipped ordinary button must not be partially tapped',()=>{
 assert.equal(audioTargetVisible(fixture([832,749,248,44]),'end',viewport),false,'bottom793 exceeds actual clip792');
 assert.equal(audioTargetVisible(fixture([832,758,248,44],[0,0,1100,900]),'end',viewport),false,'bottom802 exceeds viewport800');
 const value=fixture();value.action_visibility.end.visible_rect=[832,760,248,32];assert.equal(audioTargetVisible(value,'end',viewport),false);
});
test('missing observations, nonfinite geometry and targets smaller than44 pixels fail closed',()=>{
 for(const value of [fixture([832,748,43.99,44]),fixture([832,748,248,43.99]),fixture([NaN,748,248,44]),{actions:{end:{rect:[0,0,44,44]}}}])assert.equal(audioTargetVisible(value,'end',viewport),false);
 assert.equal(audioTargetVisible(fixture(),'missing',viewport),false);
});
