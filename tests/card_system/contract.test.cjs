'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const {registry, renderText, validateCard, validateCatalogue, validateNamesAcrossPools, hasSpecies, matchingSpecies, mechanicalFingerprint} = require('../../tools/card_system/contract.cjs');
const {inventory} = require('../../tools/card_system/assets.cjs');
const {diagnose} = require('../../tools/card_system/diagnose.cjs');
const {resolveArtAsset} = require('../../tools/card_system/art.cjs');
const ROOT = path.resolve(__dirname, '../..');
const pilot = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/card_system/pilot.json')));
const clone = value => structuredClone(value);
const creature = () => clone(pilot.cards[0]);
const impulse = () => clone(pilot.cards.find(card => card.kind === 'event'));
const relic = () => clone(pilot.cards.find(card => card.kind === 'relic'));
const rejects = (card, pattern) => { const result = validateCard(card); assert.equal(result.ok, false); assert.ok(result.errors.some(error => pattern.test(error)), result.errors.join('\n')); };

test('contract declares exactly three kinds, twelve species/categories, sixteen triggers', () => {
  assert.deepEqual(registry.kinds, {creature: 'Wesen', event: 'Impuls', relic: 'Relikt'});
  assert.equal(Object.keys(registry.species).length, 12);
  assert.equal(Object.keys(registry.categories).length, 12);
  assert.equal(Object.keys(registry.triggers).length, 16);
  assert.ok(Object.values(registry.triggers).every(trigger => trigger.generic_runtime_implemented === false));
  for (const effect of Object.values(registry.effects)) {
    assert.equal(effect.implemented, false, 'registry must not claim generic runtime hooks');
    assert.ok(Object.hasOwn(registry.categories, effect.category));
    if (effect.reference_implemented) assert.ok(fs.existsSync(path.join(ROOT, effect.source_binding.path)));
  }
});

test('eight authored source-backed pilots validate without a runtime-playability claim', () => {
  assert.equal(pilot.cards.length, 8);
  const result = validateCatalogue(pilot.cards);
  assert.deepEqual(result.errors, []);
  assert.equal(result.runtime_playable, 0);
  for (const card of pilot.cards) {
    const before = JSON.stringify(card);
    assert.deepEqual(validateCard(card), {ok: true, errors: [], reference_supported: true, runtime_playable: false});
    assert.equal(renderText(card), card.text_de);
    assert.equal(JSON.stringify(card), before, 'validator must not mutate source');
    assert.ok(!card.text_de.includes('{'));
  }
});

test('two species are equal unordered membership and do not double count one unit', () => {
  const card = creature(); card.species = ['human', 'construct'];
  assert.equal(hasSpecies(card, 'human'), true); assert.equal(hasSpecies(card, 'construct'), true);
  assert.deepEqual(matchingSpecies(card, ['construct', 'human', 'construct', 'spirit']), ['construct', 'human']);
  const fingerprint = mechanicalFingerprint(card); card.species.reverse();
  assert.equal(mechanicalFingerprint(card), fingerprint);
  assert.equal(validateCard(card).ok, true);
  assert.equal(hasSpecies(impulse(), 'human'), false);
});

test('each of twelve species is accepted as data without inventing runtime synergy tests', () => {
  for (const species of Object.keys(registry.species)) {
    const card = creature(); delete card.source_binding; card.species = [species];
    const result = validateCard(card);
    assert.equal(result.ok, true, species); assert.equal(result.reference_supported, false); assert.equal(result.runtime_playable, false);
  }
});

test('invalid creature species counts, duplicates and unknown values are rejected', () => {
  for (const species of [[], ['human', 'beast', 'spirit'], ['human', 'human'], ['dragon'], 'human']) {
    const card = creature(); card.species = species; rejects(card, /species/);
  }
});

test('non-creatures reject attack, health and species even with zero stats', () => {
  for (const original of [impulse(), relic()]) for (const [field, value] of [['attack', 0], ['health', 0], ['species', ['human']]]) {
    const card = clone(original); card[field] = value; rejects(card, /forbidden for non-creature/);
  }
});

test('stats and energy are strict finite integers within the isolated safety contract', () => {
  for (const [field, invalid] of [['attack', -1], ['attack', 0.5], ['health', 0], ['energy_cost', 0], ['energy_cost', 11], ['attack', Infinity]]) {
    const card = creature(); card[field] = invalid; rejects(card, /integer/);
  }
  const card = creature(); delete card.health; rejects(card, /health/);
});

test('unknown card types, fields, effects and prototype keys are rejected safely', () => {
  const card = creature(); card.kind = 'anomaly'; rejects(card, /kind/);
  card.kind = 'creature'; card.cost = 2; rejects(card, /unknown field/);
  delete card.cost;
  for (const effect of ['invented_effect', '__proto__', 'constructor', null]) {
    card.abilities[0].effect = effect; rejects(card, /unknown effect/);
  }
  for (const malformed of [null, [], 'card', 12]) assert.equal(validateCard(malformed).ok, false);
});

test('unknown, missing, negative, fractional and excessive effect parameters are rejected', () => {
  for (const params of [{}, {amount: -1}, {amount: 1.2}, {amount: 31}, {amount: 3, invented: 1}, null]) {
    const card = creature(); card.abilities[0].params = params; rejects(card, /params/);
  }
});

test('known effects cannot be attached to unsupported triggers, modes, kinds or targets', () => {
  for (const [field, invalid] of [['trigger', 'on_attack'], ['trigger', 'before_anything'], ['target', 'enemy_hero'], ['mode', 'reactive'], ['limit', 'unlimited']]) {
    const card = creature(); card.abilities[0][field] = invalid; rejects(card, new RegExp(field));
  }
  const card = impulse(); card.abilities[0] = clone(creature().abilities[0]); rejects(card, /kind/);
});

test('manual rules text cannot drift from generated effect parameters', () => {
  const card = creature(); card.text_de = 'Beim Beschwören: Dein Held erhält 300 Block.'; rejects(card, /text_de/);
  card.text_de = ''; rejects(card, /text_de/);
});

test('original identity, values and effect parameters are verified against actual alpha data', () => {
  for (const mutate of [card => card.energy_cost++, card => card.attack++, card => card.source_binding.power++, card => card.source_binding.card_id = 'changed-card', card => card.abilities[0].params.amount++, card => card.id = 'oa-missing-card']) {
    const card = creature(); mutate(card); rejects(card, /source_binding/);
  }
});

test('activated relic costs and once-per-own-turn limit cannot be silently changed', () => {
  for (const mutate of [card => card.abilities[0].activation.energy = 0, card => card.abilities[0].activation.resonance = 2, card => card.abilities[0].limit = 'unlimited', card => delete card.abilities[0].activation]) {
    const card = relic(); mutate(card); rejects(card, /activation|limit/);
  }
  assert.match(relic().text_de, /^Aktivieren \(1 Energie, einmal je eigenem Zug\):/u);
});

test('printed resonance costs remain explicitly unsupported until runtime integration', () => {
  const card = impulse(); card.resonance_cost = 2; rejects(card, /runtime adapter/);
  const being = creature(); being.resonance_cost = 0; rejects(being, /energy only/);
});

test('planned category registry entries do not count as implemented effects', () => {
  const card = impulse(); delete card.source_binding;
  card.abilities = [{mode: 'triggered', trigger: 'on_play', effect: 'summon', target: 'own_free_lane', params: {count: 1}, limit: 'once_per_play'}];
  card.text_de = renderText(card);
  rejects(card, /not implemented/);
  const draft = validateCard(card, {allowPlanned: true});
  assert.equal(draft.ok, true); assert.equal(draft.reference_supported, false); assert.equal(draft.runtime_playable, false);
});

test('vanilla creatures are valid, empty impulses and relics are not', () => {
  const card = creature(); delete card.source_binding; card.abilities = []; card.text_de = '';
  assert.equal(validateCard(card).ok, true);
  for (const original of [impulse(), relic()]) { original.abilities = []; original.text_de = ''; rejects(original, /requires an effect/); }
});

test('catalogue rejects duplicate identities, names and mechanical copies', () => {
  assert.equal(validateCatalogue([...pilot.cards, clone(pilot.cards[0])]).ok, false);
  const card = creature(); delete card.source_binding; card.id = 'oa-test-double'; card.name = 'TORWACHE';
  assert.ok(validateCatalogue([...pilot.cards, card]).errors.some(error => /duplicate name/.test(error)));
  card.name = 'Andere Torwache';
  assert.ok(validateCatalogue([...pilot.cards, card]).errors.some(error => /duplicate mechanics/.test(error)));
});

test('pilot must not be mistaken for a complete 110-per-power release', () => {
  const result = validateCatalogue(pilot.cards, {expectedPerPower: 110});
  assert.equal(result.ok, false); assert.equal(result.count, 8); assert.equal(result.errors.filter(error => /expected 110/.test(error)).length, 5);
});

test('portable JSON Schema stays synchronized with the authored registry', () => {
  const result = spawnSync(process.execPath, ['tools/card_system/schema.cjs', '--check'], {cwd: ROOT, encoding: 'utf8'});
  assert.equal(result.status, 0, result.stderr);
});

test('pierce terminology follows real kernel semantics instead of the old tooltip', () => {
  assert.match(registry.effects.pierce.text_de, /Block und Schild umgeht/u);
  assert.match(registry.effects.pierce.text_de, /dabei absorbieren Block und Schild/u);
});

test('historical eight-pilot inventory reports real file presence without automatically approving production art', () => {
  const manifest = inventory();
  assert.equal(manifest.inventory_card_count, 8);
  assert.equal(manifest.entries.length, 8);
  assert.equal(manifest.shared_concept_card_count, 8);
  const missing = pilot.cards.filter(card => !fs.existsSync(path.join(ROOT, 'assets/cards/originals',card.id+'.png'))).length;
  assert.equal(manifest.missing_individual_original_count, missing);
  assert.equal(manifest.final_individual_original_count, 0);
  assert.equal(manifest.future_plan.generated_future_card_rows, 0);
  assert.equal(manifest.future_plan.desired_catalogue_cards, 550);
  assert.equal(manifest.atlas.width, 1245); assert.equal(manifest.atlas.height, 1263);
  assert.equal(manifest.atlas.cell_width, 415); assert.equal(manifest.atlas.cell_height, 421);
  for (const entry of manifest.entries) {
    assert.ok(pilot.cards.some(card => card.id === entry.card_id));
    const expectedPath=path.posix.join('assets/cards/originals',entry.card_id+'.png');
    assert.equal(entry.individual_original.expected_path,expectedPath);
    const exists=fs.existsSync(path.join(ROOT,expectedPath));
    assert.equal(entry.individual_original.exists,exists);
    assert.equal(entry.individual_original.status,exists?'unreviewed':'missing','file presence cannot promote the historical pilot mapping');
    assert.equal(entry.individual_original.commercially_cleared, false);
    assert.equal(fs.existsSync(path.join(ROOT, entry.shared_reference.path)), true);
  }
});

test('generated illustration inventory is reproducible and detects stale atlas or pilot references', () => {
  const result = spawnSync(process.execPath, ['tools/card_system/assets.cjs', '--check'], {cwd: ROOT, encoding: 'utf8'});
  assert.equal(result.status, 0, result.stderr);
  const saved = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/card_system/illustration_manifest.json'), 'utf8'));
  assert.deepEqual(saved, inventory());
});

test('diagnostic reports actual 43/55 cost-stat-effect signatures as warnings only', () => {
  const source = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/alpha/cards.json'), 'utf8'));
  const result = diagnose(source.cards);
  assert.equal(result.card_count, 55); assert.equal(result.unique_signatures, 43);
  assert.equal(result.duplicate_groups.length, 10);
  assert.equal(result.severity, 'warning'); assert.equal(result.gameplay_equivalence_claimed, false);
  const card = clone(source.cards[0]); card.id = 'oa-test-distinct'; card.atk++;
  assert.equal(diagnose([source.cards[0], card]).unique_signatures, 2, 'stat variants are not falsely diagnosed as exact copies');
});

test('display names are unique across different power pools while original identity views remain legal', () => {
  const alpha = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/alpha/cards.json'), 'utf8'));
  const valid = validateNamesAcrossPools([{name: 'alpha', cards: alpha.cards}, {name: 'v2-pilot', cards: pilot.cards}]);
  assert.equal(valid.ok, true); assert.equal(valid.unique_card_ids, 55); assert.equal(valid.repeated_identity_views, 8);
  const card = creature(); delete card.source_binding; card.id = 'oa-stillwatch-torwache'; card.power = 'stillwatch'; card.name = 'TORWACHE';
  const conflict = validateNamesAcrossPools([{name: 'old', cards: alpha.cards}, {name: 'new', cards: [card]}]);
  assert.equal(conflict.ok, false); assert.match(conflict.errors[0], /Duplicate name across pools/u);
  card.name = 'To\u0072wache';
  assert.equal(validateNamesAcrossPools([{name: 'old', cards: alpha.cards}, {name: 'new', cards: [card]}]).ok, false);
});

test('individual concept and final IDs require a real safe image file; file checks grant no artistic approval', () => {
  for (const status of ['concept', 'final']) {
    const card = creature();
    card.art = {status, asset_id: 'res://assets/art/arena_painted.png', provenance: 'Test of existing-file resolution only; no claim of a final card illustration.'};
    assert.equal(validateCard(card).ok, true);
    card.art.asset_id = 'res://assets/art/nonexistent-card.png'; rejects(card, /asset_file_missing/);
    card.art.asset_id = 'arbitrary-unregistered-id'; rejects(card, /requires_res_assets_path/);
    card.art.asset_id = 'missing:uncreated-card'; rejects(card, /requires_res_assets_path/);
    card.art.asset_id = 'res://scripts/alpha/model.gd'; rejects(card, /requires_res_assets_path/);
  }
});

test('shared concepts cannot be relabelled final or hidden behind an atlas file path', () => {
  for (const status of ['concept', 'final']) for (const id of ['shared:orafold-atlas', 'res://assets/art/atlas.png']) {
    const card = creature(); card.art.status = status; card.art.asset_id = id; rejects(card, /requires_res_assets_path|shared_atlas_requires/);
  }
  const card = creature(); card.art.asset_id = 'shared:unknown-atlas'; rejects(card, /unknown_shared_asset/);
  card.art = {status: 'missing', asset_id: 'missing:uncreated-card', provenance: 'No image created.'};
  assert.equal(validateCard(card).ok, true);
  card.art.asset_id = 'res://assets/art/arena_painted.png'; rejects(card, /missing_status_requires/);
});

test('art resolver rejects traversal, symlink escape, directories and disguised non-images', () => {
  for (const id of ['res://assets/../assets/art/arena_painted.png', 'res://assets/art/../../data/alpha/cards.json', 'res://assets/art/%2e%2e/arena.png', 'res://assets\\art\\arena.png', 'res://assets//art/arena.png', 'res://assets/art/arena_painted.png?version=1']) {
    assert.equal(resolveArtAsset({status: 'final', asset_id: id}).ok, false, id);
  }
  const temporary = fs.mkdtempSync(path.join(require('node:os').tmpdir(), 'orafold-art-test-'));
  try {
    fs.mkdirSync(path.join(temporary, 'assets'));
    fs.copyFileSync(path.join(ROOT, 'assets/art/arena.svg'), path.join(temporary, 'outside.svg'));
    fs.symlinkSync(path.join(temporary, 'outside.svg'), path.join(temporary, 'assets/escape.svg'));
    assert.equal(resolveArtAsset({status: 'final', asset_id: 'res://assets/escape.svg'}, {root: temporary}).reason, 'asset_symlink_escape');
    fs.mkdirSync(path.join(temporary, 'assets/directory.png'));
    assert.equal(resolveArtAsset({status: 'concept', asset_id: 'res://assets/directory.png'}, {root: temporary}).reason, 'asset_is_not_regular_file');
    fs.writeFileSync(path.join(temporary, 'assets/fake.png'), 'This file is plain text, not a PNG image.');
    assert.equal(resolveArtAsset({status: 'final', asset_id: 'res://assets/fake.png'}, {root: temporary}).reason, 'file_does_not_match_image_format');
    fs.unlinkSync(path.join(temporary, 'assets/escape.svg'));
    fs.rmSync(path.join(temporary, 'assets'), {recursive: true});
    fs.mkdirSync(path.join(temporary, 'elsewhere'));
    fs.copyFileSync(path.join(ROOT, 'assets/art/arena.svg'), path.join(temporary, 'elsewhere/borrowed.svg'));
    fs.symlinkSync(path.join(temporary, 'elsewhere'), path.join(temporary, 'assets'));
    assert.equal(resolveArtAsset({status: 'final', asset_id: 'res://assets/borrowed.svg'}, {root: temporary}).reason, 'asset_root_symlink_redirect');
  } finally { fs.rmSync(temporary, {recursive: true, force: true}); }
});
