#!/usr/bin/env node
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const {validateCatalogue, validateNamesAcrossPools} = require('./contract.cjs');
const args = process.argv.slice(2);
const filename = args.find(argument => !argument.startsWith('--')) || path.resolve(__dirname, '../../data/card_system/pilot.json');
for (const flag of args.filter(argument => argument.startsWith('--'))) {
  if (flag !== '--complete') throw new Error(`Unknown option: ${flag}`);
}
const document = JSON.parse(fs.readFileSync(filename, 'utf8'));
const result = validateCatalogue(document.cards, args.includes('--complete') ? {expectedPerPower: 110} : {});
const source = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../../data/alpha/cards.json'), 'utf8'));
const names = validateNamesAcrossPools([{name: 'active-alpha', cards: source.cards}, {name: filename, cards: Array.isArray(document.cards) ? document.cards : []}]);
const combined = {...result, ok: result.ok && names.ok, errors: [...result.errors, ...names.errors], names};
console.log(JSON.stringify({file: filename, ...combined}, null, 2));
process.exitCode = combined.ok ? 0 : 1;
