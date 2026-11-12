'use strict';
// Observations only. Never resize a canvas, reset browser emulation or upscale
// pixels to make a screenshot pass. The context supplies its expected DPR.
const assert=require('node:assert/strict');
function nativeGeometry(metrics,viewport,factor){
 assert(Number.isFinite(factor)&&factor>0,'an explicit expected context DPR is required');
 assert(metrics&&Number.isFinite(metrics.dpr),'actual browser DPR is required');
 assert(Math.abs(metrics.dpr-factor)<.001,'actual browser DPR matches the context');
 assert(metrics.canvas,'actual canvas backing and CSS bounds are required');
 const {css,backing}=metrics.canvas;
 assert(Array.isArray(css)&&css.length===4&&css.every(Number.isFinite),'actual canvas CSS bounds are required');
 assert(Array.isArray(backing)&&backing.length===2&&backing.every(Number.isFinite),'actual canvas backing dimensions are required');
 assert(Math.abs(css[0])<1&&Math.abs(css[1])<1&&Math.abs(css[2]-viewport.width)<1&&Math.abs(css[3]-viewport.height)<1,'canvas fills the actual CSS viewport');
 assert(Math.abs(backing[0]-css[2]*factor)<=1&&Math.abs(backing[1]-css[3]*factor)<=1,'canvas backing renders both axes at native context DPR');
 assert(metrics.body_width>=viewport.width-1&&metrics.body_width<=viewport.width+1,'body CSS width matches the requested viewport');
 assert(Math.abs(metrics.inner[0]-viewport.width)<1&&Math.abs(metrics.inner[1]-viewport.height)<1,'window dimensions match the requested viewport');
 return true;
}
function assertNativeCapture(before,after,png,viewport,factor){
 nativeGeometry(before,viewport,factor);nativeGeometry(after,viewport,factor);
 assert.deepEqual(after,before,'screenshot preserves browser DPR and actual canvas CSS/backing geometry');
 assert(Buffer.isBuffer(png)&&png.length>=24&&png.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])),'capture contains an actual PNG');
 assert.equal(png.readUInt32BE(16),Math.round(viewport.width*factor),'PNG has native context pixel width');
 assert.equal(png.readUInt32BE(20),Math.round(viewport.height*factor),'PNG has native context pixel height');
 return true;
}
async function nativeCapture(page,{factor,timeout,receipts,tag}){
 const viewport=page.viewportSize();
 const observe=()=>page.evaluate(()=>{const c=document.querySelector('canvas'),r=c?.getBoundingClientRect();return {dpr:devicePixelRatio,inner:[innerWidth,innerHeight],body_width:document.body.getBoundingClientRect().width,canvas:c?{backing:[c.width,c.height],css:[r.x,r.y,r.width,r.height]}:null};});
 const receipt={tag,expected_dpr:factor,viewport,method:'playwright device-scale screenshot',timeout_ms:timeout,before:await observe()};
 receipts.push(receipt);nativeGeometry(receipt.before,viewport,factor);
 const png=await page.screenshot({scale:'device',timeout});receipt.after=await observe();
 assertNativeCapture(receipt.before,receipt.after,png,viewport,factor);receipt.validated=true;return png;
}
module.exports={nativeGeometry,assertNativeCapture,nativeCapture};
