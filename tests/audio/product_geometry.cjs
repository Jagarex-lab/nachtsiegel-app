'use strict';
// Read-only canvas observations. Ancestor clipping and the actual viewport
// decide visibility; arbitrary top/bottom gutters are not layout authorities.
function audioTargetVisible(state,key,viewport){
 const r=state.actions?.[key]?.rect,visibility=state.action_visibility?.[key];
 const valid=value=>Array.isArray(value)&&value.length===4&&value.every(Number.isFinite)&&value[2]>0&&value[3]>0;
 if(!valid(r)||r[2]<44||r[3]<44||!valid(visibility?.clip_rect)||!valid(visibility?.visible_rect))return false;
 const encloses=(outer,inner)=>inner[0]>=outer[0]-.1&&inner[1]>=outer[1]-.1&&inner[0]+inner[2]<=outer[0]+outer[2]+.1&&inner[1]+inner[3]<=outer[1]+outer[3]+.1;
 return encloses([0,0,viewport.width,viewport.height],r)&&encloses(visibility.clip_rect,r)&&encloses(visibility.visible_rect,r);
}
module.exports={audioTargetVisible};
