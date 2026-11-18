'use strict';
// Serialized by Playwright into the actual page. Keep it self-contained: these
// reports arrive independently after navigation/reload, and neither is a hook
// for changing the hosted campaign or manufacturing a successful game state.
function campaignScreenReady(expected) {
  const shell = window.orafoldQA;
  const campaign = window.orafoldCampaignQA;
  const target = typeof expected === 'string' ? {screen: expected} : expected;
  if (typeof target?.screen !== 'string' || !target.screen.length ||
      shell?.page !== 'campaign' || shell?.hosted_page !== 'campaign' ||
      campaign?.screen !== target.screen) return false;
  if (target.screen === 'battle' &&
      (typeof shell.battle?.stage !== 'string' || !shell.battle.stage.length)) return false;
  if (target.stage !== undefined && target.stageNot !== undefined) return false;
  if (target.stage !== undefined) {
    return typeof target.stage === 'string' && target.stage.length > 0 &&
      shell.battle?.stage === target.stage;
  }
  if (target.stageNot !== undefined) {
    const actualStage = shell.battle?.stage;
    return typeof target.stageNot === 'string' && target.stageNot.length > 0 &&
      typeof actualStage === 'string' && actualStage.length > 0 && actualStage !== target.stageNot;
  }
  return true;
}
module.exports = {campaignScreenReady};
