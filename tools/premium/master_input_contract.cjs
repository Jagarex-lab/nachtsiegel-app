'use strict';
// Read-only browser geometry. The real Master550 runner supplies every value
// from its current Godot Controls; this module cannot change UI or game state.
const assert=require('node:assert/strict');
const {encloses,rect}=require('./browser_contract.cjs');
function masterActionGeometry(state,id,viewport){
 const action=state?.actions?.[id],visibility=state?.action_visibility?.[id];
 assert(action,id+' has an actual action');
 assert(visibility,id+' has actual ancestor clipping diagnostics');
 const target=rect(action.rect,id),clip=rect(visibility.clip_rect,id+' clip');
 const visible=visibility.visible_rect;
 assert(Array.isArray(visible)&&visible.length===4&&visible.every(Number.isFinite),id+' has actual visible bounds');
 return {rect:target,clip,visible_rect:visible,reachable:!action.disabled&&target[2]>=43.9&&target[3]>=43.9&&encloses(viewport,target,.1)&&encloses(clip,target,.1)&&encloses(visible,target,.1)};
}
module.exports={masterActionGeometry};
