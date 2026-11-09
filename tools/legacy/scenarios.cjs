'use strict';
// Authored controlled states, executed by the pinned engine. Not natural draws,
// and not full-match replay exports. No rules are reimplemented here.
function scenarios(E){
  const cases=[];
  const unit=(id,extra={})=>({id,hp:E.BYID[id].hp,atk:E.BYID[id].atk,summoned:false,stun:0,...extra});
  const withEffect=effect=>E.CARDS.find(c=>c.effect===effect).id;
  function make(){
    const b=E.createBattle(E.START,1,2);
    for(const side of ['hero','enemy'])Object.assign(b[side],{phase:'main',pendingDraw:0,drawDone:true,hp:35,maxHp:35,ward:0,block:0,resonance:0,energy:10,deck:[...E.START],hand:[],discard:[],lanes:Array(5).fill(null),turns:1,attune:null,pendingShift:null,pendingTarget:null,weak:0,fatigue:0,burstUsed:false,cycled:false,summons:0,seals:0,cycles:0,tacticUsed:false,fortifyUsed:false});
    Object.assign(b,{active:'hero',winner:null,round:1,events:[],log:[],actions:[],queue:[]});
    b.initialState=E.snapshot(b);return b;
  }
  function add(id,setup,steps){
    const b=make();setup(b);const frames=[];
    for(const [command,...args] of steps){
      const before=E.snapshot(b),first=b.events.length;
      const result=E[command](b,...args);
      frames.push({command,args,result:result===undefined?{type:'undefined'}:{type:typeof result,value:result},accepted:result!==false,before,after:E.snapshot(b),events:b.events.slice(first)});
    }
    cases.push({id,setup_kind:'synthetic_controlled_state',steps:frames});
  }
  add('play.valid.cost_and_hand',b=>{b.hero.hand=['ash-1'];},[['play','hero',0,0]]);
  add('play.reject.energy',b=>{b.hero.hand=['ash-1'];b.hero.energy=0;},[['play','hero',0,0]]);
  add('play.reject.occupied',b=>{b.hero.hand=['ash-1'];b.hero.lanes[0]=unit('ash-1');},[['play','hero',0,0]]);
  add('play.reject.third_summon',b=>{b.hero.hand=['ash-1'];b.hero.summons=2;},[['play','hero',0,0]]);
  add('play.reject.phase',b=>{b.hero.hand=['ash-1'];b.hero.phase='draw';},[['play','hero',0,0]]);
  add('play.reject.side',b=>{b.hero.hand=['ash-1'];b.active='enemy';},[['play','hero',0,0]]);
  add('play.reject.invalid_lane',b=>{b.hero.hand=['ash-1'];},[['play','hero',0,-1],['play','hero',0,5],['play','hero',0,1.5]]);
  add('play.reject.invalid_hand',()=>{},[['play','hero',0,0]]);
  add('play.reject.finished',b=>{b.hero.hand=['ash-1'];b.winner='enemy';},[['play','hero',0,0]]);
  add('play.reject.pending',b=>{b.hero.hand=['ash-1'];b.hero.pendingTarget={power:2,sourceLane:0};},[['play','hero',0,0],['endTurn','hero']]);
  for(const effect of Object.keys(E.KINDS)){
    const id=withEffect(effect);
    const steps=[['play','hero',0,2]];
    if(effect==='strike')steps.push(['chooseStrikeTarget','hero',4],['chooseStrikeTarget','hero',3]);
    if(effect==='shift')steps.push(['moveCreature','hero',1,3]);
    add('effect.summon.'+effect,b=>{b.hero.hand=[id];b.hero.hp=20;b.hero.lanes[1]=unit('ash-1');b.enemy.lanes[2]=unit('ash-1',{hp:20});b.enemy.lanes[3]=unit('ash-1',{hp:2});},steps);
  }
  add('strike.fallback.protected_hero',b=>{b.hero.hand=[withEffect('strike')];b.enemy.block=2;b.enemy.ward=4;},[['play','hero',0,2]]);
  add('shift.skip',b=>{b.hero.pendingShift={origin:2};b.hero.lanes[1]=unit('ash-1');},[['skipShift','hero'],['skipShift','hero']]);
  add('shift.reject.destination',b=>{b.hero.pendingShift={origin:2};b.hero.lanes[1]=unit('ash-1');b.hero.lanes[4]=unit('ash-1');},[['moveCreature','hero',1,4],['moveCreature','hero',2,3]]);
  add('target.reject.no_pending',b=>{b.enemy.lanes[0]=unit('ash-1');},[['chooseStrikeTarget','hero',0]]);
  for(const side of ['hero','enemy'])for(const mode of ['empty','protected','occupied','newly_summoned','stunned','haste']){
    add(`attack.${side}.${mode}`,b=>{
      const op=side==='hero'?'enemy':'hero';b.active=side;
      b[side].lanes[0]=unit(mode==='haste'?withEffect('haste'):'ash-1',{atk:10,summoned:['newly_summoned','haste'].includes(mode),stun:mode==='stunned'?1:0});
      if(mode==='protected'){b[op].block=3;b[op].ward=4;}
      if(mode==='occupied')b[op].lanes[0]=unit('ash-1',{hp:4});
    },[['attackPhase',side]]);
  }
  for(const survive of [true,false])add('retaliate.'+(survive?'survives':'dies'),b=>{b.hero.lanes[0]=unit('ash-1',{atk:2,hp:1});b.enemy.lanes[0]=unit(withEffect('retaliate'),{hp:survive?3:2});},[['attackPhase','hero']]);
  add('harvest.death',b=>{b.enemy.lanes[0]=unit('ash-1',{atk:2});b.hero.lanes[0]=unit(withEffect('harvest'),{hp:1});},[['attackPhase','enemy']]);
  add('pierce.attack.overflow_protected',b=>{b.hero.lanes[0]=unit(withEffect('pierce'),{atk:10});b.enemy.lanes[0]=unit('ash-1',{hp:4});b.enemy.block=2;b.enemy.ward=3;},[['attackPhase','hero']]);
  add('draw.finish.normal',b=>{b.hero.phase='draw';b.hero.pendingDraw=1;},[['finishDraw','hero'],['finishDraw','hero']]);
  add('draw.overflow.burn_then_finish',b=>{b.hero.phase='draw';b.hero.pendingDraw=1;b.hero.hand=E.START.slice(0,6);},[['finishDraw','hero'],['burn','hero',6],['burn','hero',0],['burn','hero',0],['finishDraw','hero']]);
  add('burn.reject.main',b=>{b.hero.hand=['ash-1'];},[['burn','hero',0]]);
  add('burn.reject.not_required',b=>{b.hero.phase='draw';b.hero.pendingDraw=1;b.hero.hand=['ash-1'];},[['burn','hero',0]]);
  add('draw.fatigue.empty',b=>{b.hero.phase='draw';b.hero.pendingDraw=3;b.hero.deck=[];b.hero.ward=5;b.hero.block=5;b.hero.fatigue=2;},[['finishDraw','hero']]);
  add('draw.recycle',b=>{b.hero.phase='draw';b.hero.pendingDraw=1;b.hero.deck=[];b.hero.discard=['ash-1','tide-1','veil-1'];b.hero.ward=5;b.hero.block=5;},[['finishDraw','hero']]);
  add('draw.effect.empty_no_fatigue',b=>{b.hero.deck=[];},[['draw','hero',1]]);
  add('draw.effect.full_hand',b=>{b.hero.hand=E.START.slice(0,6);},[['draw','hero',1]]);
  add('recover.valid_then_reject',b=>{b.hero.resonance=15;b.hero.discard=['ash-1','tide-1','veil-1'];},[['recover','hero'],['recover','hero']]);
  add('recover.reject.resources',b=>{b.hero.resonance=4;b.hero.discard=['ash-1'];},[['recover','hero']]);
  add('recover.reject.full_hand',b=>{b.hero.resonance=15;b.hero.discard=['ash-1'];b.hero.hand=E.START.slice(0,6);},[['recover','hero']]);
  add('tacticalMove.valid_then_reject',b=>{b.hero.resonance=15;b.hero.lanes[0]=unit('ash-1');},[['tacticalMove','hero',0,1],['tacticalMove','hero',1,2]]);
  add('tacticalMove.reject.far',b=>{b.hero.resonance=15;b.hero.lanes[0]=unit('ash-1');},[['tacticalMove','hero',0,4]]);
  add('fortify.valid_then_reject',b=>{b.hero.resonance=15;b.hero.lanes[0]=unit('ash-1',{hp:1});},[['fortify','hero',0],['fortify','hero',0]]);
  add('fortify.reject.resources',b=>{b.hero.resonance=1;b.hero.lanes[0]=unit('ash-1');},[['fortify','hero',0]]);
  for(const order of E.ORDERS.map(o=>o.id))add('burst.'+order,b=>{b.hero.resonance=15;b.hero.hp=20;b.hero.lanes[0]=unit(order+'-1',{hp:1});b.enemy.ward=4;},[['burst','hero',order],['burst','hero',order]]);
  add('burst.reject.threshold',b=>{b.hero.resonance=14;b.hero.lanes[0]=unit('ash-1');},[['burst','hero','ash']]);
  add('burst.reject.no_matching_unit',b=>{b.hero.resonance=15;},[['burst','hero','ash']]);
  add('endTurn.valid.enemy_response',b=>{b.enemy.deck=[];},[['endTurn','hero']]);
  add('endTurn.reject.draw_phase',b=>{b.hero.phase='draw';},[['endTurn','hero']]);
  add('endTurn.reject.hand_overflow',b=>{b.hero.hand=E.START.slice(0,7);},[['endTurn','hero']]);
  add('victory.hero_hp',b=>{b.hero.lanes[0]=unit('ash-1',{atk:40});},[['endTurn','hero'],['play','hero',0,0]]);
  add('victory.enemy_hp',b=>{b.enemy.lanes[0]=unit('ash-1',{atk:40});},[['attackPhase','enemy']]);
  add('victory.path.player',b=>{b.hero.seals=1;for(let i=0;i<3;i++)b.hero.lanes[i]=unit('ash-1');},[['attackPhase','hero']]);
  add('victory.path.enemy',b=>{b.enemy.seals=1;for(let i=0;i<3;i++)b.enemy.lanes[i]=unit('ash-1');},[['attackPhase','enemy']]);
  add('victory.path.interrupted',b=>{b.hero.seals=1;b.hero.lanes[0]=unit('ash-1');},[['attackPhase','hero']]);
  add('begin.block_expiry.resonance',b=>{b.hero.block=8;b.hero.ward=3;b.hero.resonance=15;},[['begin','hero']]);
  for(const from of E.ORDERS.map(o=>o.id))for(const to of E.ORDERS.map(o=>o.id))if(from!==to){
    add('reaction.'+from+'.'+to,b=>{b.hero.attune=from;b.hero.hand=[to+'-1'];b.hero.hp=25;},[['play','hero',0,2]]);
  }
  add('effect.ward.cap',b=>{b.hero.hand=[withEffect('ward')];b.hero.ward=24;},[['play','hero',0,2]]);
  add('effect.weave.cap',b=>{b.hero.hand=[withEffect('weave')];b.hero.resonance=14;},[['play','hero',0,2]]);
  add('effect.mend.cap',b=>{b.hero.hand=[withEffect('mend')];},[['play','hero',0,2]]);
  add('effect.drain.absorbed_no_heal',b=>{b.hero.hand=[withEffect('drain')];b.hero.hp=20;b.enemy.block=20;b.enemy.ward=5;},[['play','hero',0,2]]);
  add('effect.rally.left_priority',b=>{b.hero.hand=[withEffect('rally')];b.hero.lanes[1]=unit('ash-1');b.hero.lanes[3]=unit('ash-1');},[['play','hero',0,2]]);
  add('effect.silence.no_target',b=>{b.hero.hand=[withEffect('silence')];},[['play','hero',0,2]]);
  add('effect.shift.no_neighbour',b=>{b.hero.hand=[withEffect('shift')];},[['play','hero',0,2]]);
  add('effect.pulse.caps_and_neighbours',b=>{b.hero.hand=[withEffect('pulse')];b.hero.resonance=14;b.hero.ward=24;b.hero.lanes[1]=unit('ash-1');b.hero.lanes[3]=unit('ash-1');},[['play','hero',0,2]]);
  add('effect.pierce.arrival_ignores_protection',b=>{b.hero.hand=[withEffect('pierce')];b.enemy.block=10;b.enemy.ward=10;},[['play','hero',0,2]]);
  add('effect.weaken.maximum',b=>{b.hero.hand=[withEffect('weaken')];b.enemy.weak=10;},[['play','hero',0,2]]);
  add('retaliate.zero_attack',b=>{b.hero.lanes[0]=unit('ash-1',{atk:0});b.enemy.lanes[0]=unit(withEffect('retaliate'));},[['attackPhase','hero']]);
  add('stun.before_newly_summoned',b=>{b.hero.lanes[0]=unit('ash-1',{summoned:true,stun:1});},[['attackPhase','hero'],['attackPhase','hero']]);
  add('weak.resets_after_attack',b=>{b.hero.weak=10;b.hero.lanes[0]=unit('ash-1');},[['attackPhase','hero']]);
  add('pierce.attack.exact_kill',b=>{b.hero.lanes[0]=unit(withEffect('pierce'),{atk:4});b.enemy.lanes[0]=unit('ash-1',{hp:4});},[['attackPhase','hero']]);
  add('victory.stops_later_lanes',b=>{b.hero.lanes[0]=unit('ash-1',{atk:40});b.hero.lanes[1]=unit('ash-1',{atk:10});b.enemy.lanes[1]=unit('ash-1',{hp:4});},[['attackPhase','hero']]);
  add('victory.path.new_units_still_count',b=>{b.hero.seals=1;for(let i=0;i<3;i++)b.hero.lanes[i]=unit('ash-1',{summoned:true,stun:1});},[['attackPhase','hero']]);
  add('block.retained_during_other_begin',b=>{b.hero.block=8;b.hero.ward=5;},[['begin','enemy']]);
  for(const resonance of [4,5,9,10,14,15])add('begin.energy.resonance_'+resonance,b=>{b.hero.resonance=resonance;},[['begin','hero']]);
  add('draw.fatigue.escalates',b=>{b.hero.phase='draw';b.hero.pendingDraw=1;b.hero.deck=[];},[['finishDraw','hero'],['begin','hero'],['finishDraw','hero'],['begin','hero'],['finishDraw','hero'],['begin','hero'],['finishDraw','hero']]);
  add('draw.fatigue.reset',b=>{b.hero.phase='draw';b.hero.pendingDraw=1;b.hero.fatigue=3;},[['finishDraw','hero']]);
  for(const cycles of [1,2,3])add('draw.recycle.cycles_'+cycles,b=>{b.hero.phase='draw';b.hero.pendingDraw=1;b.hero.deck=[];b.hero.discard=['ash-1','tide-1'];b.hero.cycles=cycles;},[['finishDraw','hero']]);
  add('recover.reject.empty_discard',b=>{b.hero.resonance=15;},[['recover','hero']]);
  add('recover.reject.phase',b=>{b.hero.resonance=15;b.hero.discard=['ash-1'];b.hero.phase='draw';},[['recover','hero']]);
  add('fortify.full_hp_and_shield_cap',b=>{b.hero.resonance=15;b.hero.ward=24;b.hero.lanes[0]=unit('ash-1');},[['fortify','hero',0]]);
  add('fortify.reject.empty_lane',b=>{b.hero.resonance=15;},[['fortify','hero',0]]);
  add('tacticalMove.reject.occupied',b=>{b.hero.resonance=15;b.hero.lanes[0]=unit('ash-1');b.hero.lanes[1]=unit('ash-1');},[['tacticalMove','hero',0,1]]);
  add('legacy_edge.burn_has_no_winner_guard',b=>{b.hero.phase='draw';b.hero.pendingDraw=1;b.hero.hand=E.START.slice(0,6);b.winner='enemy';},[['burn','hero',0]]);
  add('legacy_edge.skip_has_no_winner_guard',b=>{b.hero.pendingShift={origin:2};b.winner='enemy';},[['skipShift','hero']]);
  add('legacy_edge.recover_while_target_pending',b=>{b.hero.pendingTarget={power:2,sourceLane:0};b.hero.resonance=5;b.hero.discard=['ash-1'];},[['recover','hero']]);
  return cases;
}
module.exports={scenarios};
