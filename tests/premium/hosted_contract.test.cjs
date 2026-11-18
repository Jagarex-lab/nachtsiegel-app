'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {campaignScreenReady} = require('../../tools/premium/hosted_contract.cjs');
const root = path.resolve(__dirname, '../..');

function browser(window = {}) {
  const sandbox = vm.createContext({window});
  // Playwright serializes the actual function into the browser. Exercise that
  // exact source with no CommonJS module/closure available in the page context.
  const poll = vm.runInContext('(' + campaignScreenReady.toString() + ')', sandbox);
  return {window, poll};
}
function campaign(screen = 'overview', battle) {
  return {orafoldQA: {page:'campaign',hosted_page:'campaign',...(battle ? {battle} : {})},orafoldCampaignQA:{screen}};
}

test('serialized campaign polling waits for absent and partial reports without throwing', () => {
  for (const window of [{},{orafoldQA:null},{orafoldQA:{}},{orafoldCampaignQA:{}},
    {orafoldQA:{page:'campaign',hosted_page:'campaign'}},
    {orafoldQA:{page:'campaign',hosted_page:'campaign'},orafoldCampaignQA:null}]) {
    assert.equal(browser(window).poll('overview'),false);
  }
});

test('stale campaign reports cannot satisfy readiness on another actual hosted page', () => {
  for (const shell of [
    {page:'lobby',hosted_page:''},
    {page:'economy',hosted_page:'economy'},
    {page:'lobby',hosted_page:'campaign'},
    {page:'campaign',hosted_page:'economy'},
    {page:'campaign'},
    {hosted_page:'campaign'},
  ]) assert.equal(browser({orafoldQA:shell,orafoldCampaignQA:{screen:'overview'}}).poll('overview'),false);
});

test('the exact requested screen must be published in the actual campaign context', () => {
  for (const screen of ['overview','dialogue','battle']) {
    const page = browser(campaign(screen,screen==='battle'?{stage:'mulligan'}:undefined));
    for (const requested of ['overview','dialogue','battle']) assert.equal(page.poll(requested),requested===screen);
  }
});

test('campaign resume waits for the shell battle report as well as the campaign screen', () => {
  for (const battle of [undefined,null,{}, {stage:null}, {stage:''}]) {
    assert.equal(browser(campaign('battle',battle)).poll('battle'),false);
  }
  const page=browser(campaign('battle'));
  assert.equal(page.poll('battle'),false);
  page.window.orafoldQA.battle={stage:'mulligan'};
  assert.equal(page.poll('battle'),true);
});

test('the actual failed reload ordering waits until both independent reports arrive', () => {
  const page = browser({orafoldQA:{page:'lobby',hosted_page:''}});
  assert.equal(page.poll('overview'),false);
  // A real shell campaign tap publishes its feature before the campaign scene
  // has emitted the first orafoldCampaignQA report (WebKit job134494300084).
  page.window.orafoldQA = {page:'campaign',hosted_page:'campaign'};
  assert.equal(page.poll('overview'),false);
  page.window.orafoldCampaignQA = {screen:'overview'};
  assert.equal(page.poll('overview'),true);
  delete page.window.orafoldCampaignQA;
  assert.equal(page.poll('overview'),false,'a repeated reload must wait again');
  page.window.orafoldCampaignQA = {screen:'dialogue'};
  assert.equal(page.poll('overview'),false);
  page.window.orafoldCampaignQA = {screen:'overview'};
  assert.equal(page.poll('overview'),true);
});

test('the captured WebKit failure has a usable campaign UI before its separate report', () => {
  // Minimal projection of the actual verified artifact14387386310, source
  //389674fab9a0216009a28c68b16fe8b4d3616d14, job134494300084. Its failure
  // observation contains q only: the campaign field is absent, not a fake UI.
  const window = {orafoldQA:{page:'campaign',hosted_page:'campaign',render_version:3,
    hosted_actions:[{id:'resume'},{id:'chapter_cp01'},{id:'chapter_cp02'}]}};
  const oldPoll = vm.runInNewContext("(()=>window.orafoldCampaignQA.screen==='overview')",{window});
  assert.throws(oldPoll,error=>error.name==='TypeError','the original callback fails on the captured actual state');
  const page = browser(window);
  assert.equal(page.poll('overview'),false,'the correction waits while preserving the actual campaign UI');
  page.window.orafoldCampaignQA = {screen:'overview'};
  assert.equal(page.poll('overview'),true);
});

test('permanently missing or incorrect reports never become a readiness success', () => {
  for (const window of [{},campaign('dialogue'),{orafoldQA:{page:'lobby',hosted_page:''},orafoldCampaignQA:{screen:'overview'}}]) {
    const before = JSON.stringify(window), page = browser(window);
    for (let poll=0;poll<100;poll++) assert.equal(page.poll('overview'),false);
    assert.equal(JSON.stringify(window),before,'the predicate cannot manufacture reports or alter game state');
  }
});

test('campaign battle and actual mulligan remain one conjunctive readiness condition', () => {
  const target = {screen:'battle',stage:'mulligan'};
  for (const window of [campaign('overview',{stage:'mulligan'}),campaign('battle'),campaign('battle',{}),campaign('battle',{stage:'origin'})]) {
    assert.equal(browser(window).poll(target),false);
  }
  assert.equal(browser(campaign('battle',{stage:'mulligan'})).poll(target),true);
});

test('a negated mulligan condition requires a real nonempty stage, not undefined', () => {
  const target = {screen:'battle',stageNot:'mulligan'};
  for (const stage of [undefined,null,'',0,'mulligan']) assert.equal(browser(campaign('battle',{stage})).poll(target),false);
  assert.equal(browser(campaign('battle',{stage:'origin'})).poll(target),true);
  assert.equal(browser(campaign('overview',{stage:'origin'})).poll(target),false);
});

test('invalid target definitions cannot accidentally match missing data', () => {
  const page = browser(campaign('overview',{stage:'origin'}));
  for (const target of [undefined,null,'',{},[],{screen:''},{screen:1},{screen:'overview',stage:''},
    {screen:'overview',stageNot:''},{screen:'overview',stage:'origin',stageNot:'mulligan'}]) assert.equal(page.poll(target),false);
});

test('actual hosted journey uses the guarded predicate at all screen and stage waits', () => {
  const source = fs.readFileSync(path.join(root,'tools/premium/hosted_browser_qa.cjs'),'utf8');
  assert(source.includes("const {campaignScreenReady} = require('./hosted_contract.cjs');"));
  assert.equal((source.match(/await wait\(campaignScreenReady,/g)||[]).length,8);
  assert(!/window\.orafoldCampaignQA(?:\?\.)?\.?(?:screen)/.test(source),'no unguarded or separate campaign-screen callback remains');
  assert(source.includes("await wait(campaignScreenReady,{screen:'battle',stage:'mulligan'})"));
  assert(source.includes("await wait(campaignScreenReady,{screen:'battle',stageNot:'mulligan'})"));
  assert(source.includes('page.waitForFunction(fn,arg,{timeout:60000})'),'existing action wait deadline is retained');
  assert(source.includes('},720000)'),'existing overall journey deadline is retained');
});

test('new regression and both source syntax checks are mandatory in the existing gate', () => {
  const gate = fs.readFileSync(path.join(root,'tools/test_premium.sh'),'utf8');
  assert(gate.includes('set -euo pipefail'));
  assert(gate.includes('tools/premium/hosted_contract.cjs tools/premium/hosted_browser_qa.cjs'));
  assert(gate.includes('tests/premium/campaign_header_contract.test.cjs tests/premium/hosted_contract.test.cjs tests/release/public_integrity.test.cjs'));
  for (const original of ['tests/premium/browser_contract.test.cjs','tools/premium/test_pwa.cjs','tools/premium/test_worker.cjs']) assert(gate.includes(original));
});
