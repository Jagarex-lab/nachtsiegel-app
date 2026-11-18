'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {stableMigrationTarget,migrationActionAccepted} = require('../../tools/production/migration_input_contract.cjs');
const root = path.resolve(__dirname,'../..');
const viewport = {width:390,height:844};
const button = (rect=[12,218,366,44],disabled=false) => ({rect,disabled});
const lobby = () => ({page:'lobby',modal:false,render_version:1,modal_version:0,deck_ids:[],deck_size:0,power:'houses',
  actions:{builder:button(),settings:button([12,410,366,44]),start:button([12,104,366,58])}});
const builder = () => ({...lobby(),page:'builder',render_version:3,
  actions:{builder_back:button([300,8,82,44]),save_deck:button([8,792,180,44])}});
const clone = value => structuredClone(value);
function browser(report) {
  const window = {orafoldQA:report};
  const sandbox = vm.createContext({window});
  // Exercise the exact functions Playwright serializes, with no module or
  // enclosing Node functions available in the browser's execution context.
  const stable = vm.runInContext('('+stableMigrationTarget.toString()+')',sandbox);
  const accepted = vm.runInContext('('+migrationActionAccepted.toString()+')',sandbox);
  const publish = next => { window.orafoldQA = next; };
  return {window,stable,accepted,publish};
}

test('three distinct stable 44CSS reports permit one deliberate semantic builder navigation',()=>{
  const page = browser(lobby()), sample = {id:'builder',viewport};
  assert.equal(page.stable(sample),false);
  page.publish(clone(page.window.orafoldQA));
  assert.equal(page.stable(sample),false,'two reports are not yet a stable input target');
  page.publish(clone(page.window.orafoldQA));
  const before = page.stable(sample);
  assert.equal(before,page.window.orafoldQA);
  assert.equal(page.accepted({id:'builder',before}),false,'readiness alone never acknowledges a touch');
  let taps = 0;
  taps++;page.window.orafoldQA = builder();
  assert.equal(page.accepted({id:'builder',before}),true);
  assert.equal(taps,1);
});

test('re-reading one report on multiple polls never counts as fresh stability',()=>{
  const report = lobby(), second = clone(report), page = browser(report), sample = {id:'builder',viewport};
  for (let poll=0;poll<8;poll++) assert.equal(page.stable(sample),false);
  page.publish(second);
  assert.equal(page.stable(sample),false);
  for (const duplicate of [report,second,report,second]) {
    page.publish(duplicate);
    assert.equal(page.stable(sample),false,'nonconsecutive duplicate reports do not count');
  }
  page.publish(clone(report));
  assert.equal(page.stable(sample),page.window.orafoldQA);
});

test('any page, modal, render, modal epoch or exact target rectangle change resets readiness',()=>{
  for (const mutate of [
    report=>{report.page='settings';},report=>{report.modal=true;},
    report=>{report.render_version++;},report=>{report.modal_version++;},
    report=>{report.actions.builder.rect[1]+=.01;},report=>{report.actions.builder.disabled=true;},
    report=>{delete report.actions.builder;},
  ]) {
    for (const changedSample of [1,2]) {
      const page = browser(lobby()), sample = {id:'builder',viewport};
      assert.equal(page.stable(sample),false);
      if (changedSample === 2) {
        page.publish(clone(page.window.orafoldQA));
        assert.equal(page.stable(sample),false);
      }
      const changed = clone(page.window.orafoldQA);mutate(changed);page.publish(changed);
      assert.equal(page.stable(sample),false);
    }
  }
});

test('the serialized stable predicate returns synchronous false or the actual report on every path',()=>{
  const page = browser(lobby()), sample = {id:'builder',viewport};
  const poll = target => {
    const result = page.stable(target);
    assert.notEqual(typeof result?.then,'function','Playwright must receive a synchronous predicate result');
    assert(result === false || result === page.window.orafoldQA);
    return result;
  };
  for (const target of [undefined,null,{}, {id:'builder'}, {id:'builder',viewport:{width:0,height:844}}]) {
    assert.equal(poll(target),false);
  }
  assert.equal(poll(sample),false);
  assert.equal(poll(sample),false,'duplicate report remains a synchronous false');
  page.publish(undefined);assert.equal(poll(sample),false);
  page.publish(lobby());assert.equal(poll(sample),false);
  const changed = lobby();changed.render_version++;
  page.publish(changed);assert.equal(poll(sample),false);
  page.publish(clone(changed));assert.equal(poll(sample),false);
  page.publish(clone(changed));assert.equal(poll(sample),page.window.orafoldQA);
});

test('unstable reports recover only after three fresh reports in the new exact context',()=>{
  for (const mutate of [
    report=>{report.page='settings';},report=>{report.modal=true;},
    report=>{report.render_version++;},report=>{report.modal_version++;},
    report=>{report.actions.builder.rect[1]+=.01;},
  ]) {
    const page = browser(lobby()), sample = {id:'builder',viewport};
    assert.equal(page.stable(sample),false);
    page.publish(clone(page.window.orafoldQA));assert.equal(page.stable(sample),false);
    const changed = clone(page.window.orafoldQA);mutate(changed);
    const bytes = JSON.stringify(changed);
    Object.freeze(changed.actions.builder.rect);Object.freeze(changed.actions.builder);
    Object.freeze(changed.actions);Object.freeze(changed);
    page.publish(changed);assert.equal(page.stable(sample),false);
    assert.equal(page.stable(sample),false,'the changed object is only one observation');
    page.publish(clone(changed));assert.equal(page.stable(sample),false);
    page.publish(clone(changed));assert.equal(page.stable(sample),page.window.orafoldQA);
    assert.equal(JSON.stringify(changed),bytes,'the predicate never changes observed reports');
  }
});

test('forever-changing or missing reports never become ready and invalid samples clear progress',()=>{
  const page = browser(lobby()), sample = {id:'builder',viewport:{...viewport}};
  for (let poll=0;poll<50;poll++) {
    const changing = lobby();changing.render_version=poll+1;
    page.publish(changing);assert.equal(page.stable(sample),false);
  }
  for (let cycle=0;cycle<8;cycle++) {
    for (let poll=0;poll<2;poll++) {
      page.publish(lobby());assert.equal(page.stable(sample),false);
    }
    page.publish(cycle%2 ? undefined : {...lobby(),actions:{}});
    assert.equal(page.stable(sample),false,'a missing report or target clears prior observations');
  }
  for (let poll=0;poll<2;poll++) {
    page.publish(lobby());assert.equal(page.stable(sample),false);
  }
  sample.viewport.width=0;assert.equal(page.stable(sample),false);
  sample.viewport.width=viewport.width;
  for (let poll=0;poll<2;poll++) {
    page.publish(lobby());assert.equal(page.stable(sample),false);
  }
  page.publish(lobby());assert.equal(page.stable(sample),page.window.orafoldQA);
});

test('the captured WebKit lobby render advance cannot acknowledge the rejected builder touch',()=>{
  // Verified artifact14387047303/job134494017498: the final diagnostic still
  // has the seven main-menu actions, empty lobby deck, no browser errors and
  // render_version2. These are the relevant exact observed fields/coordinates.
  const captured = {...lobby(),render_version:2,actions:{builder:button(),
    campaign:button([12,170,366,44]),collection:button([12,266,366,44]),
    economy:button([12,314,366,44]),online:button([12,362,366,44]),
    settings:button([12,410,366,44]),start:button([12,104,366,58])}};
  const before = lobby(), page = browser(captured);
  const oldPoll = vm.runInNewContext('(previous=>window.orafoldQA.render_version>previous.render_version||window.orafoldQA.modal_version!==previous.modal_version)',{window:page.window});
  assert.equal(oldPoll(before),true,'the original driver mistakes startup rendering for an accepted tap');
  const bytes = JSON.stringify(captured);
  for (let poll=0;poll<100;poll++) assert.equal(page.accepted({id:'builder',before}),false);
  assert.equal(JSON.stringify(captured),bytes,'polling never changes the actual reports');
});

test('missing, malformed, disabled, undersized and out-of-viewport targets never become ready',()=>{
  for (const report of [undefined,null,{}, {...lobby(),modal:undefined}, {...lobby(),render_version:undefined},
    {...lobby(),modal_version:undefined}, {...lobby(),actions:{}},
    ...[button([12,218,366,43]),button([12,218,43,44]),button([-1,218,366,44]),
      button([12,802,366,44]),button([12,218,380,44]),button([12,218,NaN,44]),
      {rect:[12,218,366,44]},button([12,218,366,44],true)].map(action=>({...lobby(),actions:{builder:action}}))]) {
    const page = browser(report), sample = {id:'builder',viewport};
    for (let poll=0;poll<8;poll++) {
      page.publish(clone(report));
      assert.equal(page.stable(sample),false);
    }
  }
  for (const target of [undefined,null,false,1,{}, {id:''}, {id:'builder'}, {id:'builder',viewport:{width:0,height:844}}]) {
    assert.equal(browser(lobby()).stable(target),false);
  }
});

test('builder completion requires actual builder controls but leaves exact deck failure visible',()=>{
  const before = lobby();
  for (const report of [undefined,null,{},lobby(),{...builder(),modal:true},
    {...builder(),actions:{}},{...builder(),actions:{builder_back:button()}},
    {...builder(),actions:{save_deck:button()}},{...builder(),render_version:1},
    {...builder(),actions:{builder_back:button(),save_deck:{}}}]) {
    const page = browser(report);
    for (let poll=0;poll<20;poll++) assert.equal(page.accepted({id:'builder',before}),false);
  }
  const invalidDeck = builder();invalidDeck.actions.save_deck.disabled=true;
  const page = browser(invalidDeck);
  assert.equal(page.accepted({id:'builder',before}),true,'present disabled save still publishes an invalid deck');
  assert.throws(()=>assert.deepEqual(page.window.orafoldQA.deck_ids,['saved-card']),{code:'ERR_ASSERTION'},
    'the original exact deck assertion fails immediately; readiness never waits for expected deck values');
});

test('old and modern report formats both stabilize without requiring modern clip or density fields',()=>{
  for (const modern of [false,true]) {
    const report = lobby();
    if (modern) {report.density=3;report.layout_size=[1170,2532];report.action_visibility={builder:{clip_rect:[8,8,374,828],visible_rect:[12,218,366,44]}};}
    const page = browser(report), sample = {id:'builder',viewport};
    assert.equal(page.stable(sample),false);
    page.publish(clone(report));assert.equal(page.stable(sample),false);
    page.publish(clone(report));assert.equal(page.stable(sample).page,'lobby');
  }
});

test('navigation, modal and tab completion must publish the requested actual UI',()=>{
  const before = lobby();
  for (const [id,report] of [
    ['settings',{...builder(),page:'settings',actions:{settings_back:button(),motion:button()}}],
    ['collection',{...builder(),page:'collection',actions:{builder_back:button()}}],
    ['start',{...builder(),page:'decks',actions:{decks_back:button(),deck_play:button()}}],
    ['builder_back',{...lobby(),render_version:4}],
    ['settings_back',{...lobby(),render_version:4}],['decks_back',{...lobby(),render_version:4}],
    ['difficulty',{...lobby(),page:'settings',modal:true,modal_version:2,actions:{option_difficulty_Taktisch:button()}}],
    ['option_difficulty_Taktisch',{...builder(),page:'settings',actions:{settings_back:button(),motion:button()}}],
    ['deck_tab',{...builder(),deck_tab:'deck'}],['library_tab',{...builder(),deck_tab:'library'}],
    ['deck_play',{...builder(),page:'battle',battle:{stage:'mulligan',hero:{hand:[],deck:[]}}}],
  ]) {
    const page = browser(report);
    assert.equal(page.accepted({id,before}),true,id);
    page.window.orafoldQA = {...report,page:'wrong'};
    assert.equal(page.accepted({id,before}),false,id+' cannot accept unrelated rendering');
  }
});

test('removing the last card copy may remove its input control while keeping exact deck assertions immediate',()=>{
  const before = {...builder(),render_version:2,deck_ids:['last-copy'],deck_size:1,
    actions:{...builder().actions,remove_last_copy:button()}};
  const after = builder(), page = browser(after);
  assert.equal(page.window.orafoldQA.actions.remove_last_copy,undefined);
  assert.equal(page.accepted({id:'remove_last_copy',before}),true);
  assert.deepEqual(page.window.orafoldQA.deck_ids,[]);
});

test('actual migration driver uses one shared deadline and one tap for main and stale-tab actions',()=>{
  const source = fs.readFileSync(path.join(root,'tools/production/browser_migration_qa.cjs'),'utf8');
  assert(source.includes("require('./migration_input_contract.cjs')"));
  assert(source.includes('inputWait(stableMigrationTarget,{id,viewport:target.viewportSize()})'));
  assert(source.includes('inputWait(migrationActionAccepted,{id,before})'));
  assert(source.includes('const deadline=Date.now()+TIMEOUT;'));
  assert(source.includes('timeout:Math.max(1,deadline-Date.now())'));
  assert(source.includes('const TIMEOUT=120000;'));
  assert(source.includes('await trustedAction(page,id)'));
  assert(source.includes('await trustedAction(oldTab,id,true)'));
  assert.equal((source.match(/target\.touchscreen\.tap\(/g)||[]).length,1);
  assert(!source.includes('current.render_version>previous.render_version'),'unrelated-render acknowledgement is removed');
  for (const label of ['production restart ignores the later stale version1 write','production restart restores exact migrated deck',
    'old exact deck survives initial production load','real new match uses protected new-card deck multiset',
    'quota failure leaves independent primary bytes unchanged','44CSS touch area for ']) assert(source.includes(label));
});

test('the existing production gate mandates the regression and both source syntax checks',()=>{
  const gate = fs.readFileSync(path.join(root,'tools/test_production.sh'),'utf8');
  assert(gate.includes('set -euo pipefail'));
  assert(gate.includes('node --check tools/production/migration_input_contract.cjs'));
  assert(gate.includes('node --check tools/production/browser_migration_qa.cjs'));
  assert(gate.includes('node --test tests/production/migration_input_contract.test.cjs'));
});
