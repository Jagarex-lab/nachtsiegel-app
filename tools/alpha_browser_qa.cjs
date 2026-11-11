'use strict';
const {chromium,webkit,devices}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict'),path=require('node:path'),crypto=require('node:crypto');
const cards=[...JSON.parse(fs.readFileSync('data/production/cards.json','utf8')).cards,...JSON.parse(fs.readFileSync('data/legacy/cards.json','utf8')).cards],by=Object.fromEntries(cards.map(c=>[c.id,c]));
(async()=>{
 const url=new URL(process.env.GAME_URL||'http://127.0.0.1:8788/');url.searchParams.set('qa','1');
 const legacyOnly=process.env.QA_LEGACY_ONLY==='1';
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
   let inspectedCard=null,profileTemplate=null,testedBuildInfo=null,lastAction='boot',gameplay=null;const relicActivations=[],toolbarTests=[],actionTrace=[];
   const sequenceEnabled=recordGameplay&&engine==='chromium'&&name==='desktop',sequenceDir=path.resolve(process.env.QA_GAMEPLAY_OUTPUT||'work/alpha/gameplay-sequence');
   page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
   if(insets)await page.addInitScript(v=>Object.defineProperty(window,'nachtsiegelInsets',{configurable:true,get:()=>()=>v,set:()=>{}}),insets);
   const state=()=>page.evaluate(()=>window.orafoldQA);const progress=setInterval(async()=>{try{const q=await state();fs.writeFileSync(`work/alpha/browser-progress-${engine}-${name}.json`,JSON.stringify({engine,name,page:q?.page,modal:q?.modal,message:q?.message,commands:q?.command_count,battle:q?.battle},null,2));}catch{}},5000);progress.unref();
   const wait=fn=>page.waitForFunction(fn,undefined,{timeout:90000});
   const tap=async r=>{if(gameplay?.recording){const q=await state();gameplay.inputs.push({kind:'touch',point:[r[0]+r[2]/2,r[1]+r[3]/2],rect:r,seed:q.battle?.seed,command_count:q.command_count,selected:q.selected,phase:q.battle?.hero.phase,action:lastAction});}await page.touchscreen.tap(r[0]+r[2]/2,r[1]+r[3]/2);await page.waitForTimeout(90);};
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
    const clip=current.action_visibility[id].clip_rect,r=current.actions[id].rect;
    assert(clip[2]>=43.9&&clip[3]>=43.9,id+' scroll region can expose44CSS');
    const down=r[1]+r[3]>clip[1]+clip[3]+.1,up=r[1]<clip[1]-.1;
    assert(down||up,id+' horizontal clipping cannot be repaired by vertical pan');
    const sameClip=value=>value&&value.every((n,i)=>Math.abs(n-clip[i])<.1);
    const buttons=Object.entries(current.actions).filter(([key])=>sameClip(current.action_visibility[key]?.clip_rect)).map(([,value])=>value.rect);
    const ys=[down?clip[1]+clip[3]-24:clip[1]+24,clip[1]+clip[3]*.5,...buttons.flatMap(value=>[value[1]-2,value[1]+value[3]+2])].filter(y=>y>=clip[1]+8&&y<=clip[1]+clip[3]-8).sort((a,b)=>down?b-a:a-b);
    let point=null;
    for(const y of ys){for(const fraction of [.75,.25,.5]){const x=clip[0]+clip[2]*fraction;if(!buttons.some(value=>x>=value[0]&&x<=value[0]+value[2]&&y>=value[1]&&y<=value[1]+value[3])){point={x,y};break;}}if(point)break;}
    assert(point,id+' has a real scroll surface outside action buttons');
    const available=down?point.y-(clip[1]+8):clip[1]+clip[3]-8-point.y;
    const distance=Math.min(160,clip[3]*.6,available);assert(distance>10,id+' pan exceeds real scroll deadzone');
    const end={x:point.x,y:point.y+(down?-distance:distance)};
    if(capture){
     await capture.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...point,id:0,radiusX:2,radiusY:2,force:1}]});
     for(let step=1;step<=6;step++){await capture.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x:point.x,y:point.y+(end.y-point.y)*step/6,id:0,radiusX:2,radiusY:2,force:1}]});await page.waitForTimeout(35);}
     await capture.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    }else{
     // WebKit's public protocol provides tap only. Trusted browser mouse pan
     // reaches Godot's configured touch emulation; no DOM event/model hook.
     await page.mouse.move(point.x,point.y);await page.mouse.down();
     for(let step=1;step<=6;step++){await page.mouse.move(point.x,point.y+(end.y-point.y)*step/6);await page.waitForTimeout(35);}
     await page.mouse.up();
    }
    actionTrace.push({id,kind:'pan',driver:capture?'CDP primary touch':'browser mouse with Godot touch emulation',clip_rect:clip,from:point,to:end});
    await page.waitForTimeout(180);
   }
   const action=async (id,{render=true}={})=>{
    lastAction=id;if(id==='convergence'&&!(await state()).actions[id])await action('actions');
    await page.waitForFunction(id=>{const a=window.orafoldQA?.actions?.[id];return a&&!a.disabled&&a.rect[2]>=43.9&&a.rect[3]>=43.9;},id,{timeout:90000});
    let previous=await state();lastAction=id;
    if(legacyOnly&&!previous.action_visibility){
     for(let tries=0;tries<8&&!fullVisible(previous,id);tries++){
      const r=previous.actions[id].rect,v=page.viewportSize();await page.mouse.move(Math.max(1,Math.min(v.width-1,r[0]+r[2]/2)),v.height*.6);await page.mouse.wheel(0,r[1]<0?-v.height*.55:v.height*.55);await page.waitForTimeout(140);previous=await state();
     }
    }else for(let tries=0;tries<24&&!fullVisible(previous,id);tries++){await panTowards(previous,id);previous=await state();}
    assert(fullVisible(previous,id),id+' requires a visible44CSS card region or a fully visible button');
    const hit=touchRect(previous,id);assert(hit[2]>=43.9&&hit[3]>=43.9,id+' actual touch region remains44CSS');
    actionTrace.push({id,kind:'tap',rect:previous.actions[id].rect,hit_rect:hit,visibility:previous.action_visibility?.[id]||null});
    await tap(hit);if(render)await page.waitForFunction(v=>{const q=window.orafoldQA;return q.render_version>v.render_version||q.modal_version!==v.modal_version;},previous,{timeout:90000});
   };
   const capture=engine==='chromium'?await context.newCDPSession(page):null;
   const deadline=async (promise,message,ms)=>{let timer;return Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error(message)),ms);})]).finally(()=>clearTimeout(timer));};
   const shot=async tag=>{
    // QA render_version is updated while rebuilding Controls, before the
    // browser compositor necessarily has that canvas frame. Match the other
    // native-viewport harnesses and wait for paint before requesting readback.
    await deadline(page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))),'Screenshot paint timed out after15s',15000);
    await page.waitForTimeout(180);
    let buffer;
    if(capture){
     const viewport=page.viewportSize();let expiry;
     const response=await Promise.race([capture.send('Page.captureScreenshot',{format:'png',fromSurface:true,captureBeyondViewport:true,clip:{x:0,y:0,width:viewport.width,height:viewport.height,scale:opts.deviceScaleFactor||1}}),new Promise((_,reject)=>{expiry=setTimeout(()=>reject(new Error('CDP capture timed out after 30s')),30000)})]).finally(()=>clearTimeout(expiry));
     buffer=Buffer.from(response.data,'base64');
    }else buffer=await page.screenshot({timeout:30000});
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
   async function opening(customPower=null,expectedCards=null,recordOpening=false){
    await action('start');
    if(!legacyOnly){
     if(customPower)await action('custom_'+customPower);await action('deck_play');
     if(expectedCards){const hero=(await state()).battle.hero;assert.deepEqual([...hero.hand,...hero.deck].sort(),[...expectedCards].sort(),'actual new match contains the exact saved production template');}
     if(recordOpening){gameplay.seed=(await state()).battle.seed;await sequenceFrame('mulligan');}
    }
    if(legacyOnly){await wait(()=>window.orafoldQA.board.hero0);return;}
    await action('mulligan_done');await action('origin_2');await wait(()=>window.orafoldQA?.battle?.stage!=='origins');
    if((await state()).battle.stage==='second')await action('opening_done');await wait(()=>window.orafoldQA?.battle?.stage==='battle'&&window.orafoldQA.board.hero0);
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
      await shot('toolbar-'+height+'-six-cards');toolbarTests.push({viewport:{width:844,height},simulated_safe_insets:{left:44,right:44,top:0,bottom:21},available_height:height-21,hand_size:6,real_device_test:false});
     }
    }finally{
     await page.evaluate(()=>{const descriptor=window.__orafoldToolbarPriorInsets;if(descriptor)Object.defineProperty(window,'nachtsiegelInsets',descriptor);else delete window.nachtsiegelInsets;delete window.__orafoldToolbarPriorInsets;});
     const version=(await state()).render_version;await page.setViewportSize(previousViewport);await page.waitForFunction(v=>window.orafoldQA.render_version>v,version);
    }
    assert.deepEqual((await state()).battle,expected,'restoring browser geometry preserves all gameplay state');
   }
   async function playTurn(){
    for(let n=0;n<22;n++){
     let q=await state(),b=q.battle,p=b.hero;if(b.winner)return;
     if(p.phase==='draw'){
      if(p.hand.length+Math.min(p.pendingDraw,p.deck.length)>6){await page.waitForFunction(()=>window.orafoldQA.hand.length===window.orafoldQA.battle.hero.hand.length);await tap(q.hand[0].rect);}
      const before=q.command_count;await action('end');await page.waitForFunction(n=>window.orafoldQA.command_count>n||window.orafoldQA.battle.winner,before);continue;
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
    await page.goto(url.href,{waitUntil:'networkidle'});await wait(()=>window.orafoldQA?.page==='lobby');assert((await page.title()).includes('ORAFOLD'));
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
     await shot('collection-inspection');await action('modal_close');
     const closed=await state();assert(!closed.modal&&closed.page==='collection','closing inspection restores collection');
     assert.deepEqual(closed.deck_ids,collection.deck_ids,'closing inspection preserves the deck');
     console.log('COLLECTION INSPECTION',engine,name,card.id,card.name);
    }
    await action('builder_back');
    if(!legacyOnly){await action('settings');const power={desktop:'houses','desktop-wide':'stillwatch',android:'ninth',iphone:'morph','android-bars':'houses','iphone-wide':'stillwatch','iphone-bars':'morph'}[name];await action('faction_'+power);await action('settings_back');}
    await opening();let q=await state();assert.equal(q.battle.hero.maxHp,legacyOnly?35:30);if(!legacyOnly)assert.equal(q.battle.enemy.maxHp,30);
    for(const key of (legacyOnly?['end','actions','inspect','menu','log']:['end','actions','inspect','menu','log'])){const r=q.actions[key].rect;assert(r[2]>=43.9&&r[3]>=43.9,`${key}:44CSS`);assert(r[0]>=0&&r[1]>=0&&r[0]+r[2]<=opts.viewport.width+1&&r[1]+r[3]<=opts.viewport.height+1,`${key}:bounds`);}
    for(const r of Object.values(q.board))assert(r[2]>=43.9&&r[3]>=43.9&&r[0]>=0&&r[1]>=0&&r[0]+r[2]<=opts.viewport.width+1&&r[1]+r[3]<=opts.viewport.height+1,'board safe bounds');
    await shot('battle');if(!legacyOnly&&['desktop','iphone'].includes(name))await toolbarViewportChecks();await playTurn();await shot('after-turn');
    if((await state()).battle.winner){await action('result_menu');}else{await action('menu');await action('confirm_menu');}
    await action('builder');await action('save_deck');await wait(()=>window.orafoldQA.message.includes('gespeichert'));await shot('builder');
    await page.reload({waitUntil:'networkidle'});await wait(()=>window.orafoldQA?.page==='lobby');await action('builder');assert.equal((await state()).deck_size,legacyOnly?25:30);await action('builder_back');
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
      await action('result_menu');await action('settings');await action('last_replay');await action('replay_next');
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
    assert.equal(errors.length,0,errors.join('\n'));const result={engine,profile:name,browser_version:browser.version(),playwright:require('playwright/package.json').version,build_info:testedBuildInfo,viewport:opts.viewport,dpr:opts.deviceScaleFactor||1,errors,inspected_card:inspectedCard,strategy_template:profileTemplate,relic_activations:relicActivations,toolbar_viewport_tests:toolbarTests,gameplay_sequence:gameplay?{status:gameplay.status,manifest:path.join(sequenceDir,"sequence.json"),seed:gameplay.seed,restart_seed:gameplay.restart_seed,frames:gameplay.frames.length,replay_sha256:gameplay.replay.sha256}:null,action_trace:actionTrace,checks:'real touch, menu, collection, visible inspector, settings, opening, ancestor-clipped44CSS bounds and actual pointer pan, saved deck reload; full games verify exact production template in actual match; relic activation uses actual enabled UI control',full_duel:['desktop','desktop-wide','android','iphone'].includes(name)?(legacyOnly?'legacy':'alpha'):null};results.push(result);
    fs.writeFileSync(`work/alpha/browser-result-${engine}-${name}.json`,JSON.stringify(result,null,2));
    console.log('ALPHA BROWSER PASS:',engine,name);
   }catch(error){const diagnostic=await page.evaluate(()=>({status:document.querySelector('#status')?.textContent,qa:window.orafoldQA})).catch(()=>null);if(gameplay){gameplay.status='failed';gameplay.error=String(error);gameplay.action_trace=actionTrace;saveSequence();}await shot('failure').catch(()=>{});fs.writeFileSync('work/alpha/browser-errors.json',JSON.stringify({engine,name,last_action:lastAction,errors,action_trace:actionTrace,diagnostic},null,2));throw error;}
   finally{clearInterval(progress);await context.close();}
  }finally{await browser.close();}
  }
 }
 assert(results.length>0,'no browser profile executed');fs.writeFileSync('work/alpha/browser-results.json',JSON.stringify(results,null,2));console.log(`ALPHA BROWSER: ${results.length} profiles,0 failures`);
})().catch(error=>{console.error(error);process.exit(1)});
