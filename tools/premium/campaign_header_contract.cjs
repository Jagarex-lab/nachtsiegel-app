'use strict';
// Self-contained for Playwright serialization. Observes published UI snapshots;
// only the private poll sample is changed, never product state or storage.
function campaignHeaderReady(sample){
 const q=window.orafoldQA,c=window.orafoldCampaignQA,{size,nav,rows}=sample;
 const dimensions=[size.width,size.height];
 const matches=value=>Array.isArray(value)&&value.length===2&&value.every((v,i)=>Number.isFinite(v)&&Math.abs(v-dimensions[i])<=.1);
 const canvas=document.querySelector('canvas'),r=canvas?.getBoundingClientRect();
 let valid=q?.hosted_page==='campaign'&&c?.screen==='overview'&&matches(q.layout_size)&&matches(c.logical_viewport)&&q.portrait===(size.height>size.width)&&c.compact===(size.width<720)&&r&&Math.abs(r.width-size.width)<=1&&Math.abs(r.height-size.height)<=1&&Math.abs(canvas.width-size.width*2)<=1&&Math.abs(canvas.height-size.height*2)<=1;
 const controls=nav.map(text=>q?.hosted_actions?.find(a=>a.text===text));
 const ys=[];
 if(valid)for(const a of controls){
  const box=a?.rect;
  if(!a||a.disabled||!Array.isArray(box)||box.length!==4||!box.every(Number.isFinite)||box[2]<43.9||box[3]<43.9||box[0]<-.1||box[1]<-.1||box[0]+box[2]>size.width+.1||box[1]+box[3]>size.height+.1){valid=false;break;}
  if(!ys.some(y=>Math.abs(y-box[1])<1))ys.push(box[1]);
 }
 if(!valid||ys.length!==rows){sample.matching_pairs=0;sample.previous_q=null;sample.previous_c=null;return false;}
 // Each channel publishes independently. Re-reading one report, or seeing a
 // fresh report from just one channel, cannot certify two completed layouts.
 if(q===sample.previous_q||c===sample.previous_c)return false;
 sample.previous_q=q;sample.previous_c=c;sample.matching_pairs=(sample.matching_pairs||0)+1;
 if(sample.matching_pairs<2)return false;
 // Return exactly the pair that passed, not a later potentially mixed read.
 return {q,c,campaign_store:localStorage.getItem('orafold.campaign.v2'),economies:Object.fromEntries(Object.keys(localStorage).filter(k=>k.startsWith('orafold.economy.sandbox.')).sort().map(k=>[k,localStorage.getItem(k)])),readiness:{matching_pairs:sample.matching_pairs,shell_layout_size:q.layout_size,campaign_logical_viewport:c.logical_viewport}};
}
module.exports={campaignHeaderReady};
