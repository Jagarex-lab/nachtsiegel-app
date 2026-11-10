'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const {descriptionFor, validateTexts, withGeneratedTexts, HANDLERS} = require('../tools/alpha_card_texts.cjs');
const DATA_PATH = 'data/alpha/cards.json';
const data = JSON.parse(fs.readFileSync(DATA_PATH, 'utf8'));
const byId = Object.fromEntries(data.cards.map(card => [card.id, card]));

// Recorded directly from git show 5d37cd937d7fcc50912a565e96f3cc4aa87f506d:data/alpha/cards.json.
// Only each card's description is excluded. Top-level metadata, names, stable
// identities, every numeric/rules field, card order, and starter order are bound.
// A digest allows a shallow CI checkout to verify the same reference without
// network access or silently treating an unavailable baseline as a passing skip.
const BASELINE_COMMIT = '5d37cd937d7fcc50912a565e96f3cc4aa87f506d';
const BASELINE_WITHOUT_DESCRIPTIONS_SHA256 = 'd10ad5a7dbd7bb3fcb45fc5b7fb19e4639e9eff9a136c394952edc0912859183';
function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(k => [k, canonical(value[k])]));
  return value;
}
function rulesPayload(value) {
  const clone = structuredClone(value);
  for (const card of clone.cards) delete card.description;
  return clone;
}
function digest(value) { return crypto.createHash('sha256').update(JSON.stringify(canonical(value))).digest('hex'); }

test('all non-description fields match integrated develop baseline ' + BASELINE_COMMIT, () => {
  assert.equal(digest(rulesPayload(data)), BASELINE_WITHOUT_DESCRIPTIONS_SHA256);
  assert.equal(data.cards.length, 55);
  assert.equal(new Set(data.cards.map(c => c.id)).size, 55);
});

test('all 55 actual texts are generated, trigger-first, and cover all 29 implemented handlers', () => {
  assert.deepEqual(validateTexts(data), []);
  const coverage = Object.fromEntries(Object.keys(HANDLERS).map(kind => [kind, new Set()]));
  for (const card of data.cards) {
    coverage[card.kind].add(card.effect);
    assert.equal(card.description, descriptionFor(card), card.id);
    assert(card.description.length <= 320, card.id);
    assert(!/Ankunft:|Beim Tod:|\b(?:TODO|Platzhalter|undefined|NaN)\b/.test(card.description), card.id);
  }
  for (const kind of Object.keys(HANDLERS)) assert.deepEqual([...coverage[kind]].sort(), Object.keys(HANDLERS[kind]).sort());
});

test('text generation changes descriptions only and is idempotent', () => {
  const input = structuredClone(data);
  for (const card of input.cards) card.description = 'alter Text';
  const copy = structuredClone(input);
  const output = withGeneratedTexts(input);
  assert.deepEqual(input, copy, 'caller data must remain untouched');
  assert.deepEqual(rulesPayload(output), rulesPayload(input));
  assert.deepEqual(output, withGeneratedTexts(output));
  assert.deepEqual(output, data);
});

test('validation rejects every stale card text and unknown or malformed runtime effects', () => {
  for (const card of data.cards) {
    const wrong = structuredClone(card); wrong.description += ' Nicht implementierter Bonus.';
    assert.equal(validateTexts({cards: [wrong]}).length, 1, card.id);
  }
  for (const card of [
    {id: 'unknown-type', kind: 'anomaly', effect: 'bolt', power: 1},
    {id: 'unknown-effect', kind: 'event', effect: 'unimplemented', power: 1},
    {id: 'wrong-type', kind: 'relic', effect: 'strike', power: 1},
    {id: 'fraction', kind: 'creature', effect: 'ward', power: .5},
    {id: 'negative', kind: 'creature', effect: 'ward', power: -1},
    {id: 'nan', kind: 'event', effect: 'bolt', power: NaN},
    {id: 'infinity', kind: 'event', effect: 'bolt', power: Infinity},
  ]) {
    assert.throws(() => descriptionFor(card), undefined, card.id);
    assert.equal(validateTexts({cards: [card]}).length, 1, card.id);
  }
  assert.throws(() => descriptionFor(null));
  assert.deepEqual(validateTexts({}), ['Kartenliste fehlt.']);
});

test('numeric texts bind source offsets and the exact recipient, not only printed card power', () => {
  const samples = [
    ['creature', 'strike', 4, '5 Schaden'],
    ['creature', 'guard', 4, 'Dein Held erhält 6 Block'],
    ['creature', 'ward', 4, 'Dein Held erhält 5 Schild, höchstens 25'],
    ['creature', 'mend', 4, 'Helden um 6 Leben'],
    ['creature', 'weave', 4, 'Erzeuge 5 Resonanz'],
    ['creature', 'drain', 4, 'Helden 5 Schaden'],
    ['creature', 'rally', 4, '+4 Angriff'],
    ['creature', 'harvest', 4, 'Erzeuge 5 Resonanz'],
    ['creature', 'retaliate', 4, 'Angreifer 4 Schaden'],
    ['creature', 'weaken', 4, 'Angriffsphase um 4, mindestens auf 0'],
    ['creature', 'pulse', 4, 'Erzeuge 4 Resonanz. Dein Held erhält 4 Schild.'],
    ['event', 'bolt', 4, 'Pfad 4 Schaden'],
    ['event', 'heal', 4, 'Helden um 4 Leben'],
    ['event', 'stasis', 4, 'mindestens 4 gegnerische Angriffsphasen'],
    ['event', 'delay', 4, 'nach 2 Zugwechseln'],
    ['event', 'cascade', 4, 'nacheinander 4-mal je 1 Schaden'],
  ];
  for (const [kind, effect, power, expected] of samples) assert(descriptionFor({kind, effect, power}).includes(expected), effect);
  assert.match(descriptionFor({kind:'creature', effect:'pulse', power:4}), /Beide eigenen Nachbarwesen erhalten \+1 Angriff/);
  assert.match(byId['oa-houses-c03'].description, /verursachten Lebensverlust/);
});

test('fixed runtime constants stay fixed even when unused power metadata is different', () => {
  for (const [kind, effect, expected] of [
    ['creature', 'draw', 'Ziehe 1 Karte'],
    ['creature', 'silence', 'mindestens 1 gegnerische Angriffsphase'],
    ['event', 'surge', '1 zusätzlichen Angriff'],
    ['relic', 'relic_res', 'Erzeuge 1 Resonanz'],
    ['relic', 'relic_ward', 'Dein Held erhält 2 Schild'],
    ['relic', 'relic_heal', 'Helden um 2 Leben'],
    ['relic', 'relic_draw', 'Ziehe 1 Karte'],
  ]) {
    const text = descriptionFor({kind, effect, power: 9});
    assert(text.includes(expected), effect);
    assert(!text.includes('9'), effect);
  }
});

test('pierce distinguishes unprotected arrival from protected combat overflow', () => {
  const text = descriptionFor({kind: 'creature', effect: 'pierce', power: 2});
  assert.equal(text,
    'Beim Beschwören: Füge dem gegnerischen Helden 4 Schaden zu. Dieser Schaden ignoriert Block und Schild.\n' +
    'Beim Angreifen: Überzähliger Schaden gegen ein besiegtes Wesen trifft den gegnerischen Helden. Block und Schild wirken gegen diesen Schaden.');
  const style = fs.readFileSync('scripts/alpha/style.gd', 'utf8');
  assert(!style.includes('aber nicht Block'));
  assert.match(style, /Beschwörungstreffer ignoriert Block und Schild/);
  assert.match(style, /Überzähliger Schaden beim Angreifen trifft den Helden durch dessen Block und Schild/);
});

test('nontrivial targets, shielded retaliation, delayed timing and draw bounds are explicit', () => {
  const get = effect => data.cards.find(c => c.effect === effect).description;
  assert.match(get('retaliate'), /Überlebt dieses Wesen.*mindestens 1 Schadenspunkt vor Schild/);
  assert.match(get('recall'), /zuletzt abgelegte Wesen aus deiner Ablage.*freien eigenen Pfad/);
  assert.match(get('recall'), /Beschwörungseffekte werden erneut ausgelöst/);
  assert.match(get('delay'), /nach 2 Zugwechseln/);
  assert.match(get('delay'), /Pfad dann leer.*gegnerischen Helden/);
  assert.match(get('redirect'), /ältesten verzögerten Treffer.*Zeitpunkt bleibt gleich/);
  assert.match(get('displace'), /freien linken Nachbarpfad, sonst.*freien rechten/);
  assert.match(get('draw'), /6 Handkarten oder leerem Nachziehstapel/);
  assert.match(get('stasis'), /mindestens 2 gegnerische Angriffsphasen/);
  assert.match(get('rally'), /linke eigene.*Fehlt dort.*rechte eigene/);
  for (const card of data.cards.filter(c => c.kind === 'relic')) {
    assert.match(card.description, /^Beim Aktivieren für 1 Energie:/);
    assert.match(card.description, /Nur 1 Reliktaktivierung je eigenem Zug\./);
  }
});

test('central type labels and glossary preserve three IDs, source protection order and relic replacement rule', () => {
  const style = fs.readFileSync('scripts/alpha/style.gd', 'utf8');
  assert.match(style, /const KINDS=\{"creature":"Wesen","event":"Impuls","relic":"Relikt"\}/);
  assert.match(style, /zuerst Block, dann Schild, dann Leben/);
  assert.match(style, /Ersetzen erneuert diese Möglichkeit nicht/);
  assert.match(style, /Vollständige Schildabsorption verhindert den Gegenschaden nicht/);
  assert.match(style, /Effekte lösen selbst keinen Kreislauf und keine Erschöpfung aus/);
});

test('read-only CLI check validates the actual file and rejects unknown invocation', () => {
  const before = fs.readFileSync(DATA_PATH);
  assert.match(execFileSync(process.execPath, ['tools/alpha_card_texts.cjs', '--check'], {encoding: 'utf8'}), /55 geprüfte Texte/);
  assert.deepEqual(fs.readFileSync(DATA_PATH), before);
  assert.throws(() => execFileSync(process.execPath, ['tools/alpha_card_texts.cjs', '--unknown'], {stdio: 'pipe'}));
});
