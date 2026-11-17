'use strict';
const {chromium,webkit,devices}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict'),path=require('node:path'),crypto=require('node:crypto');
const {scrollGesture,assertPanContext,settleHeldPan}=require('./premium/browser_contract.cjs');
const {nativeCapture}=require('./premium/native_capture_contract.cjs');
const cards=[...JSON.parse(fs.readFileSync('data/production/cards.json','utf8')).cards,...JSON.parse(fs.readFileSync('data/legacy/cards.json','utf8')).cards],by=Object.fromEntries(cards.map(c=>[c.id,c]));
function allVisibleCompactReady({expected,count}){
 const rows=(window.orafoldQA?.battle_art||[]).filter(row=>row.card_id&&row.visible&&['hand','board'].includes(row.zone));
 return rows.length===count&&count>0&&rows.every(row=>{
  const size=expected[row.card_id];return size&&row.profile==='compact'&&row.status==='final'&&row.pending===false&&row.pixels[0]===size[0]&&row.pixels[1]===size[1];
 });
}
(async()=>{
 const url=new URL(process.env.GAME_URL||'http://127.0.0.1:8788/');url.searchParams.set('qa','1');
 const legacyOnly=process.env.QA_LEGACY_ONLY==='1';
 const compactEntries=legacyOnly?[]:Object.entries(JSON.parse(fs.readFileSync('data/production/art_preview_delivery.json')).entries);
 const compactGeometry=Object.fromEntries(compactEntries.map(([id,entry])=>[id,[entry.width,entry.height]]));
 const fullGeometry=legacyOnly?{}:Object.fromEntries(Object.entries(JSON.parse(fs.readFileSync('data/production/art_delivery.json','utf8')).entries).map(([id,entry])=>[id,[entry.width,entry.height]]));
 const externalCompact=Object.fromEntries(compactEntries.filter(([,entry])=>entry.delivery==='external').map(([id,entry])=>[id,[entry.width,entry.height]]));
 const recordGameplay=process.env.QA_GAMEPLAY_SEQUENCE==='1',sha256=value=>crypto.createHash('sha256').update(value).digest('hex');
 let sequenceArtifact=null;
 if(recordGameplay){
  assert(!legacyOnly,'the gameplay sequence requires the full production catalog');
  assert(/^[0-9a-f]{40}$/.test(process.env.EXPECTED_COMMIT||''),'the gameplay sequence requires an exact source commit');
  assert(process.env.QA_ARTIFACT_MANIFEST,'the gameplay sequence requires QA_ARTIFACT_MANIFEST');
  const manifest=fs.readFileSync(process.env.QA_ARTIFACT_MANIFEST);
  sequenceArtifact={path:path.resolve(process.env.QA_ARTIFACT_MANIFEST),sha256:sha256(manifest),manifest:JSON.parse(manifest)};
  assert.equal(sequenceArtifact.manifest.commit||sequenceArtifact.manifest.source_commit,process.env.EXPECTED_COMMIT,'the artifact manifest must name the same exact source commit');
  const files=sequenceArtifact.manifest.files;
  assert(files&&typeof files==='object'&&files['index.html']&&files['build-info.json'],'the artifact manifest requires actual exported file hashes');
  assert.equal(Object.keys(files).filter(file=>file.endsWith('.pck')).length,1,'the artifact manifest requires one exported PCK');
  assert.equal(Object.keys(files).filter(file=>file.endsWith('.wasm')).length,1,'the artifact manifest requires one exported WASM');
  for(const [file,hash]of Object.entries(files))assert(!file.startsWith('/')&&!file.split('/').includes('..')&&/^[0-9a-f]{64}$/.test(hash),'the artifact manifest requires safe relative paths and SHA256 hashes');
 }
 const results=[],profiles={chromium:[{name:'desktop',viewport:{width:1280,height:720},hasTouch:true},{name:'desktop-wide',viewport:{width:1600,height:900},hasTouch:true},{...devices['Pixel 7'],name:'android',viewport:{width:915,height:412},deviceScaleFactor:1},{...devices['Pixel 7'],name:'android-bars',viewport:{width:844,height:320},deviceScaleFactor:2,insets:{left:44,right:44,top:0,bottom:21}}],webkit:[{...devices['iPhone 13'],name:'iphone',viewport:{width:844,height:390},deviceScaleFactor:3},{...devices['iPhone 13 Pro Max'],name:'iphone-wide',viewport:{width:915,height:412},deviceScaleFactor:1},{...devices['iPhone 13'],name:'iphone-bars',viewport:{width:844,height:320},deviceScaleFactor:1,reducedMotion:'reduce',insets:{left:44,right:44,top:0,bottom:21}}]};
 const selectedEngines=(process.env.QA_ENGINES||'chromium,webkit').split(',');
 for(const engine of selectedEngines)assert(profiles[engine],'unsupported browser engine '+engine);
 if(process.env.QA_PROFILES)for(const requested of process.env.QA_PROFILES.split(','))assert(selectedEngines.some(engine=>profiles[engine].some(profile=>profile.name===requested)),'unsupported profile '+requested);
 if(recordGameplay)assert(selectedEngines.includes('chromium')&&(!process.env.QA_PROFILES||process.env.QA_PROFILES.split(',').includes('desktop')),'the gameplay sequence requires the Chromium desktop profile');
 fs.rmSync('work/alpha/browser-results.json',{force:true});
 for(const engine of selectedEngines){
  for(const profile of profiles[engine].filter(p=>!process.env.QA_PROFILES||process.env.QA_PROFILES.split(',').includes(p.name))){
  const browser=await (engine==='webkit'?webkit:chromium).launch({headless:true,...(process.env.QA_PROXY?{proxy:{server:process.env.QA_PROXY,bypass:"localhost,127.0.0.1"}}:{}),...(engine==='chromium'?{channel:'chromium',args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']}: {})});
  try{
   console.log('BROWSER RUNTIME',engine,browser.version(),require('playwright/package.json').version);
   const {name,insets,...opts}=profile,context=await browser.newContext(opts),page=await context.newPage(),errors=[];
   let inspectedCard=null,profileTemplate=null,testedBuildInfo=null,lastAction='boot',gameplay=null;const relicActivations=[],toolbarTests=[],actionTrace=[],battleArtChecks=[],captureMetrics=[];
   const sequenceEnabled=recordGameplay&&engine==='chromium'&&name==='desktop',sequenceDir=path.resolve(process.env.QA_GAMEPLAY_OUTPUT||'work/alpha/gameplay-sequence');
   page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
   if(insets)await page.addInitScript(v=>Object.defineProperty(window,'nachtsiegelInsets',{configurable:true,get:()=>()=>v,set:()=>{}}),insets);
   const state=()=>page.evaluate(()=>window.orafoldQA);const progress=setInterval(async()=>{try{const q=await state();fs.writeFileSync(`work/alpha/browser-progress-${engine}-${name}.json`,JSON.stringify({engine,name,page:q?.page,modal:q?.modal,message:q?.message,commands:q?.command_count,battle:q?.battle},null,2));}catch{}},5000);progress.unref();
   const wait=fn=>page.waitForFunction(fn,undefined,{timeout:90000});
   const waitViewport=()=>page.waitForFunction(viewport=>{
    const q=window.orafoldQA,m=window.orafoldDisplayMetrics?.();if(!q||!m||!q.density||!q.layout_size)return false;
    const safe=window.nachtsiegelInsets?.()||{},top=window.visualViewport?.offsetTop||0;
    const width=Math.max(320,m.pixelsWidth/q.density-(safe.left||0)-(safe.right||0));
    const height=Math.max(160,Math.min(m.pixelsHeight/q.density-top,m.visibleHeight)-(safe.top||0)-(safe.bottom||0));
    return Math.abs(m.cssWidth-viewport.width)<1&&Math.abs(m.cssHeight-viewport.height)<1&&Math.abs(m.pixelsWidth/m.cssWidth-q.density)<.02&&Math.abs(q.layout_size[0]-width)<1&&Math.abs(q.layout_size[1]-height)<1;
   },page.viewportSize(),{timeout:90000});
   const stableTarget=async (target,expectedContext=null)=>{
    const handle=await page.waitForFunction(sample=>{
     const q=window.orafoldQA;if(!q||q===sample.previous)return false;sample.previous=q;
     if(sample.context&&(q.page!==sample.context.page||Boolean(q.modal)!==Boolean(sample.context.modal)||q.modal_version!==sample.context.modal_version||q.inspection?.id!==sample.context.inspection_id))throw new Error('Scroll/input target context changed before touch');
     const t=sample.target,a=t.action?q.actions[t.action]:null;
     const rect=t.action?(t.action.startsWith('card_')&&q.action_visibility?.[t.action]?q.action_visibility[t.action].visible_rect:a?.rect):t.board?q.board[t.board]:q.hand[t.hand]?.id===t.card_id?q.hand[t.hand].rect:null;
     if(!rect||a?.disabled){sample.count=0;return false;}
     sample.count=sample.last&&rect.every((n,i)=>Math.abs(n-sample.last[i])<=1)?sample.count+1:1;sample.last=[...rect];
     return sample.count>=3?{rect,action_rect:a?.rect,visibility:t.action?q.action_visibility?.[t.action]:null,samples:sample.count}:false;
    },{target,context:expectedContext?{page:expectedContext.page,modal:expectedContext.modal,modal_version:expectedContext.modal_version,inspection_id:expectedContext.inspection?.id}:null,previous:null,last:null,count:0},{timeout:90000});
    try{return await handle.jsonValue();}finally{await handle.dispose();}
   };
   const tap=async (r,target=null,expectedContext=null)=>{
    if(!target){const q=await state(),same=value=>value&&value.every((n,i)=>Math.abs(n-r[i])<.1),id=Object.keys(q.actions).find(id=>same(touchRect(q,id))||same(q.actions[id].rect)),board=Object.keys(q.board).find(id=>same(q.board[id])),hand=q.hand.findIndex(card=>same(card.rect));target=id?{action:id}:board?{board}:hand>=0?{hand,card_id:q.hand[hand].id}:null;assert(target,'touch has an actual tracked UI target');}
    const settled=await stableTarget(target,expectedContext);r=settled.rect;const q=await state();settled.render_version=q.render_version;settled.modal_version=q.modal_version;
    if(target.action)assert(fullVisible(q,target.action),target.action+' stays fully touch-visible after kinetic scrolling settles');
    if(gameplay?.recording)gameplay.inputs.push({kind:'touch',point:[r[0]+r[2]/2,r[1]+r[3]/2],rect:r,target,seed:q.battle?.seed,command_count:q.command_count,selected:q.selected,phase:q.battle?.hero.phase,action:lastAction});
    actionTrace.push({kind:'stable_touch',target,rect:r,fresh_qa_samples:settled.samples});await page.touchscreen.tap(r[0]+r[2]/2,r[1]+r[3]/2);await page.waitForTimeout(90);return settled;
   };
   const encloses=(outer,inner)=>outer&&inner&&inner[0]>=outer[0]-.1&&inner[1]>=outer[1]-.1&&inner[0]+inner[2]<=outer[0]+outer[2]+.1&&inner[1]+inner[3]<=outer[1]+outer[3]+.1;
   const viewportRect=()=>[0,0,page.viewportSize().width,page.viewportSize().height];
   const touchRect=(current,id)=>id.startsWith('card_')&&current.action_visibility?.[id]?current.action_visibility[id].visible_rect:current.actions[id].rect;
   const fullVisible=(current,id)=>{
    const a=current.actions[id],visibility=current.action_visibility?.[id];
    if(!visibility){assert(legacyOnly,'production clip diagnostics unsupported for '+id);return encloses(viewportRect(),a.rect);}
    // A library CardView can exceed the scroll viewport. Its visible body must
    // still supply a real44x44 touch region; ordinary buttons stay fully visible.
    if(id.startsWith('card_'))return encloses(viewportRect(),visibility.visible_rect)&&encloses(a.rect,visibility.visible_rect)&&encloses(visibility.clip_rect,visibility.visible_rect)&&visibility.visible_rect[2]>=43.9&&visibility.visible_rect[3]>=43.9;
    return encloses(viewportRect(),a.rect)&&encloses(visibility.clip_rect,a.rect)&&encloses(visibility.visible_rect,a.rect)&&visibility.visible_rect[2]>=43.9&&visibility.visible_rect[3]>=43.9;
   };
   async function panTowards(current,id){
    const gesture=scrollGesture(current,id),clip=gesture.clip,point=gesture.from,end=gesture.to;
    let quiet;
    if(capture){
     await capture.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...point,id:0,radiusX:2,radiusY:2,force:1}]});
     try{
     for(let step=1;step<=6;step++){await capture.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:point.x,y:point.y+(end.y-point.y)*step/6,id:0,radiusX:2,radiusY:2,force:1}]});await page.waitForTimeout(35);}
     quiet=await settleHeldPan(page,id,current);
     }finally{await capture.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});}
    }else{
     // WebKit's public protocol provides tap only. Trusted browser mouse pan
     // reaches Godot's configured touch emulation; no DOM event/model hook.
     await page.mouse.move(point.x,point.y);await page.mouse.down();
     try{
     for(let step=1;step<=6;step++){await page.mouse.move(point.x,point.y+(end.y-point.y)*step/6);await page.waitForTimeout(35);}
     quiet=await settleHeldPan(page,id,current);
     }finally{await page.mouse.up();}
    }
    await page.waitForTimeout(180);
    const after=await state(),context=s=>({page:s.page,modal:s.modal,modal_version:s.modal_version,render_version:s.render_version,inspection_id:s.inspection?.id});
    actionTrace.push({id,kind:'pan',driver:capture?'CDP primary touch':'browser mouse with Godot touch emulation',clip_rect:clip,from:point,to:end,quiet_before_release:quiet,before:context(current),after:context(after),target_before:current.actions[id]?.rect,target_after:after.actions[id]?.rect});
    assertPanContext(current,after,id);
   }
   const action=async (id,{render=true}={})=>{
    lastAction=id;
    // Secondary actions live in the actual More sheet in the premium arena.
    // Open that visible sheet rather than requiring permanent debug buttons or
    // invoking any model/UI callback from JavaScript.
    if(['convergence','log','restart'].includes(id)&&!(await state()).actions[id])await action('actions');
    await page.waitForFunction(id=>{const a=window.orafoldQA?.actions?.[id];return a&&!a.disabled&&a.rect[2]>=43.9&&a.rect[3]>=43.9;},id,{timeout:90000});
    let previous=await state();const actionContext=previous;lastAction=id;
    if(legacyOnly&&!previous.action_visibility){
     for(let tries=0;tries<8&&!fullVisible(previous,id);tries++){
      const r=previous.actions[id].rect,v=page.viewportSize();await page.mouse.move(Math.max(1,Math.min(v.width-1,r[0]+r[2]/2)),v.height*.6);await page.mouse.wheel(0,r[1]<0?-v.height*.55:v.height*.55);await page.waitForTimeout(140);previous=await state();
     }
    }else for(let tries=0;tries<24&&!fullVisible(previous,id);tries++){await panTowards(previous,id);await stableTarget({action:id},actionContext);previous=await state();}
    assertPanContext(actionContext,previous,id);
    assert(fullVisible(previous,id),id+' requires a visible44CSS card region or a fully visible button');
    const hit=touchRect(previous,id);assert(hit[2]>=43.9&&hit[3]>=43.9,id+' actual touch region remains44CSS');
    const destination={builder:'builder',collection:'collection',settings:'settings',start:legacyOnly?'battle':'decks',deck_play:'battle',builder_back:'lobby',settings_back:'lobby',decks_back:'lobby',confirm_menu:'lobby',result_menu:'lobby'}[id];
    const settled=await tap(hit,{action:id},actionContext);actionTrace.push({id,kind:'tap',rect:settled.action_rect,hit_rect:settled.rect,visibility:settled.visibility});if(render)await page.waitForFunction(({previous,destination})=>{const q=window.orafoldQA;return(q.render_version>previous.render_version||q.modal_version!==previous.modal_version)&&(!destination||q.page===destination);},{previous:settled,destination},{timeout:90000});
   };
   const capture=engine==='chromium'?await context.newCDPSession(page):null;
   const deadline=async (promise,message,ms)=>{let timer;return Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error(message)),ms);})]).finally(()=>clearTimeout(timer));};
   const shot=async tag=>{
    // QA render_version is updated while rebuilding Controls, before the
    // browser compositor necessarily has that canvas frame. Match the other
    // native-viewport harnesses and wait for paint before requesting readback.
    await deadline(page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))),'Screenshot paint timed out after15s',15000);
    await page.waitForTimeout(180);
    const buffer=await nativeCapture(page,{factor:opts.deviceScaleFactor||1,timeout:30000,receipts:captureMetrics,tag});
    assert.equal(buffer.readUInt32BE(16),page.viewportSize().width*(opts.deviceScaleFactor||1),'native screenshot width');
    assert.equal(buffer.readUInt32BE(20),page.viewportSize().height*(opts.deviceScaleFactor||1),'native screenshot height');
    assert(buffer.length>20000,'nonempty rendered screenshot');
    fs.writeFileSync(`work/alpha/${engine}-${name}-${tag}.png`,buffer);
    return buffer;
   };
   const saveSequence=()=>{if(gameplay)fs.writeFileSync(path.join(sequenceDir,'sequence.json'),JSON.stringify(gameplay,null,2));};
   async function sequenceFrame(stage,evidence={}){
    assert(gameplay?.recording,'a sequence frame must belong to the recorded real duel');
    await wait(()=>{const b=window.orafoldQA?.battle;return b&&(b.stage!=='battle'||b.active==='hero'||b.winner);});
    const before=await state(),tag=`gameplay-${String(gameplay.frames.length+1).padStart(2,'0')}-${stage}`,buffer=await shot(tag),after=await state();
    assert.equal(after.command_count,before.command_count,'screenshot does not cross a gameplay command');
    assert.deepEqual(after.battle,before.battle,'screenshot captures a stable actual battle state');
    const file=path.join(sequenceDir,tag+'.png');fs.writeFileSync(file,buffer);
    gameplay.frames.push({stage,file:path.basename(file),sha256:sha256(buffer),bytes:buffer.length,seed:after.battle.seed,command_count:after.command_count,round:after.battle.round,winner:after.battle.winner,page:after.page,modal:after.modal,message:after.message,render_version:after.render_version,input_count:gameplay.inputs.length,evidence,live_session_battle:after.battle});saveSequence();
   }
   async function checkBattleArt(stage,requiredIds=null,zone=null){
    const before=await state();assert(Array.isArray(before.battle_art),'production bound hand/board art diagnostics are required');
    assert(before.battle.hero.hand.some(id=>externalCompact[id])||before.battle_art.some(row=>row.zone==='board'&&externalCompact[row.card_id]),'actual opening includes at least one nonpacked illustration');
    const expected=requiredIds?Object.fromEntries(Object.entries(externalCompact).filter(([id])=>requiredIds.includes(id))):externalCompact;
    await page.waitForFunction(({expected,zone})=>window.orafoldQA.battle_art?.some(row=>row.visible&&['hand','board'].includes(row.zone)&&(!zone||row.zone===zone)&&row.profile==='compact'&&row.status==='final'&&row.pending===false&&expected[row.card_id]&&row.pixels[0]===expected[row.card_id][0]&&row.pixels[1]===expected[row.card_id][1]&&Math.max(...row.pixels)===512),{expected,zone},{timeout:90000});
    const current=await state();assert.equal(current.battle.stage,stage,'waiting for actual image delivery does not advance the opening');assert.equal(current.command_count,before.command_count,'image delivery issues no gameplay command');
    const delivered=current.battle_art.filter(row=>row.visible&&['hand','board'].includes(row.zone)&&(!zone||row.zone===zone)&&row.profile==='compact'&&row.status==='final'&&row.pending===false&&expected[row.card_id]&&row.pixels[0]===expected[row.card_id][0]&&row.pixels[1]===expected[row.card_id][1]);
    assert(delivered.length>0,'a visible nonpacked card owns its actual decoded compact texture');battleArtChecks.push({stage,required_ids:requiredIds,zone,seed:current.battle.seed,command_count:current.command_count,delivered,delivery:current.art_delivery});
   }
   async function checkAllVisibleArt(){
    const before=await state(),rows=before.battle_art.filter(row=>row.card_id&&row.visible&&['hand','board'].includes(row.zone));
    assert(rows.length>0,'actual hand/board cards must be visible before the all-art check');
    await page.waitForFunction(allVisibleCompactReady,{expected:compactGeometry,count:rows.length},{timeout:90000});
    const after=await state();assert.deepEqual(after.battle,before.battle,'waiting for all visible illustrations preserves the complete model');
    assert.equal(after.command_count,before.command_count,'waiting for all visible illustrations issues no command');
    battleArtChecks.push({check:'all-visible-before-after-turn',stage:after.battle.stage,seed:after.battle.seed,command_count:after.command_count,delivered:after.battle_art.filter(row=>row.card_id&&row.visible&&['hand','board'].includes(row.zone)),delivery:after.art_delivery});
   }
   async function opening(customPower=null,expectedCards=null,recordOpening=false){
    await action('start');
    if(!legacyOnly){
     if(customPower)await action('custom_'+customPower);await action('deck_play');
     if(expectedCards){const hero=(await state()).battle.hero;assert.deepEqual([...hero.hand,...hero.deck].sort(),[...expectedCards].sort(),'actual new match contains the exact saved production template');}
     await checkBattleArt('mulligan');
     await checkAllVisibleArt();
     if(recordOpening){gameplay.seed=(await state()).battle.seed;await sequenceFrame('mulligan');}
    }
    if(legacyOnly){await wait(()=>window.orafoldQA.board.hero0);return;}
    await action('mulligan_done');await action('origin_2');await wait(()=>window.orafoldQA?.battle?.stage!=='origins');
    if((await state()).battle.stage==='second')await action('opening_done');await wait(()=>window.orafoldQA?.battle?.stage==='battle'&&window.orafoldQA.board.hero0);
    await checkBattleArt('battle');
    await checkAllVisibleArt();
    if(recordOpening)await sequenceFrame('opening');
   }
   async function toolbarViewportChecks(){
    // Obtain six real cards by drawing, or by holding the first hand for one
    // legal turn. No HP, cards, phase, seed or model state is injected.
    let current=await state();
    if(current.battle.hero.phase==='draw'){await action('end');current=await state();}
    if(current.battle.hero.hand.length<6){
     assert.equal(current.battle.hero.phase,'main','real hold-turn starts in main phase');await action('end');
     await page.waitForFunction(()=>window.orafoldQA.battle.active==='hero'&&window.orafoldQA.battle.hero.phase==='draw');await action('end');current=await state();
    }
    assert.equal(current.battle.hero.hand.length,6,'six-card toolbar case is reached through real draw/turn commands');
    const expected=current.battle,commands=current.command_count,previousViewport=page.viewportSize();
    await page.evaluate(()=>{window.__orafoldToolbarPriorInsets=Object.getOwnPropertyDescriptor(window,'nachtsiegelInsets');Object.defineProperty(window,'nachtsiegelInsets',{configurable:true,value:()=>({left:44,right:44,top:0,bottom:21})});});
    try{
     for(const height of [270,320]){
      const version=(await state()).render_version;await page.setViewportSize({width:844,height});
      await page.waitForFunction(({version,height})=>{const q=window.orafoldQA;return q?.render_version>version&&Math.abs(q.layout_size[0]-756)<1&&Math.abs(q.layout_size[1]-(height-21))<1;},{version,height},{timeout:90000});
      const resized=await state();assert.deepEqual(resized.battle,expected,'toolbar resize preserves full model state');assert.equal(resized.command_count,commands,'toolbar resize issues no command');assert(!resized.actions.rotate_menu,'landscape browser toolbars must not show an orientation guard');assert.equal(Object.keys(resized.board).length,10,'all five paired paths remain available with toolbars');assert.equal(resized.hand.length,6,'all six actual hand cards stay present');
      const safe=r=>r&&r[0]>=43.9&&r[1]>=-.1&&r[0]+r[2]<=800.1&&r[1]+r[3]<=height-21+.1;
      for(const [id,r]of Object.entries(resized.board)){assert(safe(r),id+' remains inside simulated safe area');assert(r[2]>=43.9&&r[3]>=43.9,id+' remains44CSS');}
      for(const c of resized.hand){assert(safe(c.rect),'six-card hand safe area '+c.id);assert(c.rect[2]>=43.9&&c.rect[3]>=43.9,'six-card touch44CSS '+c.id);}
      for(const id of ['menu','end']){const r=resized.actions[id]?.rect;assert(safe(r),id+' toolbar primary action remains visible');assert(r[2]>=43.9&&r[3]>=43.9,id+' remains44CSS with toolbars');}
      await action('menu');assert((await state()).modal,'safe menu really opens through touch at toolbar height');await action('modal_close');assert.deepEqual((await state()).battle,expected,'menu inspection is read-only during toolbar test');
      await checkBattleArt('battle');
      await shot('toolbar-'+height+'-six-cards');toolbarTests.push({viewport:{width:844,height},simulated_safe_insets:{left:44,right:44,top:0,bottom:21},available_height:height-21,hand_size:6,real_device_test:false});
     }
    }finally{
     await page.evaluate(()=>{const descriptor=window.__orafoldToolbarPriorInsets;if(descriptor)Object.defineProperty(window,'nachtsiegelInsets',descriptor);else delete window.nachtsiegelInsets;delete window.__orafoldToolbarPriorInsets;});
     const version=(await state()).render_version;await page.setViewportSize(previousViewport);await page.waitForFunction(v=>window.orafoldQA.render_version>v,version);
     await waitViewport();
    }
    assert.deepEqual((await state()).battle,expected,'restoring browser geometry preserves all gameplay state');
   }
   async function playTurn(){
    for(let n=0;n<22;n++){
     let q=await state(),b=q.battle,p=b.hero;if(b.winner)return;
     if(p.phase==='draw'){
      if(p.hand.length+Math.min(p.pendingDraw,p.deck.length)>6){await page.waitForFunction(()=>window.orafoldQA.hand.length===window.orafoldQA.battle.hero.hand.length);await tap(q.hand[0].rect);}
      const before=q.command_count;await action('end');await page.waitForFunction(n=>window.orafoldQA.command_count>n||window.orafoldQA.battle.winner,before);
      if(!legacyOnly){const drawn=await state();if(!drawn.battle.winner&&drawn.battle.hero.phase==='main'){
       const remaining=[...p.hand],newExternal=drawn.battle.hero.hand.filter(id=>{const index=remaining.indexOf(id);if(index>=0){remaining.splice(index,1);return false;}return !!externalCompact[id];});
       if(newExternal.length)await checkBattleArt('battle',newExternal,'hand');
      }}continue;
     }
     if(p.pendingTarget){const lane=b.enemy.lanes.findIndex(Boolean),before=q.command_count;await tap(q.board['enemy'+lane]);await page.waitForFunction(n=>window.orafoldQA.command_count>n,before);continue;}
     if(p.pendingShift){await action('skip');continue;}
     let choice=null;
     for(const legal of q.legal_plays||[]){
      if(legal.lanes.length){choice={i:legal.index,lane:legal.lanes[0],side:legal.side,relic:legal.relic};break;}
     }
     if(!choice){
      if(q.mode==='alpha'&&p.relic&&!p.relic_used){
       // The actual enabled button is the model's activation contract. Generic
       // relics must not disappear behind an obsolete four-effect lookup table.
       await action('actions');const activation=(await state()).actions.relic;
       assert(activation,'installed relic has an actual activation control');
       if(!activation.disabled){
        const before=await state(),id=before.battle.hero.relic.id;await action('relic');await page.waitForFunction(n=>window.orafoldQA.command_count>n,before.command_count);
        const after=await state();assert.equal(after.command_count,before.command_count+1,'relic activation issues exactly one command');assert(after.battle.hero.relic_used,'actual activation consumes its per-turn use');
        relicActivations.push({id,generic:by[id]?.effect==='v2',remaining_relic:after.battle.hero.relic?.id||null,round:before.battle.round,command:after.command_count});continue;
       }
       await action('modal_close');
      }
      const ready=q.controlled_lanes||[];
      if(q.mode==='alpha'&&b.round>=11&&ready.length>=3){
       await action('convergence');for(const i of ready.slice(0,3)){const previous=await state();await tap(previous.board['hero'+i]);await page.waitForFunction(v=>window.orafoldQA.render_version>v,previous.render_version);}const previous=await state();await action('convergence');await page.waitForFunction(n=>window.orafoldQA.command_count>n,previous.command_count);
      }else{
       const attackers=Object.entries(q.board_details||{}).filter(([id,unit])=>id.startsWith('hero')&&unit.ready&&unit.attack>0);
       const before=q.command_count;await action('end');
       if(gameplay?.recording&&!gameplay.frames.some(frame=>frame.stage==='attack-resolution')&&attackers.length){
        await sequenceFrame('attack-resolution',{actual_command:'endTurn',command_before:before,ready_attackers:attackers});
       }
      }return;
     }
     await page.waitForFunction(()=>window.orafoldQA.hand.map(c=>c.id).join()===window.orafoldQA.battle.hero.hand.join());q=await state();await tap(q.hand[choice.i].rect);
     await page.waitForFunction(i=>window.orafoldQA.selected===i,choice.i);const before=(await state()).command_count;
     await tap(choice.relic?(await state()).actions.relic_slot.rect:(await state()).board[choice.side+choice.lane]);
     await page.waitForFunction(n=>window.orafoldQA.command_count>n||window.orafoldQA.battle.winner,before,{timeout:90000});
     if(!legacyOnly){const played=q.hand[choice.i].id,after=await state();if(!after.battle.winner&&externalCompact[played]&&after.battle[choice.side].lanes[choice.lane]?.id===played)await checkBattleArt('battle',[played],'board');}
     if(gameplay?.recording&&!gameplay.frames.some(frame=>frame.stage==='first-play'))await sequenceFrame('first-play',{card:q.hand[choice.i].id,command_before:before,lane:choice.lane,side:choice.side,relic:choice.relic});
    }
    throw Error('UI action loop made no turn progress');
   }
   try{
    if(process.env.EXPECTED_COMMIT){const r=await page.request.get(new URL('build-info.json',url).href);assert(r.ok());testedBuildInfo=await r.json();assert.equal(testedBuildInfo.commit,process.env.EXPECTED_COMMIT);}
    if(sequenceEnabled){
     sequenceArtifact.served_verified_files=[];
     for(const [file,expected]of Object.entries(sequenceArtifact.manifest.files).filter(([file])=>['index.html','build-info.json'].includes(file)||file.endsWith('.pck')||file.endsWith('.wasm'))){
      const response=await page.request.get(new URL(file,url).href,{timeout:90000});assert(response.ok(),'actual served artifact '+file);
      const bytes=await response.body(),actual=sha256(bytes);assert.equal(actual,expected,'actual served bytes match artifact manifest: '+file);
      sequenceArtifact.served_verified_files.push({file,sha256:actual,bytes:bytes.length});await response.dispose();
     }
    }
    await page.goto(url.href,{waitUntil:'networkidle'});await wait(()=>window.orafoldQA?.page==='lobby');await waitViewport();assert((await page.title()).includes('ORAFOLD'));
    console.log('LOBBY',engine,name);let menu=await state();
    for(const key of ['start','builder','collection','settings'])assert(menu.actions[key],key);
    for(const key of ['archive','mode_alpha','mode_legacy'])assert(!menu.actions[key],'no public route '+key);
    await shot('lobby');await action('collection');assert.equal((await state()).page,'collection');assert(!(await state()).actions.save_deck);
    if(!legacyOnly){
     const collection=await state(),viewport=page.viewportSize();
     const inside=r=>r[0]>=(insets?.left||0)&&r[1]>=(insets?.top||0)&&r[0]+r[2]<=viewport.width-(insets?.right||0)+1&&r[1]+r[3]<=viewport.height-(insets?.bottom||0)+1;
     // Cards are sorted by energy/name. A fixed card ID can be below the
     // ScrollContainer's visible first row; its full rect still exists in QA.
     // Inspect through the card's actual visible44CSS region. Its full176px
     // body may exceed a short scroll viewport; no offscreen/model hook is used.
     const visible=Object.entries(collection.actions).filter(([id,a])=>{const hit=touchRect(collection,id);return id.startsWith('card_')&&!a.disabled&&hit[2]>=43.9&&hit[3]>=43.9&&inside(hit);}).sort((a,b)=>touchRect(collection,a[0])[1]-touchRect(collection,b[0])[1]||touchRect(collection,a[0])[0]-touchRect(collection,b[0])[0]);
     assert(visible.length>0,'collection has an actual visible >=44CSS card');
     const [id,target]=visible[0],card=by[id.slice('card_'.length)];assert(card,'visible collection action identifies a real card');
     inspectedCard={id:card.id,name:card.name,rect:target.rect,hit_rect:touchRect(collection,id)};
     await action(id);const detail=await state();
     assert(detail.modal&&detail.actions.inspect_target&&detail.actions.modal_close,'card inspector with explicit close actions');
     assert(detail.modal_version>collection.modal_version,'inspection opened a new modal');
     assert.deepEqual(detail.deck_ids,collection.deck_ids,'read-only collection inspection preserves the deck');
     assert.equal(detail.page,'collection','inspection stays in the collection');
     assert(inside(detail.actions.modal_close.rect)&&detail.actions.modal_close.rect[2]>=43.9&&detail.actions.modal_close.rect[3]>=43.9,'inspector close is visible >=44CSS');
     await page.waitForFunction(expected=>{const i=window.orafoldQA.inspection,a=i?.art,size=expected[i?.id];return Boolean(size&&a?.state==='ready'&&a.status==='final'&&a.profile==='full'&&a.visible===true&&a.draw_count>0&&a.card_id===i.id&&a.requested_card_id===i.id&&a.preview_only===false&&a.pixels?.[0]===size[0]&&a.pixels?.[1]===size[1]);},fullGeometry,{timeout:90000});
     await shot('collection-inspection');await action('modal_close');
     const closed=await state();assert(!closed.modal&&closed.page==='collection','closing inspection restores collection');
     assert.deepEqual(closed.deck_ids,collection.deck_ids,'closing inspection preserves the deck');
     console.log('COLLECTION INSPECTION',engine,name,card.id,card.name);
    }
    await action('builder_back');
    if(!legacyOnly){await action('settings');const power={desktop:'houses','desktop-wide':'stillwatch',android:'ninth',iphone:'morph','android-bars':'houses','iphone-wide':'stillwatch','iphone-bars':'morph'}[name];await action('faction_'+power);await action('settings_back');}
    await opening();let q=await state();assert.equal(q.battle.hero.maxHp,legacyOnly?35:30);if(!legacyOnly)assert.equal(q.battle.enemy.maxHp,30);
    for(const key of ['end','actions','inspect','menu']){const r=q.actions[key].rect;assert(r[2]>=43.9&&r[3]>=43.9,`${key}:44CSS`);assert(r[0]>=0&&r[1]>=0&&r[0]+r[2]<=opts.viewport.width+1&&r[1]+r[3]<=opts.viewport.height+1,`${key}:bounds`);}
    for(const r of Object.values(q.board))assert(r[2]>=43.9&&r[3]>=43.9&&r[0]>=0&&r[1]>=0&&r[0]+r[2]<=opts.viewport.width+1&&r[1]+r[3]<=opts.viewport.height+1,'board safe bounds');
    const beforeLog=q.battle;await action('log');assert((await state()).modal&&(await state()).actions.verify_replay,'the secondary combat log is genuinely reachable through touch');await action('modal_close');assert.deepEqual((await state()).battle,beforeLog,'opening and closing the combat log preserves the complete battle');
    await shot('battle');if(!legacyOnly&&['desktop','iphone'].includes(name))await toolbarViewportChecks();await playTurn();
    if(!legacyOnly&&!(await state()).battle.winner)await checkAllVisibleArt();await shot('after-turn');
    if((await state()).battle.winner){await action('result_menu');}else{await action('menu');await action('confirm_menu');}
    await action('builder');await action('save_deck');await wait(()=>window.orafoldQA.message.includes('gespeichert'));await shot('builder');
    await page.reload({waitUntil:'networkidle'});await wait(()=>window.orafoldQA?.page==='lobby');await waitViewport();await action('builder');assert.equal((await state()).deck_size,legacyOnly?25:30);await action('builder_back');
    if(['desktop','desktop-wide','android','iphone'].includes(name)){
     let productionTemplate=null;
     if(!legacyOnly){
      const templateId=['desktop','iphone'].includes(name)?'prod-relic':'prod-aggro';
      await action('builder');await action('strategy_templates');await action('template_'+templateId);
      const loaded=await state();productionTemplate=JSON.parse(fs.readFileSync('data/production/test_decks.json','utf8')).decks.find(deck=>deck.id===templateId);profileTemplate=templateId;
      assert.deepEqual(loaded.deck_ids,productionTemplate.cards,'realproductiontemplate loads exact30cards');
      assert(loaded.deck_ids.some(id=>id.startsWith('of-')),'fullbrowsergame uses actual genericproductioncards');
      await action('save_deck');await action('builder_back');
     }
     if(sequenceEnabled){
      fs.mkdirSync(sequenceDir,{recursive:true});assert(!fs.existsSync(path.join(sequenceDir,'sequence.json')),'preserve the previous gameplay sequence; choose a new QA_GAMEPLAY_OUTPUT');
      gameplay={status:'running',recording:true,source_commit:process.env.EXPECTED_COMMIT,build_info:testedBuildInfo,artifact:sequenceArtifact,engine,browser_version:browser.version(),playwright:require('playwright/package.json').version,viewport:opts.viewport,dpr:opts.deviceScaleFactor||1,production_catalog_sha256:sha256(fs.readFileSync('data/production/cards.json')),art_manifest_sha256:sha256(fs.readFileSync('data/production/art_manifest.json')),strategy_template:profileTemplate,deck:productionTemplate.cards,seed:null,frames:[],inputs:[],replay:null};saveSequence();
     }
     await opening(productionTemplate?.power,productionTemplate?.cards,sequenceEnabled);
     let turns=0;while(!(await state()).battle.winner&&turns++<160){
      const q=await state();console.log('UI DUEL',engine,name,'turn',q.battle.round,'HP',q.battle.hero.hp,q.battle.enemy.hp,'commands',q.command_count);await playTurn();
      const current=await state();
      if(gameplay?.recording&&!current.battle.winner&&current.battle.round>=7&&gameplay.frames.some(frame=>frame.stage==='attack-resolution')&&!gameplay.frames.some(frame=>frame.stage==='midgame'))await sequenceFrame('midgame');
     }
     q=await state();assert(q.battle.winner,'complete UI duel');if(profileTemplate==='prod-relic')assert(relicActivations.some(value=>value.generic),'Reliktstrategie must exercise at least one real generic activation through UI');await shot('result');
     if(sequenceEnabled)await sequenceFrame('result');
     await action('result_log');
     if(sequenceEnabled){
      const [download]=await Promise.all([page.waitForEvent('download',{timeout:30000}),action('export_replay',{render:false})]);
      assert.equal(download.suggestedFilename(),'orafold-replay.json');const replayFile=path.join(sequenceDir,'orafold-replay.json');await download.saveAs(replayFile);
      const bytes=fs.readFileSync(replayFile),replay=JSON.parse(bytes);assert.equal(replay.format,'ORAFOLD-LOCAL-REPLAY');assert.equal(replay.version,2);assert.equal(replay.setup.seed,gameplay.seed);assert.equal(replay.setup.rules_profile,'production-550-v1');
      assert.deepEqual([...replay.setup.deck].sort(),[...productionTemplate.cards].sort());assert.equal(replay.commands.length,q.command_count);assert.equal(replay.winner,q.battle.winner);
      const firstPlay=gameplay.frames.find(frame=>frame.stage==='first-play'),attack=gameplay.frames.find(frame=>frame.stage==='attack-resolution');
      assert(firstPlay&&attack,'sequence requires an actual card play and a real end-turn with ready attackers');
      assert.equal(replay.commands[firstPlay.evidence.command_before].name,'play');assert.equal(replay.commands[attack.evidence.command_before].name,'endTurn');
      gameplay.replay={file:path.basename(replayFile),sha256:sha256(bytes),bytes:bytes.length,seed:replay.setup.seed,command_count:replay.commands.length,event_sha256:replay.event_sha256,final:replay.final,winner:replay.winner,verified_through_actual_ui:false};saveSequence();
     }
     await action('verify_replay');await wait(()=>window.orafoldQA.message==='Replay identisch.');
     if(sequenceEnabled){
      gameplay.replay.verified_through_actual_ui=true;
      await action('menu');await action('confirm_menu');await action('settings');await action('last_replay');await action('replay_next');
      assert((await state()).modal&&(await state()).actions.replay_previous?.disabled===false,'the actual stored replay viewer opens and advances');
      await sequenceFrame('replay',{viewer_step:1,total_commands:gameplay.replay.command_count,replay_file:gameplay.replay.file,replay_sha256:gameplay.replay.sha256,note:'The modal reconstructs replay prefix1; live_session_battle remains the completed original session and is not the displayed prefix.'});
      await action('modal_close');await action('settings_back');await opening(productionTemplate.power,productionTemplate.cards);
     }
     const beforeRestart=sequenceEnabled?await state():null;
     await action('restart');await action('confirm_restart');await wait(()=>!window.orafoldQA.battle.winner);await shot('restart');
     if(sequenceEnabled){
      const restarted=await state();assert.notEqual(restarted.battle.seed,beforeRestart.battle.seed,'actual Neu confirmation replaces the immediately preceding match');assert.equal(restarted.battle.stage,'mulligan');assert.equal(restarted.command_count,0);
      assert.deepEqual([...restarted.battle.hero.hand,...restarted.battle.hero.deck].sort(),[...productionTemplate.cards].sort(),'the confirmed restart retains the exact saved production deck');
      await sequenceFrame('restart',{path:'new match from lobby, then actual Neu / Neu starten confirmation',previous_seed:beforeRestart.battle.seed,previous_command_count:beforeRestart.command_count});gameplay.restart_seed=restarted.battle.seed;
      assert.deepEqual(gameplay.frames.map(frame=>frame.stage),['mulligan','opening','first-play','attack-resolution','midgame','result','replay','restart'],'all eight chronological stages must be present');
      assert(gameplay.frames.slice(0,-1).every(frame=>frame.seed===gameplay.seed),'the original duel and replay share the same actual seed');
      gameplay.recording=false;gameplay.status='passed';gameplay.action_trace=actionTrace;saveSequence();
     }
    }
    assert.equal(errors.length,0,errors.join('\n'));const result={engine,profile:name,browser_version:browser.version(),playwright:require('playwright/package.json').version,build_info:testedBuildInfo,viewport:opts.viewport,dpr:opts.deviceScaleFactor||1,errors,inspected_card:inspectedCard,strategy_template:profileTemplate,relic_activations:relicActivations,toolbar_viewport_tests:toolbarTests,bound_battle_art_checks:battleArtChecks,native_captures:captureMetrics,gameplay_sequence:gameplay?{status:gameplay.status,manifest:path.join(sequenceDir,"sequence.json"),seed:gameplay.seed,restart_seed:gameplay.restart_seed,frames:gameplay.frames.length,replay_sha256:gameplay.replay.sha256}:null,action_trace:actionTrace,checks:'real touch, menu, collection, visible inspector, settings, opening, ancestor-clipped44CSS bounds and actual pointer pan, saved deck reload; full games verify exact production template in actual match; relic activation uses actual enabled UI control',full_duel:['desktop','desktop-wide','android','iphone'].includes(name)?(legacyOnly?'legacy':'alpha'):null};results.push(result);
    fs.writeFileSync(`work/alpha/browser-result-${engine}-${name}.json`,JSON.stringify(result,null,2));
    console.log('ALPHA BROWSER PASS:',engine,name);
   }catch(error){const diagnostic=await page.evaluate(()=>({status:document.querySelector('#status')?.textContent,qa:window.orafoldQA})).catch(()=>null);if(gameplay){gameplay.status='failed';gameplay.error=String(error);gameplay.action_trace=actionTrace;saveSequence();}await shot('failure').catch(()=>{});fs.writeFileSync('work/alpha/browser-errors.json',JSON.stringify({engine,name,last_action:lastAction,errors,action_trace:actionTrace,native_captures:captureMetrics,diagnostic},null,2));throw error;}
   finally{clearInterval(progress);await context.close();}
  }finally{await browser.close();}
  }
 }
 assert(results.length>0,'no browser profile executed');fs.writeFileSync('work/alpha/browser-results.json',JSON.stringify(results,null,2));console.log(`ALPHA BROWSER: ${results.length} profiles,0 failures`);
})().catch(error=>{console.error(error);process.exit(1)});
