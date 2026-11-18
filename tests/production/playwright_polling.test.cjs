'use strict';
// Real Playwright API regression on controlled about:blank QA-report fixtures.
// This does not run the game or provide gameplay or physical-device evidence.
const test = require('node:test');
const assert = require('node:assert/strict');
const {chromium,webkit,errors} = require('playwright');
const playwrightVersion = require('playwright/package.json').version;
const {stableMigrationTarget} = require('../../tools/production/migration_input_contract.cjs');

const viewport = {width:800,height:600};
const engines = [...new Set((process.env.QA_ENGINES || 'chromium').split(',').map(value=>value.trim()))];
const target = () => ({id:'start',viewport:{...viewport}});
const report = (sequence,{render=1,modal=0,rect=[12,104,366,58],modern=false}={}) => ({
  page:'lobby',modal:false,render_version:render,modal_version:modal,
  observation_seq:sequence,actions:{start:{disabled:false,rect:[...rect]}},
  ...(modern ? {density:3,layout_size:[2400,1800],
    action_visibility:{start:{clip_rect:[0,0,800,600],visible_rect:[...rect]}}} : {}),
});

// The first predicate read starts a finite browser-timer sequence. Keeping the
// first object across many animation frames exposes accidental same-object
// counting without depending on how quickly Node dispatches the wait call.
async function installReports(page,reports,{firstDelay=150,interval=90}={}) {
  await page.evaluate(({reports,firstDelay,interval})=>{
    const fixture = {reports,index:0,reads:[],started:false};
    window.__pollingFixture = fixture;
    Object.defineProperty(window,'orafoldQA',{configurable:true,get(){
      const current = fixture.reports[fixture.index];
      fixture.reads.push(current?.observation_seq ?? null);
      if (!fixture.started) {
        fixture.started = true;
        const publish = () => {
          if (fixture.index+1 >= fixture.reports.length) return;
          fixture.index++;
          fixture.timer = setTimeout(publish,interval);
        };
        fixture.timer = setTimeout(publish,firstDelay);
      }
      return current;
    }});
  },{reports,firstDelay,interval});
}

async function fixturePage(browser,t) {
  const page = await browser.newPage({viewport});
  t.after(()=>page.close());
  assert.equal(page.url(),'about:blank');
  return page;
}

for (const engine of engines) {
  assert(['chromium','webkit'].includes(engine),`Unsupported QA_ENGINES entry: ${engine}`);
  test(`${engine}: actual Playwright polling API on blank-page report fixtures`,{timeout:30000},async t=>{
    assert.equal(playwrightVersion,'1.65.0','the async-false negative control targets the pinned QA runtime');
    const browser = await (engine==='chromium' ? chromium : webkit).launch({headless:true,
      ...(engine==='chromium' ? {channel:'chromium',args:['--no-sandbox','--disable-dev-shm-usage',
        '--use-angle=swiftshader','--enable-unsafe-swiftshader']} : {}),
    });
    try {
      t.diagnostic(JSON.stringify({engine,browser_version:browser.version(),playwright:playwrightVersion,
        scope:'about:blank controlled QA-report fixtures; real Playwright API',gameplay:false,physical_device:false}));

      await t.test('pinned async-false negative control returns a false handle; production callback is synchronous',async t=>{
        const page = await fixturePage(browser,t);
        // The previous async readiness callback could resolve false after an
        // await. Playwright 1.65 accepts its Promise before checking that value.
        const oldAsyncFalse = async () => {
          await new Promise(resolve=>setTimeout(resolve,20));
          return false;
        };
        const oldHandle = await page.waitForFunction(oldAsyncFalse,undefined,{timeout:250});
        try {
          assert.equal(await oldHandle.jsonValue(),false,'known false-handle behavior is reproduced');
        } finally {
          await oldHandle.dispose();
        }
        // Inspect the immediate return inside the browser: page.evaluate would
        // otherwise await a Promise and hide the exact contract being tested.
        const immediate = await page.evaluate(({source,sample})=>{
          const predicate = eval('('+source+')');
          const value = predicate(sample);
          return {thenable:typeof value?.then==='function',value};
        },{source:stableMigrationTarget.toString(),sample:target()});
        assert.equal(immediate.thenable,false);
        assert.equal(immediate.value,false,'a missing report is synchronously false');
      });

      await t.test('the actual API preserves one mutable browser argument across synchronous polls',async t=>{
        const page = await fixturePage(browser,t), sample = {polls:0};
        const handle = await page.waitForFunction(state=>{
          state.polls++;
          return state.polls>=3 ? state.polls : false;
        },sample,{timeout:500});
        try {
          assert.equal(await handle.jsonValue(),3);
          assert.deepEqual(sample,{polls:0},'Playwright cloned the argument instead of mutating Node state');
        } finally {
          await handle.dispose();
        }
      });

      for (const modern of [false,true]) {
        await t.test(`${modern ? 'current' : 'old'} report shape: epoch and geometry changes need three fresh stable reports`,async t=>{
          const page = await fixturePage(browser,t), finalRect = [28,136,340,52];
          const phases = [
            {},{},
            {render:2},{render:2},
            {render:2,modal:1},{render:2,modal:1},
            {render:2,modal:1,rect:finalRect},
            {render:2,modal:1,rect:finalRect},
            {render:2,modal:1,rect:finalRect},
          ];
          await installReports(page,phases.map((phase,index)=>report(index+1,{...phase,modern})));
          const sample = target();
          const handle = await page.waitForFunction(stableMigrationTarget,sample,{timeout:4000});
          try {
            const ready = await handle.jsonValue();
            assert(ready && typeof ready==='object','readiness must return a report, never a false handle');
            assert.equal(ready.observation_seq,9,'each changed epoch or rectangle resets the three-report count');
            assert.equal(ready.render_version,2);
            assert.equal(ready.modal_version,1);
            assert.deepEqual(ready.actions.start.rect,finalRect);
            const observation = await handle.evaluate(value=>({
              actualReport:window.__pollingFixture.reports.includes(value),
              currentReport:value===window.orafoldQA,
              readSequences:[...new Set(window.__pollingFixture.reads)],
            }));
            assert.equal(observation.actualReport,true,'the callback returns an actual published report object');
            assert.equal(observation.currentReport,true);
            for (const sequence of [7,8,9]) {
              assert(observation.readSequences.includes(sequence),`fresh stable report ${sequence} was actually observed`);
            }
            assert.deepEqual(sample,target(),'stability state lives in the serialized browser argument');
          } finally {
            await handle.dispose();
          }
        });
      }

      const invalid = report(1);invalid.actions.start.rect[3]=43;
      const failureCases = [
        ['missing reports',[null]],
        ['invalid 43CSS reports',[invalid]],
        ['one unchanged report object',[report(1)]],
        ['continuously changing valid reports',Array.from({length:20},(_,index)=>report(index+1,
          {render:index+1,rect:[12+index,104,366,58]}))],
      ];
      for (const [label,reports] of failureCases) {
        await t.test(`${label} reject with the real bounded Playwright TimeoutError`,async t=>{
          const page = await fixturePage(browser,t);
          await installReports(page,reports,{firstDelay:25,interval:40});
          // No retries or global UI deadline: false must keep polling until
          // this fixture's explicit deadline produces the real API error.
          await assert.rejects(async()=>{
            const unexpected = await page.waitForFunction(stableMigrationTarget,target(),{timeout:400});
            try {
              assert.fail(`unexpected resolved handle: ${JSON.stringify(await unexpected.jsonValue())}`);
            } finally {
              await unexpected.dispose();
            }
          },error=>error instanceof errors.TimeoutError && error.name==='TimeoutError');
        });
      }
    } finally {
      await browser.close();
    }
  });
}
