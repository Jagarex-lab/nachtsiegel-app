// Defaults to the local export; GAME_URL also verifies the published Pages game.
const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const browser = await chromium.launch({executablePath:process.env.CHROMIUM_BIN || undefined,headless:true,args:['--no-sandbox','--disable-dev-shm-usage','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
  try {
  const results=[];
  const target=process.env.GAME_URL || 'http://127.0.0.1:8765/';
  const prefix=process.env.QA_PREFIX || 'web';
  for(const size of [{width:1280,height:720},{width:844,height:390}]) {
    const context=await browser.newContext({viewport:size,hasTouch:true,deviceScaleFactor:1});
    const page=await context.newPage();
    const errors=[];
    page.on('pageerror', e=>errors.push(String(e)));
    page.on('console', msg=>{if(msg.type()==='error') errors.push(msg.text());});
    let metadata=null;
    if(process.env.EXPECTED_COMMIT) {
      const infoUrl=new URL('build-info.json',target);
      infoUrl.searchParams.set('v',process.env.EXPECTED_COMMIT);
      const response=await page.request.get(infoUrl.href);
      if(!response.ok()) throw Error(`Build metadata HTTP ${response.status()}`);
      metadata=await response.json();
      if(metadata.commit!==process.env.EXPECTED_COMMIT) throw Error(`Wrong live commit: ${metadata.commit}`);
    }
    await page.goto(target,{waitUntil:'networkidle'});
    await page.waitForFunction(()=>!document.querySelector('#status'),null,{timeout:90000});
    await page.waitForTimeout(1000);
    await page.screenshot({path:`work/${prefix}-${size.width}x${size.height}-start.png`});
    const scale=Math.min(size.width/1600,size.height/900);
    const offsetX=(size.width-1600*scale)/2, offsetY=(size.height-900*scale)/2;
    await page.touchscreen.tap(offsetX+1475*scale,offsetY+580*scale);
    await page.waitForTimeout(1000);
    await page.screenshot({path:`work/${prefix}-${size.width}x${size.height}-turn2.png`});
    const canvas=await page.locator('#canvas').boundingBox();
    if(!canvas || canvas.width<300 || errors.length) throw Error(JSON.stringify({size,canvas,errors}));
    results.push({target,metadata,viewport:size,canvas,errors,touch:'End turn tapped; see turn2 screenshot for visual verification'});
    await context.close();
  }
  fs.writeFileSync(`work/${prefix}-results.json`,JSON.stringify(results,null,2));
  if(prefix==='web') fs.copyFileSync('work/web-results.json','work/browser-results.json');
  console.log('BROWSER: two viewports started; touch end turn; no console/page errors');
  } finally {
    await browser.close();
  }
})().catch(e=>{console.error(e);process.exit(1);});
