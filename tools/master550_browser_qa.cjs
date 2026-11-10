'use strict';
// Browser input only. orafoldQA is read-only; no model/test-setup mutation.
// WebKit touch uses explicitly synthetic DOM events, not iPhone hardware.
const {chromium, webkit}=require('playwright');
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
const OUTPUT='work/master550/browser';
const TIMEOUT=120000;
const cards=JSON.parse(fs.readFileSync('data/alpha/cards.json','utf8')).cards;
const by=Object.fromEntries(cards.map(card=>[card.id,card]));
const center=rect=>({x:rect[0]+rect[2]/2,y:rect[1]+rect[3]/2});
fs.mkdirSync(OUTPUT,{recursive:true});
fs.rmSync(path.join(OUTPUT,'results.json'),{force:true});

async function runEngine(name){
 for(const suffix of ['results.json','error.json','failure.png','interrupted.json'])fs.rmSync(path.join(OUTPUT,name+'-'+suffix),{force:true});
 const browser=await (name==='webkit'?webkit:chromium).launch({headless:true,...(name==='chromium'?{channel:'chromium',args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']}: {})});
 let page,context,cdp,assertions=0,lastStep='launch';
 const errors=[],checks=[],shots=[],actions=[],seeds=[],touchDriver=name==='chromium'?'CDP browser-protocol touch':'synthetic DOM TouchEvent (untrusted, not device input)';
 const check=(condition,label)=>{assertions++;assert(condition,label);};
 const equal=(actual,expected,label)=>{assertions++;assert.deepEqual(actual,expected,label);};
 const url=new URL(process.env.GAME_URL||'http://127.0.0.1:8788/');url.searchParams.set('qa','1');
 try{
  context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:2,hasTouch:true,isMobile:true,acceptDownloads:true});
  page=await context.newPage();page.setDefaultTimeout(TIMEOUT);
  if(name==='chromium')cdp=await context.newCDPSession(page);
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',message=>{if(message.type()==='error')errors.push(message.text());});
  // Explicitly simulated safe areas. This changes browser geometry, never game state.
  await page.addInitScript(()=>Object.defineProperty(window,'nachtsiegelInsets',{configurable:true,get:()=>()=>innerWidth>innerHeight&&innerWidth>=800?{left:44,right:44,top:0,bottom:21}:{left:0,right:0,top:innerWidth<innerHeight?20:0,bottom:innerWidth<innerHeight?20:0},set:()=>{}}));
  const q=()=>page.evaluate(()=>window.orafoldQA);
  const wait=(predicate,arg)=>page.waitForFunction(predicate,arg,{timeout:TIMEOUT});
  const rectCheck=(rect,label)=>{
   const viewport=page.viewportSize();check(Array.isArray(rect)&&rect[2]>=43.9&&rect[3]>=43.9,label+' >=44 CSS pixels');
   check(rect[0]>=-.1&&rect[1]>=-.1&&rect[0]+rect[2]<=viewport.width+1&&rect[1]+rect[3]<=viewport.height+1,label+' inside viewport');
  };
  async function shot(tag){
   await page.waitForTimeout(180);
   const viewport=page.viewportSize();let buffer;
   if(cdp){
    let timer;const response=await Promise.race([cdp.send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:true,clip:{x:0,y:0,width:viewport.width,height:viewport.height,scale:2}}),new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('Native screenshot timed out after 45s')),45000);})]).finally(()=>clearTimeout(timer));
    buffer=Buffer.from(response.data,'base64');
   }else buffer=await page.screenshot({timeout:45000});
   check(buffer.readUInt32BE(16)===viewport.width*2&&buffer.readUInt32BE(20)===viewport.height*2,'screenshot uses DPR2 native dimensions');
   check(buffer.length>20000,'screenshot contains rendered content');
   const filename=name+'-'+tag+'.png';fs.writeFileSync(path.join(OUTPUT,filename),buffer);shots.push(filename);
  }
  async function action(id,{render=true}={}){
   lastStep='action '+id;fs.writeFileSync(path.join(OUTPUT,name+'-progress.json'),JSON.stringify({step:lastStep,completed_actions:actions.length,assertions},null,2));
   await wait(key=>{const value=window.orafoldQA?.actions?.[key];return value&&!value.disabled;},id);
   const before=await q(),target=before.actions[id];rectCheck(target.rect,id);
   const at=center(target.rect);await page.touchscreen.tap(at.x,at.y);
   if(render)await wait(previous=>{const state=window.orafoldQA;return state.render_version>previous.render_version||state.modal_version!==previous.modal_version;},before);
   actions.push(id);
  }
  async function resize(width,height){
   const previous=await q();await page.setViewportSize({width,height});
   await wait(({previous,width,height})=>{const state=window.orafoldQA;return state&&state.render_version>previous.render_version&&state.portrait===(height>width);},{previous,width,height});
   await page.waitForTimeout(240); // Actual rotation input guard, not rule advancement.
  }
  async function paths(label){
   const state=await q();equal(Object.keys(state.board).sort(),['enemy0','enemy1','enemy2','enemy3','enemy4','hero0','hero1','hero2','hero3','hero4'].sort(),label+': ten actual paired paths');
   for(let lane=0;lane<5;lane++){
    const own=state.board['hero'+lane],enemy=state.board['enemy'+lane];rectCheck(own,label+' own '+lane);rectCheck(enemy,label+' enemy '+lane);
    check(Math.abs(own[0]-enemy[0])<1&&Math.abs(own[2]-enemy[2])<1,label+': paired path alignment');
   }
  }
  async function exactState(before,label){
   await page.waitForTimeout(180);const after=await q();equal(after.battle,before.battle,label+': complete state unchanged');equal(after.command_count,before.command_count,label+': no command');
  }
  async function beginGame(){
   await action('start');await action('choose_houses');await action('deck_play');
   await wait(()=>window.orafoldQA?.battle?.stage==='mulligan'&&window.orafoldQA.actions.mulligan_done);
  }
  async function restartGame(){
   const state=await q();
   if(state.modal)await action('modal_close');
   if((await q()).actions.restart){await action('restart');await action('confirm_restart');}
   else{await action('menu');await action('confirm_menu');await beginGame();}
   await wait(()=>window.orafoldQA?.battle?.stage==='mulligan'&&window.orafoldQA.actions.mulligan_done);
  }
  async function opening({detailed=false}={}){
   await paths('mulligan');let before=await q();equal(before.hand.map(card=>card.id),before.battle.hero.hand,'opening shows actual hand IDs');equal(before.hand.length,5,'five starting cards');
   for(const hand of before.hand)rectCheck(hand.rect,'opening card '+hand.id);
   await action('mulligan_0');await wait(()=>window.orafoldQA.opening_marks?.includes(0));
   await action('mulligan_1');await action('mulligan_1');await wait(()=>JSON.stringify(window.orafoldQA.opening_marks)==='[0]');
   await exactState(before,'marking and unmarking');
   if(detailed){
    await canceledTap((await q()).actions.menu.rect,'canceled menu tap');
    await shot('mulligan-five-paths-marked');await action('inspect');check((await q()).modal,'mulligan inspector is open');await shot('mulligan-inspection-844');await action('modal_close');
    before=await q();await resize(390,844);await wait(()=>window.orafoldQA.actions.rotate_menu);equal(Object.keys((await q()).board).length,0,'portrait never squeezes battlefield');await exactState(before,'mulligan rotation');equal((await q()).opening_marks,[0],'exchange selection retained in portrait');
    await resize(844,390);await wait(()=>window.orafoldQA.actions.mulligan_done);await paths('restored mulligan');equal((await q()).opening_marks,[0],'exchange selection restored');
   }
   before=await q();await action('mulligan_done');await wait(()=>window.orafoldQA.battle.stage==='origins');equal((await q()).command_count,before.command_count+1,'one mulligan confirmation command');await paths('origin selection');
   const origin=await q();for(let lane=0;lane<5;lane++)equal(origin.actions['origin_'+lane].rect,origin.board['hero'+lane],'origin action is actual own path');
   const enemy=center(origin.board.enemy2);await page.touchscreen.tap(enemy.x,enemy.y);await exactState(origin,'enemy path cannot choose origin');
   await canceledTap((await q()).actions.origin_2.rect,'canceled origin tap');
   await canceledTap((await q()).actions.origin_2.rect,'same-turn canceled origin tap',0);
   if(detailed)await shot('origin-on-battlefield');await action('origin_2');await wait(()=>window.orafoldQA.battle.stage!=='origins');
   let state=await q();equal(state.battle.origins.hero,2,'origin chosen on actual path');const coin=state.battle.coin;seeds.push({seed:state.battle.seed,coin});
   if(state.battle.stage==='second'){
    await paths('second possibility');before=await q();await action('second_card_0');equal((await q()).selected,0,'second exchange selects card');await exactState(before,'selecting second exchange needs confirmation');
    await action('inspect');await action('modal_close');await action('second_origin_3');check((await q()).battle.second_path,'second origin applied');
    for(let lane=0;lane<5;lane++)check((await q()).actions['second_origin_'+lane].disabled,'second origin locked after use');
    // Changing origin intentionally clears selection; choose again before confirming exchange.
    await action('second_card_0');before=await q();await action('second_exchange');equal((await q()).command_count,before.command_count+1,'one optional card-exchange command');
    check((await q()).battle.second_card&&(await q()).actions.second_exchange.disabled,'optional exchange limited to once');
    if(detailed)await shot('second-possibility');await action('opening_done');
   }
   await wait(()=>window.orafoldQA.battle.stage==='battle');await paths('actual combat');return coin;
  }
  const pointer={
   async touch(type,at){
    if(cdp){await cdp.send('Input.dispatchTouchEvent',{type,touchPoints:type==='touchEnd'||type==='touchCancel'?[]:[{x:at.x,y:at.y,id:7,radiusX:2,radiusY:2,force:1}]});return;}
    await page.evaluate(({type,at})=>{
     const canvas=document.querySelector('canvas'),kind={touchStart:'touchstart',touchMove:'touchmove',touchEnd:'touchend',touchCancel:'touchcancel'}[type];
     const init={identifier:7,target:canvas,clientX:at.x,clientY:at.y,pageX:at.x+scrollX,pageY:at.y+scrollY,screenX:at.x,screenY:at.y,radiusX:2,radiusY:2,rotationAngle:0,force:1};
     let touch;try{touch=new Touch(init);}catch{touch=init;}
     const active=type==='touchStart'||type==='touchMove'?[touch]:[],data={bubbles:true,cancelable:true,composed:true,touches:active,targetTouches:active,changedTouches:[touch]};
     let event;try{event=new TouchEvent(kind,data);}catch{event=new Event(kind,data);for(const key of ['touches','targetTouches','changedTouches'])Object.defineProperty(event,key,{value:data[key]});}
     canvas.dispatchEvent(event);
    },{type,at});
   },
   async start(method,at){if(method==='mouse'){await page.mouse.move(at.x,at.y);await page.mouse.down();}else await this.touch('touchStart',at);},
   async move(method,at){if(method==='mouse')await page.mouse.move(at.x,at.y,{steps:4});else await this.touch('touchMove',at);},
   async end(method,at,canceled=false){if(method==='mouse'){await page.mouse.move(at.x,at.y);await page.mouse.up();}else await this.touch(canceled?'touchCancel':'touchEnd',at);}
  };
  async function canceledTap(rect,label,holdMs=120){
   const before=await q(),at=center(rect);await pointer.touch('touchStart',at);if(holdMs)await page.waitForTimeout(holdMs);await pointer.touch('touchCancel',at);
   await exactState(before,label);const after=await q();equal(after.selected,before.selected,label+': selection retained');equal(after.page,before.page,label+': page retained');equal(after.modal,before.modal,label+': no modal action');equal(after.opening_marks,before.opening_marks,label+': mulligan marks retained');
  }
  async function lift(index,method){
   const before=await q();equal(before.hand[index].id,before.battle.hero.hand[index],'drag source identity matches actual hand');
   const at=center(before.hand[index].rect);await pointer.start(method,at);const lifted={x:at.x,y:at.y-34};await pointer.move(method,lifted);
   await wait(()=>window.orafoldQA.drag?.active);const state=await q();check(state.drag.active,'actual browser input lifts card');return {before,at:lifted,targets:state.drag.targets};
  }
  async function releaseInvalid(gesture,method,label){
   const state=await q(),invalid=Object.keys(state.board).find(key=>!gesture.targets.includes(key));
   const at=invalid?center(state.board[invalid]):{x:3,y:page.viewportSize().height-3};await pointer.move(method,at);await pointer.end(method,at);await wait(()=>!window.orafoldQA.drag.active);await exactState(gesture.before,label);equal((await q()).selected,gesture.before.selected,'invalid drop restores previous selection');
  }
  async function dragPlay(index,method,{safety=false,capture=true}={}){
   lastStep='drag '+method+' index '+index;
   if((await q()).selected>=0)await action('cancel_selection');
   if(safety){
    let gesture=await lift(index,method);const tapTarget=gesture.targets[0];check(tapTarget,'tap-cancel test has a real legal target');await releaseInvalid(gesture,method,'invalid '+method+' drop');
    if(method==='touch'){
     gesture=await lift(index,method);const current=await q(),key=gesture.targets[0];check(key,'touch-cancel case has a legal target');const at=center(key==='relic_slot'?current.actions.relic_slot.rect:current.board[key]);
     await pointer.move(method,at);await pointer.end(method,at,true);await wait(()=>!window.orafoldQA.drag.active);await exactState(gesture.before,'touchcancel on a legal target');equal((await q()).selected,gesture.before.selected,'touchcancel restores previous selection');
    }
    gesture=await lift(index,method);await resize(390,844);await wait(()=>window.orafoldQA.actions.rotate_menu&&!window.orafoldQA.drag.active);await pointer.end(method,{x:180,y:350});await exactState(gesture.before,'rotation cancels '+method+' drag');equal((await q()).selected,gesture.before.selected,'rotation restores previous selection');await resize(844,390);await wait(()=>window.orafoldQA.actions.end);
    const state=await q(),handPoint=center(state.hand[index].rect);await page.touchscreen.tap(handPoint.x,handPoint.y);await wait(i=>window.orafoldQA.selected===i,index);
    const selected=await q(),targetRect=tapTarget==='relic_slot'?selected.actions.relic_slot.rect:selected.board[tapTarget];
    await canceledTap(targetRect,'canceled selected-card target tap');await canceledTap(targetRect,'same-turn canceled selected-card target tap',0);await action('cancel_selection');
   }
   const gesture=await lift(index,method),state=await q(),card=by[state.hand[index].id];
   check(gesture.targets.length>0,'playable card has a kernel-approved drag target');
   if(card.kind==='relic')equal(gesture.targets,['relic_slot'],'relic targets separate slot only');
   const key=gesture.targets[0],rect=key==='relic_slot'?state.actions.relic_slot.rect:state.board[key];rectCheck(rect,'actual '+card.kind+' drop target');
   const at=center(rect);await pointer.move(method,at);
   // Release before any potentially slow software-renderer screenshot. The
   // game's eight-second idle cancellation must never become a capture race.
   await pointer.end(method,at);await wait(count=>window.orafoldQA.command_count>count,gesture.before.command_count);await page.waitForTimeout(240);
   const after=await q();equal(after.command_count,gesture.before.command_count+1,'valid '+method+' drop issues exactly one command');check(!after.drag.active,'drag presentation is cleared after play');
   check(JSON.stringify(after.battle)!==JSON.stringify(gesture.before.battle),'valid drop changes authoritative state even if an identical copy is drawn');
   if(card.kind==='relic')equal(after.battle.hero.relic.id,card.id,'relic installs outside five paths');
   if(capture)await shot('after-drag-'+method+'-'+card.kind);
   console.log('MASTER550 DRAG',name,method,card.id,'commands',after.command_count);return card;
  }
  function choices(state){
   const b=state.battle,p=b.hero,op=b.enemy,ready=(unit)=>unit&&!unit.stun&&(!unit.summoned||by[unit.id].effect==='haste')&&unit.atk>p.weak;
   if(b.winner||b.active!=='hero'||p.phase!=='main'||p.pendingTarget||p.pendingShift)return [];
   return p.hand.map((id,index)=>({card:by[id],index})).filter(({card})=>{
    if(!card||card.cost>p.energy)return false;
    if(card.kind==='creature')return p.lanes.some(unit=>!unit);
    switch(card.effect){
     case 'stasis':return op.lanes.some(Boolean);
     case 'displace':return op.lanes.some((unit,lane)=>unit&&[lane-1,lane+1].some(to=>to>=0&&to<5&&!op.lanes[to]));
     case 'surge':return p.lanes.some(ready);
     case 'recall':return p.lanes.some(unit=>!unit)&&p.discard.some(id=>by[id]?.kind==='creature');
     case 'redirect':return b.delayed.some(event=>event.side==='hero');
     default:return true;
    }
   });
  }
  async function resolvePending(){
   for(let n=0;n<8;n++){
    const state=await q(),p=state.battle.hero;if(state.battle.winner)return;
    if(p.phase==='draw'){
     if(p.hand.length+Math.min(p.pendingDraw,p.deck.length)>6){
      const index=Math.max(0,p.hand.findIndex(id=>by[id].kind==='creature'));const at=center(state.hand[index].rect);await page.touchscreen.tap(at.x,at.y);await wait(i=>window.orafoldQA.selected===i,index);
     }
     await action('end');continue;
    }
    if(p.pendingTarget){const lane=state.battle.enemy.lanes.findIndex(Boolean);check(lane>=0,'pending strike has an actual target');const before=state.command_count,at=center(state.board['enemy'+lane]);await page.touchscreen.tap(at.x,at.y);await wait(count=>window.orafoldQA.command_count>count,before);continue;}
    if(p.pendingShift){await action('skip');continue;}return;
   }
   throw new Error('pending choices failed to settle');
  }

  const began=Date.now();await page.goto(url.href,{waitUntil:'networkidle'});await wait(()=>window.orafoldQA?.page==='lobby');
  const bootMs=Date.now()-began;check((await q()).drag&&Array.isArray((await q()).opening_marks),'build exposes new read-only UI diagnostics');
  console.log('MASTER550 LOBBY',name,bootMs,'ms');
  let buildInfo=null;const buildResponse=await page.request.get(new URL('build-info.json',url).href);if(buildResponse.ok())buildInfo=await buildResponse.json();
  if(process.env.EXPECTED_COMMIT)equal(buildInfo?.commit,process.env.EXPECTED_COMMIT,'exact tested build commit');
  const metrics=await page.evaluate(()=>({...window.orafoldDisplayMetrics?.(),transform:getComputedStyle(document.querySelector('canvas')).transform}));
  equal(metrics.transform,'none','canvas is never rotated/scaled with CSS transform');check(Math.abs(metrics.pixelsWidth/metrics.cssWidth-2)<.02,'DPR2 render buffer');
  await action('settings');await action('difficulty');await action('option_difficulty_Einfach');await action('settings_back');
  await beginGame();const seen=new Set();
  for(let game=0;game<8;game++){
   const coin=await opening({detailed:game===0});seen.add(coin);console.log('MASTER550 OPENING',name,game,coin);if(seen.size===2)break;await restartGame();
  }
  equal([...seen].sort(),['enemy','hero'],'both real seeded start-player openings tested');checks.push('integrated mulligan and both origin/second flows');
  const beforeBars=await q();await resize(844,320);await paths('browser bars and safe areas');const bars=await q();equal(bars.layout_size,[756,299],'usable landscape area accounts for side and bottom safe areas');for(const hand of bars.hand)rectCheck(hand.rect,'browser-bars hand card');await exactState(beforeBars,'browser-bars resize');await shot('battle-browser-bars-844x320');await resize(844,390);
  const goals={creature:'touch',event:'mouse',relic:'touch'},completed={},safetyDone=new Set();let restarts=0;
  for(let step=0;step<90&&Object.keys(completed).length<3;step++){
   await resolvePending();let state=await q();
   if(state.battle.winner){check(restarts++<3,'drag cases found within four regular games');await action('result_restart');await opening();continue;}
   if(state.selected>=0){await action('cancel_selection');state=await q();}
   const legal=choices(state),wanted=legal.find(choice=>!completed[choice.card.kind]);
   if(wanted){const method=goals[wanted.card.kind];const card=await dragPlay(wanted.index,method,{safety:!safetyDone.has(method)});safetyDone.add(method);completed[card.kind]={id:card.id,method,touchDriver:method==='touch'?touchDriver:undefined};}
   else if(legal.length){await dragPlay(legal[0].index,'mouse',{capture:false});}
   else{await action('end');}
  }
  equal(Object.keys(completed).sort(),['creature','event','relic'],'all three card types played using actual browser drag');checks.push('touch creature/relic and mouse impulse drag; invalid/rotation drops and canceled menu/origin/selected-target taps');
  // A legal third play may win immediately; use the visible result-dialog path.
  await action((await q()).battle.winner?'result_log':'log');await action('verify_replay');await wait(()=>window.orafoldQA.message==='Replay identisch.');checks.push('actual interaction commands replay identically');
  await action('menu');await action('confirm_menu');await resize(390,844);await action('collection');
  const first=Object.keys((await q()).actions).find(id=>id.startsWith('card_'));check(first,'actual collection card available');await action(first);
  for(const [width,height] of [[390,844],[844,390],[756,390],[390,844]]){
   if(page.viewportSize().width!==width||page.viewportSize().height!==height)await resize(width,height);
   check((await q()).modal,'inspector stays open across sizes');rectCheck((await q()).actions.modal_close.rect,'inspector close');await shot('inspector-'+width+'x'+height);
  }
  checks.push('open card inspector at portrait390 and landscape844/756 widths');
  await action('modal_close');equal(errors,[],'no browser/script/WebGL console errors');
  const result={engine:name,browser_version:browser.version(),playwright:require('playwright/package.json').version,url:url.href,build_info:buildInfo,boot_ms:bootMs,assertions,failures:0,simulated:true,real_device:false,touch_driver:touchDriver,metrics,checks,seeds,completed_drag_types:completed,screenshots:shots,actions,errors};
  fs.writeFileSync(path.join(OUTPUT,name+'-results.json'),JSON.stringify(result,null,2));fs.writeFileSync(path.join(OUTPUT,name+'-progress.json'),JSON.stringify({status:'passed',assertions},null,2));console.log('MASTER550 BROWSER PASS',name,assertions,'assertions');return result;
 }catch(error){
  let diagnostic=null;
  if(page){let timer;diagnostic=await Promise.race([page.evaluate(()=>({qa:window.orafoldQA,metrics:window.orafoldDisplayMetrics?.()})).catch(()=>null),new Promise(resolve=>{timer=setTimeout(()=>resolve(null),5000);})]).finally(()=>clearTimeout(timer));await page.screenshot({path:path.join(OUTPUT,name+'-failure.png'),timeout:15000}).catch(()=>{});}
  fs.writeFileSync(path.join(OUTPUT,name+'-error.json'),JSON.stringify({error:String(error),lastStep,assertions,errors,diagnostic},null,2));fs.writeFileSync(path.join(OUTPUT,name+'-progress.json'),JSON.stringify({status:'failed',lastStep,assertions},null,2));throw error;
 }finally{if(context)await context.close();await browser.close();}
}
(async()=>{
 const results=[];
 for(const engine of (process.env.QA_ENGINES||'chromium,webkit').split(',')){checkEngine(engine);results.push(await runEngine(engine));}
 fs.writeFileSync(path.join(OUTPUT,'results.json'),JSON.stringify(results,null,2));console.log('MASTER550 BROWSER:',results.length,'engines,0 failures; simulated browsers, no real devices');
})().catch(error=>{console.error(error);process.exit(1);});
function checkEngine(name){assert(['chromium','webkit'].includes(name),'unsupported browser engine '+name);}
