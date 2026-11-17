'use strict';
// Serializable, read-only browser predicate. An instantaneous Analyser sample
// can be zero between real mixer blocks on a loaded software renderer. Prove
// readiness from fresh audio-thread PCM instead; never accept cached peaks.
function freshPcmReady(sample){
 const probe=window.__audioQAProbe?.(),audio=window.orafoldQA?.audio;
 if(!probe||!audio)return false;
 if(probe.meterErrors?.length)throw new Error('Independent PCM observer failed: '+probe.meterErrors.join('; '));
 // The actual pool routes only to SFX/UI; music and ambience own separate
 // players. Muted pool flags need not finish playback to become inaudible.
 // Require both the requested zero gains and the actual muted buses, and no
 // ambience, before treating a still-playing pool as isolated from music.
 const inaudiblePool=audio.settings?.sfx===0&&audio.settings?.ui===0&&audio.settings?.ambience===0&&audio.buses?.sfx?.muted===true&&audio.buses?.ui?.muted===true&&audio.buses?.ambience?.muted===true;
 if(!audio.unlocked||audio.suspended||audio.settings?.muted||!(audio.settings?.master>0)||!(audio.settings?.music>0)||audio.music?.suspended||!(audio.music?.playing>0)||(audio.active_voices!==0&&!inaudiblePool)){sample.quiet=[];return false;}
 sample.quiet||=[];
 const observations=[];
 for(let index=0;index<probe.contexts.length;index++){
  const current=probe.contexts[index],cutoff=sample.cutoffs[index];
  if(!cutoff||current.state!=='running'||!(current.destination_sources>0)||!Number.isFinite(current.current_time)||!Number.isFinite(current.epoch)||!Number.isFinite(current.generation)||current.generation<cutoff.generation){sample.quiet[index]=null;continue;}
  const quiet=sample.quiet[index];
  // Establish a new boundary only once transient voices have stopped. Sparse
  // output can stretch a short UI cue over wall time on a starved test host;
  // those old blocks must not become evidence when active_voices reaches zero.
  if(!quiet||quiet.generation!==current.generation||quiet.epoch!==current.epoch){sample.quiet[index]={current_time:current.current_time,generation:current.generation,epoch:current.epoch};continue;}
  const after=Math.max(cutoff.current_time+.1,quiet.current_time+.1,current.epoch+.1);
  const blocks=probe.meterMessages.filter(block=>block.context===index&&block.generation===current.generation&&Number.isFinite(block.at)&&block.at>after&&block.at<=current.current_time&&Number.isFinite(block.maxRms)&&block.maxRms>=0);
  const positive=blocks.filter(block=>block.maxRms>0.000001);
  const span=positive.length?positive.at(-1).at-positive[0].at:0;
  // A 0.45-second UI-confirm cue cannot satisfy one second of positive PCM.
  // The product must also report active music and no transient voices.
  if(positive.length>=6&&span>=1)observations.push({context:index,generation:current.generation,cutoff:after,fresh_blocks:blocks.length,positive_blocks:positive.length,positive_span:span,first_positive:positive[0].at,last_positive:positive.at(-1).at});
 }
 return observations.length?{before_action:sample.before,cutoffs:sample.cutoffs,quiescent_cutoffs:sample.quiet,observations,probe}:false;
}
// The worklet reports after4096 interleaved samples. At96kHz/stereo the
// previous fixed eight-block tail spans only0.149s and can never prove0.2s.
// Observe a bounded consecutive silent suffix instead; thresholds stay intact.
function silencePcmReady(sample){
 const probe=window.__audioQAProbe();
 const observations=probe.contexts.map((current,index)=>{
  if(current.state!=='running'||current.destination_sources===0)return true;
  const after=Math.max(sample.since[index]+.1,current.epoch+.1);
  const fresh=probe.meterMessages.filter(block=>block.context===index&&block.generation===current.generation&&Number.isFinite(block.at)&&block.at>after&&block.at<=current.current_time);
  const silent=[];
  for(let i=fresh.length-1;i>=0;i--){
   if(!Number.isFinite(fresh[i].maxRms)||fresh[i].maxRms<0||fresh[i].maxRms>=1e-7)break;
   silent.unshift(fresh[i]);
  }
  return {context:index,current_time:current.current_time,generation:current.generation,sample_rate:current.sample_rate,blocks:fresh.slice(-16).map(block=>({at:block.at,maxRms:block.maxRms})),silent_blocks:silent.length,silent_span:silent.length?silent.at(-1).at-silent[0].at:0,ready:silent.length>=6&&silent.at(-1).at-silent[0].at>=.2};
 });
 const ready=observations.every(item=>item===true||item.ready),now=performance.now();
 if(!sample.last||now-sample.last>=1000||ready){
  const q=window.orafoldQA;sample.last=now;
  console.debug('ORAFOLD_PCM_BASELINE '+JSON.stringify({since:sample.since,observations,page:q?.page,render_version:q?.render_version,battle:{stage:q?.battle?.stage,active:q?.battle?.active,hero_phase:q?.battle?.hero?.phase},end:q?.actions?.end,audio:q?.audio,ready}));
 }
 return ready;
}
module.exports={freshPcmReady,silencePcmReady};
