#!/usr/bin/env node
'use strict';
// Portable JSON Schema is generated from the same registry as the strict checker.
const fs = require('node:fs');
const path = require('node:path');
const {registry} = require('./contract.cjs');
const output = path.resolve(__dirname, '../../data/card_system/schema.json');
const integer = (minimum, maximum) => ({type: 'integer', minimum, maximum});
const text = maxLength => ({type: 'string', minLength: 1, maxLength});
const ability = (id, effect) => {
  const properties = {
    mode: {enum: effect.modes}, effect: {const: id}, target: {enum: effect.targets}, limit: {enum: effect.limits},
    params: {type: 'object', additionalProperties: false, required: Object.keys(effect.params), properties: Object.fromEntries(Object.entries(effect.params).map(([key, rule]) => [key, integer(rule.min, rule.max)]))},
  };
  const required = ['mode', 'effect', 'target', 'params', 'limit'];
  if (effect.triggers.length) { properties.trigger = {enum: effect.triggers}; required.push('trigger'); }
  if (effect.activation) {
    properties.activation = {type: 'object', additionalProperties: false, required: ['energy', 'resonance'], properties: {energy: {const: effect.activation.energy}, resonance: {const: effect.activation.resonance}}};
    required.push('activation');
  }
  return {type: 'object', additionalProperties: false, required, properties};
};
const schema = {
  $schema: 'https://json-schema.org/draft/2020-12/schema',
  $id: 'urn:orafold:card-system:2',
  title: 'ORAFOLD V2 isolated card data contract',
  description: 'Structural validation only. Runtime support and original source bindings require tools/card_system/validate.cjs. Planned registry effects are not playable.',
  type: 'object', additionalProperties: false,
  required: ['schema_version', 'id', 'name', 'power', 'kind', 'rarity', 'energy_cost', 'art', 'abilities', 'text_de'],
  properties: {
    schema_version: {const: 2}, id: {type: 'string', pattern: '^[a-z][a-z0-9]*(?:-[a-z0-9]+)+$'}, name: text(64),
    power: {enum: registry.powers}, kind: {enum: Object.keys(registry.kinds)}, rarity: {enum: registry.rarities},
    energy_cost: integer(0, 10), resonance_cost: integer(0, 15), attack: integer(0, 30), health: integer(1, 40),
    species: {type: 'array', minItems: 1, maxItems: 2, uniqueItems: true, items: {enum: Object.keys(registry.species)}},
    art: {type: 'object', additionalProperties: false, required: ['status', 'asset_id', 'provenance'], properties: {status: {enum: ['missing', 'shared_concept', 'concept', 'final']}, asset_id: text(120), provenance: text(240)}, allOf: [
      {if: {properties: {status: {const: 'missing'}}}, then: {properties: {asset_id: {pattern: '^missing:[a-z][a-z0-9-]+$'}}}},
      {if: {properties: {status: {const: 'shared_concept'}}}, then: {properties: {asset_id: {const: 'shared:orafold-atlas'}}}},
      {if: {properties: {status: {enum: ['concept', 'final']}}}, then: {properties: {asset_id: {pattern: '^res://assets/.+\\.([pP][nN][gG]|[jJ][pP][eE]?[gG]|[wW][eE][bB][pP]|[sS][vV][gG])$'}}}},
    ]},
    abilities: {type: 'array', maxItems: 16, items: {oneOf: Object.entries(registry.effects).map(([id, effect]) => ability(id, effect))}},
    text_de: {type: 'string'}, lore_key: text(120),
    source_binding: {type: 'object', additionalProperties: false, required: ['catalog', 'card_id', 'effect', 'power'], properties: {catalog: {const: 'orafold-alpha-0.1'}, card_id: text(120), effect: {enum: Object.keys(registry.effects)}, power: integer(0, 100)}},
  },
  allOf: [
    {if: {properties: {kind: {const: 'creature'}}}, then: {required: ['attack', 'health', 'species'], properties: {energy_cost: integer(1, 10)}, not: {required: ['resonance_cost']}}, else: {not: {anyOf: ['attack', 'health', 'species'].map(key => ({required: [key]}))}, properties: {abilities: {minItems: 1}}}},
  ],
};
const expected = JSON.stringify(schema, null, 2) + '\n';
if (process.argv.includes('--check')) {
  if (!fs.existsSync(output) || fs.readFileSync(output, 'utf8') !== expected) { console.error('Card schema is stale. Run node tools/card_system/schema.cjs'); process.exitCode = 1; }
} else fs.writeFileSync(output, expected);
module.exports = {schema};
