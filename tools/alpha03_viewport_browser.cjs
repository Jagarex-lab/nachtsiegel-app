'use strict';
// Real Chromium/WebKit DOM + timer regression for the exported shell's actual
// viewport bridge. No Godot export is needed. --baseline runs the prior bridge
// and its prior GDScript layout equations to show the stale-buffer failure.
const fs = require('node:fs');
const cp = require('node:child_process');
const assert = require('node:assert/strict');
const {chromium, webkit} = require('playwright');
const baseline = process.argv.includes('--baseline');
const baselineRef = process.env.VIEWPORT_BASELINE_REF || '345edb6e683d4359b8141ef228683c0855773ac2';
const html = baseline ? cp.execFileSync('git',['show',baselineRef+':web/shell.html'],{encoding:'utf8'}) : fs.readFileSync('web/shell.html','utf8');
const bridge = html.match(/<script>([\s\S]*?)<\/script>/)[1];
const style = html.match(/<style>([\s\S]*?)<\/style>/)[1];
const output = {scope:'Real Linux browser shell bridge; injected Safari timing/visual viewport faults. Not physical iPhone or full Godot export.',baseline,baselineRef:baseline?baselineRef:null,browsers:[]};
(async () => {
 for (const [name,kind] of [['chromium',chromium],['webkit',webkit]].filter(([name])=>(process.env.QA_ENGINES||'chromium,webkit').split(',').includes(name))) {
  const browser = await kind.launch({headless:true,...(name==='chromium'?{channel:'chromium'}:{}),args:name==='chromium'?['--no-sandbox','--disable-dev-shm-usage']:[]});
  try {
   const page = await browser.newPage({viewport:{width:390,height:844},hasTouch:true});
   const errors=[];page.on('pageerror',e=>errors.push(String(e)));
   const fixture=(width,height)=>`<style>${style}</style><canvas id="canvas" width="${width}" height="${height}"></canvas><input id="keyboard"><script>
    window.testViewport={width:${width},height:${height}};
    Object.defineProperty(window,'innerWidth',{configurable:true,get:()=>testViewport.width});
    Object.defineProperty(window,'innerHeight',{configurable:true,get:()=>testViewport.height});
    window.testVisual=new EventTarget();Object.assign(testVisual,{width:${width},height:${height},scale:1,offsetLeft:0,offsetTop:0});
    Object.defineProperty(window,'visualViewport',{configurable:true,value:testVisual});
    Object.defineProperty(screen,'orientation',{configurable:true,value:undefined});
   </script><script>${bridge}</script>`;
   await page.setContent(fixture(390,844));
   await page.evaluate(() => {window.testInsets={};window.nachtsiegelInsets=()=>testInsets;});
   const results=[];
   const check=async(label,predicate)=>{const value=await predicate();results.push({label,pass:!!value});};
   const change=async(width,height,visual={},event='resize')=>{
    await page.setViewportSize({width,height});
    await page.evaluate(({width,height,visual,event})=>{Object.assign(testViewport,{width,height});Object.assign(testVisual,{width,height,scale:1,offsetLeft:0,offsetTop:0},visual);window.dispatchEvent(new Event(event));},{width,height,visual,event});
    await page.waitForTimeout(70);
   };
   const state=()=>page.evaluate(()=>{
    const c=gameCanvas,r=c.getBoundingClientRect();
    if(window.orafoldViewportMetrics)return {...orafoldViewportMetrics(),cssWidth:r.width,cssHeight:r.height};
    // Prior _layout used Control.size (backing buffer), one X density, and
    // independent live visualViewport measurements. Keep those equations here.
    const density=c.width/Math.max(1,r.width),i=nachtsiegelInsets();
    return {portrait:c.height>c.width,width:r.width,height:r.height,cssWidth:r.width,cssHeight:r.height,
     visibleHeight:Math.max(160,Math.min(c.height/density-testVisual.offsetTop,testVisual.height)-(i.top||0)-(i.bottom||0)),visualValid:true};
   });
   await check('portrait without screen.orientation',async()=> (await state()).portrait);
   await change(844,390);
   await check('landscape despite stale portrait Godot buffer',async()=> !(await state()).portrait);
   await check('CSS canvas is upright and fills landscape',async()=>{const s=await state();return s.cssWidth===844&&s.cssHeight===390&&await page.evaluate(()=>getComputedStyle(gameCanvas).transform==='none');});
   await page.evaluate(()=>Object.defineProperty(screen,'orientation',{configurable:true,value:{type:'portrait-primary',angle:0}}));
   await check('stale screen.orientation cannot force portrait',async()=> !(await state()).portrait);
   await change(844,390,{width:390,height:844});
   await check('stale portrait visualViewport rejected',async()=>{const s=await state();return s.visualValid===false&&s.visibleHeight===390;});
   // Safari sometimes fires orientationchange before dimensions, without a
   // second resize. Mutate dimensions later and let the bounded retries find it.
   await change(390,844);
   await page.evaluate(()=>window.dispatchEvent(new Event('orientationchange')));
   await page.waitForTimeout(90);
   await page.setViewportSize({width:844,height:390});
   await page.evaluate(()=>{Object.assign(testViewport,{width:844,height:390});Object.assign(testVisual,{width:844,height:390});});
   await page.waitForTimeout(650);
   await check('late dimensions settle without final resize',async()=>{const s=await state();return !s.portrait&&s.cssWidth===844&&s.cssHeight===390;});
   for(const order of ['width-first','height-first']) {
    await change(390,844);
    await page.evaluate(order=>{Object.assign(testViewport,order==='width-first'?{width:844}:{height:390});window.dispatchEvent(new Event('orientationchange'));},order);
    await page.waitForTimeout(80);
    await page.setViewportSize({width:844,height:390});
    await page.evaluate(()=>{Object.assign(testViewport,{width:844,height:390});Object.assign(testVisual,{width:844,height:390});});
    await page.waitForTimeout(330);
    await check(order+' rotation settles',async()=>{const s=await state();return !s.portrait&&s.cssHeight===390;});
   }
   await page.evaluate(()=>{testInsets={left:47,right:47,bottom:21};});
   await change(844,390,{height:299});
   await check('address bar and safe area retained in snapshot',async()=>{const s=await state();return !s.portrait&&s.visibleHeight===299&&s.insets?.left===47&&s.insets?.bottom===21;});
   await change(844,390,{height:220});
   await check('under248 usable landscape is not portrait',async()=>{const s=await state();return !s.portrait&&s.visibleHeight===220;});
   await change(390,844);
   await page.locator('#keyboard').focus();
   await change(390,310);
   await check('same-width keyboard cannot flip portrait',async()=> (await state()).portrait);
   await page.locator('#keyboard').blur();
   await change(844,390,{width:422,height:160,scale:2,offsetLeft:100,offsetTop:60});
   await check('zoom and pan fit visible rect without changing orientation',async()=>{const s=await state();return !s.portrait&&s.visualValid&&s.visibleWidth===422&&s.visibleHeight===160&&s.visibleLeft===100&&s.visibleTop===60;});
   await change(844,390,{width:0,height:0,scale:0});
   await check('unavailable visual viewport dimensions use layout',async()=>{const s=await state();return !s.portrait&&!s.visualValid&&s.visibleWidth===844&&s.visibleHeight===390;});
   for(let i=0;i<4;i++){await change(390,844);await change(844,390);}
   await check('repeated turns return landscape upright',async()=>{const s=await state();return !s.portrait&&s.cssWidth===844&&s.cssHeight===390;});
   const version=await page.evaluate(()=>window.orafoldViewportVersion);
   await page.waitForTimeout(1800);
   await check('settling retries end without redraw loop',async()=>await page.evaluate(()=>window.orafoldViewportVersion)===version);
   await page.evaluate(()=>{Object.defineProperty(window,'visualViewport',{configurable:true,value:undefined});window.dispatchEvent(new Event('resize'));});
   await check('missing visualViewport uses layout',async()=>{const s=await state();return !s.portrait&&s.visibleHeight===390;});
   // A fresh document in landscape exercises the startup/reload branch. It
   // makes no claim that an in-progress match survives browser navigation.
   await page.goto('about:blank');
   await page.setViewportSize({width:844,height:390});
   await page.setContent(fixture(844,390));
   await page.waitForTimeout(70);
   await check('fresh landscape document needs no extra rotation',async()=>{const s=await state();return !s.portrait&&s.cssWidth===844&&s.cssHeight===390;});
   await check('no browser script errors',async()=>errors.length===0);
   output.browsers.push({name,version:browser.version(),results,errors});
  } finally {await browser.close();}
 }
 console.log(JSON.stringify(output,null,2));
 assert(output.browsers.every(b=>b.results.every(r=>r.pass)),'viewport regression failed');
})().catch(e=>{console.error(e);process.exitCode=1;});
