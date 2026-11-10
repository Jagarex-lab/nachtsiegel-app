'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const {analyze, loadRepository, renderMarkdown} = require('../../tools/production/catalog_review.cjs');

const root = path.resolve(__dirname, '../..');
const baseline = loadRepository(root);
const changed = mutate => { const data = structuredClone(baseline); mutate(data); return analyze(data); };
const hasError = (report, code) => report.structure.errors.some(error => error.code === code);

test('actual proposal catalogue has exact requested counts and valid references', () => {
  const report = analyze(baseline);
  assert.equal(report.structure.valid, true);
  assert.deepEqual(report.counts.affiliations, {'Zwölf Häuser': 110, Stillwacht: 110, Vielgestalt: 110, 'Neunte Stunde': 110, Neutral: 110});
  assert.deepEqual(report.counts.card_types, {Wesen: 350, Impuls: 125, Relikt: 75});
  assert.equal(Object.keys(report.counts.creatures_by_species).length, 12);
  assert.deepEqual(report.counts.creatures_by_species_count, {1: 350});
  assert.equal(report.counts.active_alpha_cards, 55);
  assert.deepEqual(report.counts.concept_ids_also_in_alpha, []);
});

test('complete proposal source is not reported as an implemented or balanced catalogue', () => {
  const report = analyze(baseline);
  assert.equal(report.gameplay_data.missing_fields.energy_cost.count, 550);
  assert.equal(report.gameplay_data.missing_fields.attack.count, 350);
  assert.equal(report.gameplay_data.candidate_definitions_with_all_fields_present, 0);
  assert.equal(report.gameplay_data.runtime_verified_cards, null);
  assert.equal(report.gameplay_data.individual_illustrations_verified, null);
  assert.equal(report.gameplay_data.balance_simulated_matches, 0);
  assert.equal(report.gameplay_data.release_ready, false);
  assert.equal(report.counts.lore_status.VORSCHLAG, 550);
});

test('presence of every gameplay field still grants no runtime or release claim', () => {
  const report = changed(data => {
    for (const row of data.cards) Object.assign(row, {energy_cost: 1, abilities: [], text_de: 'Test', art: {status: 'final'}, attack: 1, health: 1});
  });
  assert.equal(report.gameplay_data.candidate_definitions_with_all_fields_present, 550);
  assert.equal(report.gameplay_data.release_ready, false);
  assert.equal(report.gameplay_data.runtime_verified_cards, null);
  assert.ok(report.gameplay_data.release_blockers.includes('runtime_execution_not_verified_by_static_review'));
});

test('technical uniqueness is distinguished from reused writing', () => {
  const report = analyze(baseline);
  assert.equal(report.editorial.names_with_technical_id_suffix.count, 20);
  assert.equal(report.editorial.repetition.flavor.distinct_values, 15);
  assert.equal(report.editorial.repetition.flavor.cards_in_duplicate_groups, 550);
  assert.equal(report.editorial.repetition.art_direction.distinct_values, 109);
  assert.equal(report.editorial.repetition.lore_without_card_name.distinct_values, 133);
});

test('cross-affiliation and cross-region character links stay review observations', () => {
  const report = analyze(baseline);
  assert.equal(report.references.character_affiliation_differs.count, 394);
  assert.equal(report.references.character_region_differs.count, 438);
  assert.equal(report.structure.valid, true);
});

test('duplicate IDs and Unicode/case/spacing-normalized duplicate names fail', () => {
  const report = changed(data => {
    data.cards[1].id = data.cards[0].id;
    data.cards[1].name = ` ${data.cards[0].name.toUpperCase()}  `;
  });
  assert.ok(hasError(report, 'duplicate_card_id'));
  assert.ok(hasError(report, 'duplicate_normalized_name'));
});

test('missing references, false region and false family/organization affiliations fail', () => {
  const report = changed(data => {
    data.cards[0].character_id = 'CHAR-MISSING';
    data.cards[0].location_id = data.locations.find(row => row.region !== data.cards[0].region).id;
    data.cards[0].family_id = data.families.find(row => row.affiliation !== data.cards[0].affiliation).id;
    data.cards[0].organization = data.organizations.find(row => row.power !== data.cards[0].affiliation).name;
  });
  for (const code of ['missing_reference', 'location_region_mismatch', 'family_affiliation_mismatch', 'organization_affiliation_mismatch']) assert.ok(hasError(report, code), code);
});

test('no fourth type, thirteenth species, duplicate species, or species on an Impuls', () => {
  for (const mutate of [
    data => { data.cards[0].card_type = 'Held'; },
    data => { data.cards[0].species = ['Echo']; },
    data => { data.cards[0].species = ['Menschen', 'Menschen']; },
    data => { data.cards[0].species = []; },
    data => { data.cards[0].species = ['Menschen', 'Bestien', 'Geister']; },
    data => { data.cards.find(row => row.card_type === 'Impuls').species = ['Menschen']; }
  ]) assert.equal(changed(mutate).structure.valid, false);
  const twoSpecies = changed(data => { data.cards[0].species = ['Menschen', 'Konstrukte']; });
  assert.equal(twoSpecies.structure.valid, true);
});

test('missing records, empty required fields, wrong total and bad classifications fail', () => {
  assert.throws(() => analyze({...baseline, cards: null}), /must be an array/u);
  assert.ok(hasError(changed(data => { data.cards[0] = null; }), 'invalid_card_record'));
  assert.ok(hasError(changed(data => { data.cards[0].lore = ' '; }), 'missing_editorial_field'));
  assert.ok(hasError(changed(data => { data.cards.pop(); }), 'wrong_total'));
  assert.ok(hasError(changed(data => { data.cards[0].affiliation = 'Neue Macht'; }), 'invalid_affiliation'));
  assert.ok(hasError(changed(data => { data.cards[0].rarity = 'Mythisch'; }), 'invalid_rarity'));
  assert.ok(hasError(changed(data => { data.cards[0].status = 'FREIGEGEBEN'; }), 'invalid_lore_status'));
  assert.ok(hasError(changed(data => { delete data.cards[0].prototype_only; }), 'missing_prototype_flag'));
});

test('reference ID collisions and malformed reference entries fail', () => {
  assert.ok(hasError(changed(data => { data.characters.push({...data.characters[0]}); }), 'duplicate_reference_id'));
  assert.ok(hasError(changed(data => { data.locations.push(null); }), 'invalid_reference_record'));
});

test('analysis is deterministic and leaves source data unchanged', () => {
  const before = JSON.stringify(baseline);
  assert.deepEqual(analyze(baseline), analyze(baseline));
  assert.equal(JSON.stringify(baseline), before);
  assert.match(renderMarkdown(analyze(baseline)), /Releasefreigabe: \*\*nein\*\*/u);
  assert.match(renderMarkdown(analyze(baseline)), /b7e6bfd396bf899d/u);
});

test('CLI uses meaningful exit codes and never writes the source files', () => {
  const script = path.join(root, 'tools/production/catalog_review.cjs');
  const source = path.join(root, 'data/lore/card-concepts.json');
  const before = fs.readFileSync(source);
  for (const [args, expected] of [[['--check'], 0], [['--require-release'], 1], [['--format', 'yaml'], 2], [['--unknown'], 2]]) {
    const result = spawnSync(process.execPath, [script, ...args], {cwd: root, encoding: 'utf8'});
    assert.equal(result.status, expected, result.stderr);
  }
  assert.deepEqual(fs.readFileSync(source), before);
});
