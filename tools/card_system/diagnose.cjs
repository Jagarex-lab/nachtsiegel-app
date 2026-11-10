#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {validateNamesAcrossPools} = require('./contract.cjs');
const ROOT = path.resolve(__dirname, '../..');
const normalize = value => Array.isArray(value) ? value.map(normalize) : value && typeof value === 'object'
  ? Object.fromEntries(Object.keys(value).sort().map(key => [key, normalize(value[key])])) : value;

// Defined diagnostic only: it intentionally excludes name, art, flavour and faction.
// A warning across factions does not assert identical reaction/synergy behaviour.
function signature(card) {
  let fields;
  if (card.source_binding) {
    fields = [card.kind, card.energy_cost, card.attack || 0, card.health || 0, card.source_binding.effect, card.source_binding.power];
  } else if (Array.isArray(card.abilities)) {
    fields = [card.kind, card.energy_cost, card.attack || 0, card.health || 0, normalize(card.abilities), card.resonance_cost || 0, card.species?.slice().sort() || []];
  } else fields = [card.kind, card.cost, card.atk || 0, card.hp || 0, card.effect, card.power];
  return crypto.createHash('sha256').update(JSON.stringify(fields)).digest('hex');
}
function diagnose(cards) {
  const groups = new Map();
  for (const card of cards) {
    const fingerprint = signature(card);
    if (!groups.has(fingerprint)) groups.set(fingerprint, []);
    groups.get(fingerprint).push(card.id);
  }
  const duplicates = [...groups.entries()].filter(([, ids]) => ids.length > 1).map(([fingerprint, ids]) => ({fingerprint, card_ids: ids}));
  return {card_count: cards.length, unique_signatures: groups.size, duplicate_groups: duplicates, severity: duplicates.length ? 'warning' : 'none', gameplay_equivalence_claimed: false};
}
function main() {
  const filenames = process.argv.slice(2);
  const paths = filenames.length ? filenames : ['data/alpha/cards.json', 'data/card_system/pilot.json'];
  const pools = paths.map(filename => {
    const document = JSON.parse(fs.readFileSync(path.resolve(ROOT, filename), 'utf8'));
    const cards = Array.isArray(document) ? document : document.cards;
    if (!Array.isArray(cards)) throw new Error(`Expected a card array: ${filename}`);
    return {name: filename, cards};
  });
  const names = validateNamesAcrossPools(pools);
  console.log(JSON.stringify({signature_scope: 'exact type/cost/stats/effect parameters; excludes name/art/faction; generic V2 includes ability graph and species', catalogues: pools.map(pool => ({file: pool.name, ...diagnose(pool.cards)})), names, duplicate_mechanics_policy: 'diagnostic_warning_only_for_existing_catalogues'}, null, 2));
  process.exitCode = names.ok ? 0 : 1;
}
if (require.main === module) main();
module.exports = {signature, diagnose};
