// UI geometry is exported in CSS pixels only with ?qa=1. Normal play has no QA bridge.
const { chromium, webkit, devices } = require('playwright');
const fs = require('fs');
const assert = require('assert/strict');
(async () => {
 const target=new URL(process.env.GAME_URL || 'http://127.0.0.1:8765/');
 target.searchParams.set('qa','1');
 const prefix=process.env.QA_PREFIX || 'web';
 const results=[];
 const engines=(process.env.QA_ENGINES || 'chromium,webkit').split(',');
 const profiles={
  chromium:[
   {name:'desktop',viewport:{width:1280,height:720},hasTouch:true},
   {name:'desktop-wide',viewport:{width:1600,height:900},hasTouch:true},
   {...devices['Pixel 7'],name:'android-landscape',viewport:{width:915,height:412},deviceScaleFactor:1},
   {...devices['Pixel 7'],name:'android-bars',viewport:{width:844,height:320},deviceScaleFactor:2,insets:{left:44,right:44,top:0,bottom:21}}
  ],
  webkit:[
   {...devices['iPhone 13'],name:'iphone-landscape',viewport:{width:844,height:390},deviceScaleFactor:3},
   {...devices['iPhone 13 Pro Max'],name:'iphone-wide',viewport:{width:915,height:412},deviceScaleFactor:1},
   {...devices['iPhone 13'],name:'iphone-reduced',viewport:{width:844,height:320},deviceScaleFactor:1,reducedMotion:'reduce',insets:{left:44,right:44,top:0,bottom:21}}
  ]
 };
 for(const engine of engines){
  // A fresh browser process per profile prevents WPE/WebGL resources from
  // previous full tutorial/reload runs accumulating across mobile contexts.
  for(const profile of profiles[engine].filter(p=>!process.env.QA_PROFILES||process.env.QA_PROFILES.split(',').includes(p.name))){
  const browser=await (engine==='webkit'?webkit:chromium).launch({
   executablePath:engine==='chromium'?(process.env.CHROMIUM_BIN || undefined):undefined,
   headless:true,...(engine==='chromium'?{args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']}:{})
  });
  try {
    console.log('BROWSER RUNTIME',engine,browser.version(),require('playwright/package.json').version);
    const {name,insets,...options}=profile;
    const context=await browser.newContext(options);
    const page=await context.newPage();
    const errors=[];
    page.on('pageerror',e=>errors.push(String(e)));
    page.on('console',m=>{if(m.type()==='error') errors.push(m.text());});
    if(insets) await page.addInitScript(insets=>{
     Object.defineProperty(window,'nachtsiegelInsets',{configurable:true,get:()=>()=>insets,set:()=>{}});
    },insets);
    let metadata=null;
    if(process.env.EXPECTED_COMMIT){
     const info=new URL('build-info.json',target);info.searchParams.set('v',process.env.EXPECTED_COMMIT);
     const response=await page.request.get(info.href);
     assert(response.ok(),`Build metadata HTTP ${response.status()}`);
     metadata=await response.json();assert.equal(metadata.commit,process.env.EXPECTED_COMMIT);
    }
    const base=`work/${prefix}-${engine}-${name}`;
    const state=()=>page.evaluate(()=>window.nachtsiegelQA);
    const wait=async(fn,arg)=>page.waitForFunction(fn,arg,{timeout:90000});
    const tap=async rect=>page.touchscreen.tap(rect[0]+rect[2]/2,rect[1]+rect[3]/2);
    try{
     await page.goto(target.href,{waitUntil:'networkidle'});
     await wait(()=>!document.querySelector('#status')&&window.nachtsiegelHub?.page==='start');
     const hub=()=>page.evaluate(()=>window.nachtsiegelHub);
     const hubTap=async(id,next)=>{const h=await hub();assert(h.actions[id]&&!h.actions[id].disabled,id+' available');await tap(h.actions[id].rect);if(next)await wait(p=>window.nachtsiegelHub.page===p,next);};
     await page.screenshot({path:base+'-home-start.png'});
     await hubTap('begin','intro');await hubTap('intro_skip','heroes');
     await hubTap('hero_ash_king');await wait(()=>window.nachtsiegelHub.selected_hero==='ash_king');
     await hubTap('start_tutorial','battle');
     await wait(()=>window.nachtsiegelQA?.round===1);
     await page.waitForTimeout(500);
     const identity=require('../data/brand/identity.json');
     const releaseName=identity.approved_product_name||identity.legacy_product_name;
     assert.equal((await page.title()).replace(/ \(DEBUG\)$/,''),releaseName,'Central release brand reaches browser title (Godot debug suffix allowed)');
     assert((await page.locator('#canvas').getAttribute('aria-label')).startsWith(releaseName),'Canvas uses central release brand');
     assert.notEqual(releaseName,identity.preview.de,'Draft name stays separate');
     let q=await state();
     if(options.reducedMotion==='reduce') assert(q.reduced_motion,'OS reduced-motion respected');
     for(const [label,css] of Object.entries(q.text_css))assert(css>=11.99,`${name}: ${label} is at least 12 CSS px`);
     for(const [label,r] of Object.entries(q.actions)){
      if(label==='details')continue;
      assert(r[2]>=43.99&&r[3]>=43.99,`${name}: ${label} >=44 CSS px`);
      assert(r[0]>=0&&r[1]>=0&&r[0]+r[2]<=options.viewport.width+.5&&r[1]+r[3]<=options.viewport.height+.5,`${label}: inside visible viewport`);
     }
     await page.screenshot({path:base+'-start.png'});
     if(engine==='chromium'&&name==='desktop'){
      const r=q.actions.end;await page.mouse.move(r[0]+r[2]/2,r[1]+r[3]/2);
      await page.screenshot({path:base+'-hover.png'});
     }
     const card=q.cards.find(c=>c.kind==='unit'&&c.cost<=q.energy);assert(card,'First playable creature');
     await tap(card.rect);
     await wait(index=>window.nachtsiegelQA.selected===index,card.index);
     await page.waitForTimeout(200);
     q=await state();assert.equal(q.onboarding,1,'First-time guidance advances on selection');
     await page.screenshot({path:base+'-selected.png'});
     await tap(q.cards[card.index].rect);
     await wait(()=>window.nachtsiegelQA.modal==='card');
     await page.screenshot({path:base+'-inspection.png'});
     q=await state();const back=q.modal_actions.find(b=>b.caption==='ZIEL WÄHLEN');assert(back);
     assert(back.rect[2]>=44&&back.rect[3]>=44,'Inspection return target');
     await tap(back.rect);await wait(()=>window.nachtsiegelQA.modal==='');
     q=await state();await tap(q.targets[0].rect);
     await wait(()=>window.nachtsiegelQA.selected===-1);
     q=await state();assert.equal(q.energy,3-card.cost,'Summon spends energy exactly once');
     assert.equal(q.onboarding,2,'First-time guidance reaches end turn');
     await tap(q.actions.end);
     await wait(()=>window.nachtsiegelQA.round===2&&!window.nachtsiegelQA.busy);
     await page.waitForTimeout(400);q=await state();
     assert.equal(q.onboarding,3,'Tutorial disappears after understood first turn');
     await page.screenshot({path:base+'-turn2.png'});
     await tap(q.actions.menu);await wait(()=>window.nachtsiegelQA.modal==='menu');
     q=await state();const toggle=q.modal_actions.find(b=>b.caption.startsWith('BEWEGUNG'));assert(toggle);
     const motionBefore=q.reduced_motion;await tap(toggle.rect);
     await wait(before=>window.nachtsiegelQA.reduced_motion!==before,motionBefore);
     q=await state();await tap(q.modal_actions.find(b=>b.caption==='ZURÜCK'||b.caption==='WEITERSPIELEN').rect);
     await wait(()=>window.nachtsiegelQA.modal==='');
     // A real viewport-height change approximates expanding browser bars.
     const shorter={width:options.viewport.width,height:Math.max(300,options.viewport.height-30)};
     await page.setViewportSize(shorter);await page.waitForTimeout(400);q=await state();
     const end=q.actions.end;assert(end[3]>=43.99&&end[1]+end[3]<=shorter.height+.5,'Browser-bar resize keeps action reachable');
     await page.screenshot({path:base+'-bars.png'});
     // Complete a real tutorial with actual touch commands; no health/result injection.
     await page.setViewportSize(options.viewport);await page.waitForTimeout(250);
     for(let turn=0;turn<45;turn++){
      q=await state();console.log(`QA ${engine}/${name}: tutorial round ${q.round}, hp ${q.player_hp}/${q.foe_hp}`);if(q.finished)break;
      for(let move=0;move<8;move++){
       q=await state();let best=null;
       for(const c of q.cards){if(c.cost>q.energy)continue;
        for(let lane=0;lane<5;lane++){let score=-999;
         if(c.kind==='unit'&&q.summons<2&&!q.allies[lane])score=c.attack*2+c.hp*2+(!q.enemies[lane]?12:(c.attack>=q.enemies[lane].hp?8:0));
         if(c.kind==='spell'&&q.enemies[lane])score=q.enemies[lane].hp<=3?80:15;
         if(score>=0&&(!best||score>best.score))best={c,lane,score};
        }
       }
       if(!best)break;
       await tap(best.c.rect);await wait(i=>window.nachtsiegelQA.selected===i,best.c.index);
       q=await state();await tap((best.c.kind==='spell'?q.foes:q.targets)[best.lane].rect);
       await wait(()=>window.nachtsiegelQA.selected===-1);
      }
      q=await state();const before=q.round;await tap(q.actions.end);
      await wait(r=>window.nachtsiegelQA.finished||(window.nachtsiegelQA.round>r&&!window.nachtsiegelQA.busy),before);
     }
     q=await state();assert(q.finished,'Tutorial reaches a genuine result');
     let h=await hub();assert(h.tutorial_completed&&h.wins===1&&h.unlocked_chapter===1,'Real victory saved and chapter one unlocked');
     await wait(()=>window.nachtsiegelQA.modal==='result');q=await state();await page.screenshot({path:base+'-tutorial-result.png'});
     await tap(q.modal_actions.find(a=>a.caption==='HAUPTMENÜ').rect);await wait(()=>window.nachtsiegelHub.page==='home');
     await hubTap('settings','settings');await hubTap('av_settings','av');
     h=await hub();const gain=h.audio_sliders.SFX;
     await page.touchscreen.tap(gain[0]+1,gain[1]+gain[3]/2);await wait(()=>window.nachtsiegelHub.audio.SFX===0);
     await hubTap('effects');await wait(()=>window.nachtsiegelHub.low_effects===true);
     await page.screenshot({path:base+'-mixer.png'});
     await hubTap('back','settings');await hubTap('back','home');
     await page.waitForTimeout(1200);await page.reload({waitUntil:'networkidle'});await wait(()=>window.nachtsiegelHub?.page==='start');
     h=await hub();assert(h.tutorial_completed&&h.selected_hero==='ash_king'&&h.wins===1,'Reload retains tutorial, wins and selected hero');
     assert(h.audio.SFX===0&&h.low_effects===true,'Mixer mute and low-effects mode survive reload');
     await hubTap('begin','home');await page.screenshot({path:base+'-home-progress.png'});
     if(engine==='chromium'&&name==='desktop'){
      await hubTap('settings','settings');await hubTap('fullscreen');await wait(()=>!!document.fullscreenElement);
      await page.screenshot({path:base+'-fullscreen.png'});await page.evaluate(()=>document.exitFullscreen());await page.waitForTimeout(250);await hubTap('back','home');
     }
     await hubTap('campaign','campaign');h=await hub();assert(!h.actions.chapter_1.disabled&&h.actions.chapter_2.disabled,'Chapter progression gated');
     await hubTap('chapter_1','chapter');await page.screenshot({path:base+'-chapter.png'});
     await hubTap('back','campaign');await hubTap('back','home');await hubTap('collection','collection');
     h=await hub();assert.equal(h.visible_cards.length,7,'Exactly seven implemented cards');
     await hubTap('filter');await wait(()=>window.nachtsiegelHub.visible_cards.length===3);
     await hubTap('concepts');await wait(()=>window.nachtsiegelHub.visible_cards.length>3);
     h=await hub();await tap(h.search_rect);
     await wait(()=>['INPUT','TEXTAREA'].includes(document.activeElement?.tagName)&&!document.activeElement.disabled);
     await page.keyboard.type('Ofenlehrling');
     assert.equal(await page.evaluate(()=>document.activeElement.value),'Ofenlehrling','Real mobile HTML input forwards text to Godot');
     await wait(()=>window.nachtsiegelHub.visible_cards.length===1&&window.nachtsiegelHub.visible_cards[0]==='furnace_apprentice');
     await page.screenshot({path:base+'-collection-search.png'});
     if(name==='android-bars'){
      await page.setViewportSize({width:options.viewport.width,height:200});await wait(()=>window.nachtsiegelHub.keyboard_layout);
      h=await hub();assert(h.search_rect[1]+h.search_rect[3]<=200,'Typing layout keeps input above keyboard');
      assert.equal(await page.evaluate(()=>document.activeElement.value),'Ofenlehrling','Virtual keyboard input survives viewport shrink');
      await page.screenshot({path:base+'-keyboard.png'});await page.setViewportSize(options.viewport);await page.waitForTimeout(300);
     }
     await hubTap('card_furnace_apprentice','inspect');await page.screenshot({path:base+'-concept.png'});
     await hubTap('collection_back','collection');await hubTap('back','home');
     assert.equal(errors.length,0,JSON.stringify(errors));
     results.push({engine,profile:name,viewport:options.viewport,deviceScaleFactor:options.deviceScaleFactor||1,metadata,target:target.href,errors,checks:'touch, full tutorial victory, hero selection, saved reload, locked chapters, collection search/filter, concept inspection, safe areas and motion preference'});
     console.log(`BROWSER PASS: ${engine} ${name}`);
    }catch(e){
     const diagnostic=await page.evaluate(()=>({status:document.querySelector('#status')?.textContent,hub:window.nachtsiegelHub?.page,game:window.nachtsiegelQA?.round})).catch(()=>null);
     fs.writeFileSync(base+'-failure.json',JSON.stringify({error:String(e),errors,diagnostic},null,2));
     await page.screenshot({path:base+'-failure.png'}).catch(()=>{});throw e}
    finally{await context.close()}
  }finally{await browser.close()}
  }
 }
 fs.writeFileSync(`work/${prefix}-results.json`,JSON.stringify(results,null,2));
 if(prefix==='web')fs.copyFileSync('work/web-results.json','work/browser-results.json');
 console.log(`BROWSER: ${results.length} device/engine profiles, 0 failures`);
})().catch(e=>{console.error(e);process.exit(1)});
