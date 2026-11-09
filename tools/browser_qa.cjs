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
  const browser=await (engine==='webkit'?webkit:chromium).launch({
   executablePath:engine==='chromium'?(process.env.CHROMIUM_BIN || undefined):undefined,
   headless:true,...(engine==='chromium'?{args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']}:{})
  });
  try {
   for(const profile of profiles[engine]){
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
     await wait(()=>!document.querySelector('#status')&&window.nachtsiegelQA?.round===1);
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
     q=await state();await tap(q.modal_actions.find(b=>b.caption==='ZURÜCK').rect);
     await wait(()=>window.nachtsiegelQA.modal==='');
     if(engine==='chromium'&&name==='desktop'){
      await tap(q.actions.menu);await wait(()=>window.nachtsiegelQA.modal==='menu');
      q=await state();await tap(q.modal_actions.find(b=>b.caption==='VOLLBILD').rect);
      await wait(()=>!!document.fullscreenElement);
      await page.screenshot({path:base+'-fullscreen.png'});
      await page.evaluate(()=>document.exitFullscreen());
      await page.waitForTimeout(250);
     }
     // A real viewport-height change approximates expanding browser bars.
     const shorter={width:options.viewport.width,height:Math.max(300,options.viewport.height-30)};
     await page.setViewportSize(shorter);await page.waitForTimeout(400);q=await state();
     const end=q.actions.end;assert(end[3]>=43.99&&end[1]+end[3]<=shorter.height+.5,'Browser-bar resize keeps action reachable');
     await page.screenshot({path:base+'-bars.png'});
     assert.equal(errors.length,0,JSON.stringify(errors));
     results.push({engine,profile:name,viewport:options.viewport,deviceScaleFactor:options.deviceScaleFactor||1,metadata,target:target.href,errors,checks:'CSS touch targets, first summon, double-tap inspection, end turn, contextual hints, motion preference and viewport resize'});
     console.log(`BROWSER PASS: ${engine} ${name}`);
    }catch(e){await page.screenshot({path:base+'-failure.png'}).catch(()=>{});throw e}
    finally{await context.close()}
   }
  }finally{await browser.close()}
 }
 fs.writeFileSync(`work/${prefix}-results.json`,JSON.stringify(results,null,2));
 if(prefix==='web')fs.copyFileSync('work/web-results.json','work/browser-results.json');
 console.log(`BROWSER: ${results.length} device/engine profiles, 0 failures`);
})().catch(e=>{console.error(e);process.exit(1)});
