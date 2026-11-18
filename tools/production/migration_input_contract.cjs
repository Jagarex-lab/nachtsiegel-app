'use strict';
// Playwright serializes these functions into both actual runtimes. Keep them
// self-contained and read-only: QA reports are observations, never input hooks.
function stableMigrationTarget(sample = {}) {
  if (!sample || typeof sample !== 'object') return false;
  const {id,viewport} = sample;
  if (typeof id !== 'string' || !id || !Number.isFinite(viewport?.width) ||
      !Number.isFinite(viewport?.height) || viewport.width <= 0 || viewport.height <= 0) {
    delete sample._migrationTarget;
    return false;
  }
  const ready = report => {
    const action = report?.actions?.[id], rect = action?.rect;
    return typeof report?.page === 'string' && report.page.length > 0 &&
      typeof report.modal === 'boolean' && Number.isInteger(report.render_version) && report.render_version > 0 &&
      Number.isInteger(report.modal_version) && report.modal_version >= 0 && action?.disabled === false &&
      Array.isArray(rect) && rect.length === 4 && rect.every(Number.isFinite) &&
      rect[2] >= 43.9 && rect[3] >= 43.9 && rect[0] >= -.1 && rect[1] >= -.1 &&
      rect[0]+rect[2] <= viewport.width+1 && rect[1]+rect[3] <= viewport.height+1;
  };
  const current = window.orafoldQA;
  if (!ready(current)) {
    delete sample._migrationTarget;
    return false;
  }
  const previous = sample._migrationTarget, rect = current.actions[id].rect;
  // Playwright retains the argument between synchronous polls. Keep our
  // observations there: an async predicate can resolve a false value as a
  // completed wait. QA reports remain read-only, including their rectangles.
  if (!previous || previous.id !== id || previous.width !== viewport.width || previous.height !== viewport.height ||
      current.page !== previous.page || current.modal !== previous.modal ||
      current.render_version !== previous.render_version || current.modal_version !== previous.modal_version ||
      rect.some((value,index) => value !== previous.rect[index])) {
    sample._migrationTarget = {id,width:viewport.width,height:viewport.height,
      page:current.page,modal:current.modal,render_version:current.render_version,modal_version:current.modal_version,
      rect:rect.slice(),reports:[current]};
    return false;
  }
  // The game replaces its report every ~100ms. Re-reading one object cannot
  // establish freshness or hide its deferred startup/viewport render.
  if (previous.reports.length < 3 && !previous.reports.includes(current)) previous.reports.push(current);
  return previous.reports.length >= 3 ? current : false;
}

function migrationActionAccepted({id,before} = {}) {
  const current = window.orafoldQA;
  if (typeof id !== 'string' || !id || !before || !current ||
      !Number.isInteger(before.render_version) || !Number.isInteger(current.render_version) ||
      !Number.isInteger(before.modal_version) || !Number.isInteger(current.modal_version) ||
      typeof current.modal !== 'boolean' ||
      !(current.render_version > before.render_version || current.modal_version !== before.modal_version)) return false;
  const control = key => {
    const action = current.actions?.[key];
    return typeof action?.disabled === 'boolean' && Array.isArray(action.rect) &&
      action.rect.length === 4 && action.rect.every(Number.isFinite);
  };
  const on = (page,...keys) => current.page === page && current.modal === false && keys.every(control);
  // A render advance alone cannot acknowledge navigation: it may only be the
  // startup viewport render that invalidated the original touch. Save presence
  // proves the builder UI is published; its deck is checked immediately by the
  // existing exact assertions, including invalid/empty decks.
  if (id === 'builder') return on('builder','builder_back','save_deck');
  if (id === 'collection') return on('collection','builder_back') && !current.actions.save_deck;
  if (id === 'settings') return on('settings','settings_back','motion');
  if (id === 'start') return on('decks','decks_back','deck_play');
  if (['builder_back','settings_back','decks_back'].includes(id)) return on('lobby','builder','settings','start');
  if (id === 'difficulty') return current.page === 'settings' && current.modal === true && control('option_difficulty_Taktisch');
  if (id.startsWith('option_difficulty_')) return on('settings','settings_back','motion');
  if (id === 'deck_play') return current.page === 'battle' && current.modal === false &&
    typeof current.battle?.stage === 'string' && current.battle.stage.length > 0 &&
    Array.isArray(current.battle.hero?.hand) && Array.isArray(current.battle.hero?.deck);
  if (id === 'deck_tab' || id === 'library_tab') return on('builder','save_deck','builder_back') &&
    current.deck_tab === (id === 'deck_tab' ? 'deck' : 'library');
  if (id.startsWith('add_') || id.startsWith('remove_')) return on('builder','save_deck','builder_back');
  // Settings toggles, search, edits and saves retain their exact downstream
  // persisted-byte/deck/match assertions. Do not poll for expected deck data.
  return current.page === before.page && current.modal === before.modal && control(id);
}

module.exports = {stableMigrationTarget,migrationActionAccepted};
