'use strict';

// Data contract only. This module never executes combat or claims runtime support.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const ROOT = path.resolve(__dirname, '../..');
const registry = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/card_system/registry.json'), 'utf8'));
const sourceCards = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/alpha/cards.json'), 'utf8')).cards;
const own = (value, key) => Object.prototype.hasOwnProperty.call(value, key);
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const sorted = value => Array.isArray(value) ? value.map(sorted) : object(value)
  ? Object.fromEntries(Object.keys(value).sort().map(key => [key, sorted(value[key])])) : value;
const normalizeName = name => name.normalize('NFKC').trim().replace(/\s+/gu, ' ').toLocaleLowerCase('de-DE');

function keys(value, allowed, required, location, errors) {
  if (!object(value)) { errors.push(`${location}: object required`); return false; }
  for (const key of Object.keys(value)) if (!allowed.includes(key)) errors.push(`${location}.${key}: unknown field`);
  for (const key of required) if (!own(value, key)) errors.push(`${location}.${key}: required`);
  return true;
}
function integer(value, minimum, maximum, location, errors) {
  if (!Number.isSafeInteger(value) || value < minimum || value > maximum) errors.push(`${location}: integer ${minimum}..${maximum} required`);
}
function member(value, values, location, errors) {
  if (!values.includes(value)) errors.push(`${location}: unknown value ${String(value)}`);
}
function nonempty(value, maximum, location, errors) {
  if (typeof value !== 'string' || value.trim() !== value || !value.length || value.length > maximum || /[\u0000-\u001f]/u.test(value)) errors.push(`${location}: nonempty trimmed text, maximum ${maximum} characters required`);
}
function validateAbility(ability, kind, index, errors, options) {
  const location = `abilities[${index}]`;
  if (!keys(ability, ['mode', 'trigger', 'effect', 'target', 'params', 'activation', 'limit'], ['mode', 'effect', 'target', 'params', 'limit'], location, errors)) return;
  member(ability.mode, registry.ability_modes, `${location}.mode`, errors);
  const effect = typeof ability.effect === 'string' && own(registry.effects, ability.effect) ? registry.effects[ability.effect] : null;
  if (!effect) { errors.push(`${location}.effect: unknown effect ${String(ability.effect)}`); return; }
  member(kind, effect.kinds, `${location}.kind`, errors);
  member(ability.mode, effect.modes, `${location}.mode`, errors);
  member(ability.target, effect.targets, `${location}.target`, errors);
  member(ability.limit, effect.limits, `${location}.limit`, errors);
  if (!effect.reference_implemented && !options.allowPlanned) errors.push(`${location}.effect: not implemented in the reference runtime`);
  if (ability.mode === 'triggered' || ability.mode === 'reactive') {
    member(ability.trigger, Object.keys(registry.triggers), `${location}.trigger`, errors);
    member(ability.trigger, effect.triggers, `${location}.trigger`, errors);
  } else if (own(ability, 'trigger')) errors.push(`${location}.trigger: forbidden for ${ability.mode}`);
  if (keys(ability.params, Object.keys(effect.params), Object.keys(effect.params), `${location}.params`, errors)) {
    for (const [name, rule] of Object.entries(effect.params)) {
      integer(ability.params[name], rule.min, rule.max, `${location}.params.${name}`, errors);
    }
  }
  if (ability.mode === 'activated') {
    if (keys(ability.activation, ['energy', 'resonance'], ['energy', 'resonance'], `${location}.activation`, errors)) {
      integer(ability.activation.energy, 0, 10, `${location}.activation.energy`, errors);
      integer(ability.activation.resonance, 0, 15, `${location}.activation.resonance`, errors);
      if (effect.activation && (ability.activation.energy !== effect.activation.energy || ability.activation.resonance !== effect.activation.resonance)) errors.push(`${location}.activation: differs from implemented reference cost`);
    }
  } else if (own(ability, 'activation')) errors.push(`${location}.activation: forbidden for ${ability.mode}`);
}

function renderAbility(ability) {
  const effect = own(registry.effects, ability.effect) ? registry.effects[ability.effect] : null;
  if (!effect) throw new Error(`Unknown effect: ${ability.effect}`);
  let prefix;
  if (ability.mode === 'passive') prefix = 'Dauerhaft';
  else if (ability.mode === 'activated') {
    const costs = [];
    if (ability.activation.energy) costs.push(`${ability.activation.energy} Energie`);
    if (ability.activation.resonance) costs.push(`${ability.activation.resonance} Resonanz`);
    prefix = `Aktivieren (${costs.length ? costs.join(' und ') : 'kostenlos'}, einmal je eigenem Zug)`;
  } else prefix = registry.triggers[ability.trigger]?.de;
  if (!prefix) throw new Error(`Unknown trigger: ${ability.trigger}`);
  const body = effect.text_de.replace(/\{([a-z_]+)\}/gu, (_, name) => {
    if (!own(ability.params, name)) throw new Error(`Missing parameter: ${name}`);
    return String(ability.params[name]);
  });
  return `${prefix}: ${body}`;
}
function renderText(card) {
  if (!Array.isArray(card.abilities)) throw new Error('abilities must be an array');
  return card.abilities.map(renderAbility).join('\n');
}

function validateCard(card, options = {}) {
  const errors = [];
  const required = ['schema_version', 'id', 'name', 'power', 'kind', 'rarity', 'energy_cost', 'art', 'abilities', 'text_de'];
  if (!keys(card, [...required, 'resonance_cost', 'attack', 'health', 'species', 'source_binding', 'lore_key'], required, 'card', errors)) return {ok: false, errors, runtime_playable: false};
  if (card.schema_version !== 2) errors.push('schema_version: expected 2');
  if (typeof card.id !== 'string' || !/^[a-z][a-z0-9]*(?:-[a-z0-9]+)+$/u.test(card.id)) errors.push('id: stable lowercase hyphenated ID required');
  nonempty(card.name, 64, 'name', errors);
  member(card.power, registry.powers, 'power', errors);
  member(card.kind, Object.keys(registry.kinds), 'kind', errors);
  member(card.rarity, registry.rarities, 'rarity', errors);
  integer(card.energy_cost, 0, 10, 'energy_cost', errors);
  if (own(card, 'resonance_cost')) {
    integer(card.resonance_cost, 0, 15, 'resonance_cost', errors);
    if (card.kind === 'creature') errors.push('resonance_cost: creatures use energy only in this contract');
    if (card.resonance_cost !== 0 && !options.allowPlanned) errors.push('resonance_cost: printed resonance costs require a runtime adapter');
  }
  if (card.kind === 'creature') {
    integer(card.energy_cost, 1, 10, 'energy_cost for creature', errors);
    integer(card.attack, 0, 30, 'attack', errors);
    integer(card.health, 1, 40, 'health', errors);
    if (!Array.isArray(card.species) || card.species.length < 1 || card.species.length > 2) errors.push('species: creatures require one or two species');
    else {
      if (new Set(card.species).size !== card.species.length) errors.push('species: duplicates forbidden');
      for (const species of card.species) member(species, Object.keys(registry.species), 'species', errors);
    }
  } else {
    for (const field of ['attack', 'health', 'species']) if (own(card, field)) errors.push(`${field}: forbidden for non-creature cards`);
  }
  if (keys(card.art, ['status', 'asset_id', 'provenance'], ['status', 'asset_id', 'provenance'], 'art', errors)) {
    member(card.art.status, ['missing', 'shared_concept', 'concept', 'final'], 'art.status', errors);
    nonempty(card.art.asset_id, 120, 'art.asset_id', errors);
    nonempty(card.art.provenance, 240, 'art.provenance', errors);
    if (card.art.status === 'final' && card.art.asset_id.startsWith('missing:')) errors.push('art: missing asset cannot be final');
  }
  if (!Array.isArray(card.abilities) || card.abilities.length > 16) errors.push('abilities: array with at most sixteen abilities required');
  else {
    if (card.kind !== 'creature' && !card.abilities.length) errors.push('abilities: non-creature card requires an effect');
    card.abilities.forEach((ability, i) => validateAbility(ability, card.kind, i, errors, options));
  }
  if (card.source_binding !== undefined && keys(card.source_binding, ['catalog', 'card_id', 'effect', 'power'], ['catalog', 'card_id', 'effect', 'power'], 'source_binding', errors)) {
    if (card.source_binding.catalog !== 'orafold-alpha-0.1') errors.push('source_binding.catalog: unknown catalog');
    if (card.source_binding.card_id !== card.id) errors.push('source_binding.card_id: original identity must remain unchanged');
    if (!own(registry.effects, card.source_binding.effect)) errors.push('source_binding.effect: unknown effect');
    integer(card.source_binding.power, 0, 100, 'source_binding.power', errors);
    const source = sourceCards.find(c => c.id === card.id);
    if (!source) errors.push('source_binding: original card does not exist');
    else {
      for (const [v2, original] of [['power', 'faction'], ['kind', 'kind'], ['rarity', 'rarity'], ['energy_cost', 'cost'], ...(card.kind === 'creature' ? [['attack', 'atk'], ['health', 'hp']] : [])]) {
        if (card[v2] !== source[original]) errors.push(`source_binding: ${v2} differs from original card`);
      }
      if (card.source_binding.effect !== source.effect || card.source_binding.power !== source.power) errors.push('source_binding: effect or power differs from original card');
      if (!Array.isArray(card.abilities) || card.abilities.length !== 1 || card.abilities[0]?.effect !== source.effect) errors.push('source_binding: requires the single original ability');
      else {
        const binding = registry.effects[source.effect]?.source_binding?.parameter_semantics;
        if (binding) for (const [parameter, expression] of Object.entries(binding)) {
          const match = /^(?:power(?: \+ ([0-9]+))?|constant ([0-9]+))$/u.exec(expression);
          const expected = match ? (match[2] === undefined ? source.power + Number(match[1] || 0) : Number(match[2])) : undefined;
          if (expected === undefined || card.abilities[0]?.params?.[parameter] !== expected) errors.push(`source_binding: ${parameter} differs from original effect`);
        }
      }
    }
  }
  if (own(card, 'lore_key')) nonempty(card.lore_key, 120, 'lore_key', errors);
  if (!errors.length) {
    const expected = renderText(card);
    if (card.text_de !== expected) errors.push('text_de: differs from generated effect text');
  }
  return {ok: errors.length === 0, errors, reference_supported: errors.length === 0 && card.source_binding !== undefined && card.abilities.every(a => registry.effects[a.effect].reference_implemented), runtime_playable: false};
}

// A species list is an unordered membership set. Neither entry is primary.
function hasSpecies(card, species) { return card.kind === 'creature' && Array.isArray(card.species) && card.species.includes(species); }
function matchingSpecies(card, query) { return [...new Set(query)].filter(species => hasSpecies(card, species)); }
function mechanicalFingerprint(card) {
  const mechanics = {power: card.power, kind: card.kind, rarity: card.rarity, energy_cost: card.energy_cost, resonance_cost: card.resonance_cost || 0,
    attack: card.attack, health: card.health, species: card.species?.slice().sort(), abilities: card.abilities};
  return crypto.createHash('sha256').update(JSON.stringify(sorted(mechanics))).digest('hex');
}
function validateCatalogue(cards, options = {}) {
  if (!Array.isArray(cards)) return {ok: false, errors: ['catalogue: array required'], count: 0, runtime_playable: 0};
  const errors = [], ids = new Set(), names = new Set(), fingerprints = new Map();
  const counts = Object.fromEntries(registry.powers.map(power => [power, 0]));
  cards.forEach((card, index) => {
    const result = validateCard(card, options);
    errors.push(...result.errors.map(error => `[${index}] ${error}`));
    if (!object(card)) return;
    if (ids.has(card.id)) errors.push(`[${index}] duplicate id: ${card.id}`);
    ids.add(card.id);
    const name = typeof card.name === 'string' ? normalizeName(card.name) : '';
    if (names.has(name)) errors.push(`[${index}] duplicate name: ${card.name}`);
    names.add(name);
    if (own(counts, card.power)) counts[card.power]++;
    if (result.ok) {
      const fingerprint = mechanicalFingerprint(card);
      if (fingerprints.has(fingerprint)) errors.push(`[${index}] duplicate mechanics: ${card.id} / ${fingerprints.get(fingerprint)}`);
      fingerprints.set(fingerprint, card.id);
    }
  });
  if (options.expectedPerPower !== undefined) for (const [power, count] of Object.entries(counts)) if (count !== options.expectedPerPower) errors.push(`${power}: expected ${options.expectedPerPower}, got ${count}`);
  return {ok: errors.length === 0, errors, count: cards.length, counts, runtime_playable: 0};
}

function validateNamesAcrossPools(pools) {
  const names = new Map(), identities = new Set(), errors = [];
  let references = 0;
  for (const pool of pools) for (const card of pool.cards) {
    references++;
    if (typeof card.id !== 'string' || typeof card.name !== 'string') { errors.push(`${pool.name}: missing identity or display name`); continue; }
    identities.add(card.id);
    const key = normalizeName(card.name);
    if (!names.has(key)) names.set(key, {id: card.id, name: card.name, pool: pool.name});
    const previous = names.get(key);
    if (previous.id !== card.id) errors.push(`Duplicate name across pools: ${previous.name} (${previous.pool}:${previous.id}) / ${card.name} (${pool.name}:${card.id})`);
  }
  return {ok: !errors.length, errors, unique_card_ids: identities.size, card_references: references, repeated_identity_views: references - identities.size};
}

module.exports = {registry, renderText, renderAbility, validateCard, validateCatalogue, validateNamesAcrossPools, hasSpecies, matchingSpecies, mechanicalFingerprint};
