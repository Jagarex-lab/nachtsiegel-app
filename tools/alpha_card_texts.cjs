#!/usr/bin/env node
'use strict';

// Presentation-only descriptions of the EXISTING Alpha handlers. This does not
// register abilities, change parameters, or turn descriptive metadata into rules.
// Parameter offsets/constants match legacy/battle_engine.gd::_resolve_summon and
// alpha/model.gd::play/activate_relic. Keep fixed runtime values fixed here too:
// draw/surge and relic handlers do not use the card's `power` as their magnitude.
const fs = require('node:fs');
const path = require('node:path');
const CARD_PATH = path.join(__dirname, '../data/alpha/cards.json');
const TRIGGERS = ['Beim Beschwören:', 'Wenn dieses Wesen besiegt wird:',
  'Beim Verteidigen:', 'Beim Ausspielen:', 'Beim Aktivieren für 1 Energie:'];

const CREATURE = Object.freeze({
  strike: p => `Beim Beschwören: Füge einem gewählten gegnerischen Wesen ${p + 1} Schaden zu. Gibt es kein gegnerisches Wesen, trifft der Schaden den gegnerischen Helden.`,
  guard: p => `Beim Beschwören: Dein Held erhält ${p + 2} Block bis zu deinem nächsten Zugbeginn.`,
  ward: p => `Beim Beschwören: Dein Held erhält ${p + 1} Schild, höchstens 25 insgesamt.`,
  mend: p => `Beim Beschwören: Heile deinen Helden um ${p + 2} Leben.`,
  weave: p => `Beim Beschwören: Erzeuge ${p + 1} Resonanz.`,
  drain: p => `Beim Beschwören: Füge dem gegnerischen Helden ${p + 1} Schaden zu. Heile deinen Helden um den verursachten Lebensverlust.`,
  rally: p => `Beim Beschwören: Das linke eigene Nachbarwesen erhält +${p} Angriff. Fehlt dort ein Wesen, erhält stattdessen das rechte eigene Nachbarwesen +${p} Angriff.`,
  silence: () => 'Beim Beschwören: Versetze das direkt gegenüberliegende gegnerische Wesen für mindestens 1 gegnerische Angriffsphase in Stasis.',
  pierce: p => `Beim Beschwören: Füge dem gegnerischen Helden ${p + 2} Schaden zu. Dieser Schaden ignoriert Block und Schild.\nBeim Angreifen: Überzähliger Schaden gegen ein besiegtes Wesen trifft den gegnerischen Helden. Block und Schild wirken gegen diesen Schaden.`,
  shift: () => 'Beim Beschwören: Du darfst ein eigenes Wesen auf einem Nachbarpfad auf einen freien eigenen Pfad verschieben.',
  harvest: p => `Wenn dieses Wesen besiegt wird: Erzeuge ${p + 1} Resonanz.`,
  // Runtime tests attack strength >0 BEFORE unit shield, not actual HP loss.
  retaliate: p => `Beim Verteidigen: Überlebt dieses Wesen einen Angriff mit mindestens 1 Schadenspunkt vor Schild, fügt es dem Angreifer ${p} Schaden zu.`,
  draw: () => 'Beim Beschwören: Ziehe 1 Karte. Bei 6 Handkarten oder leerem Nachziehstapel wird keine Karte gezogen.',
  haste: () => 'Beim Beschwören: Dieses Wesen kann bereits am Ende dieses Zuges angreifen (Eile).',
  weaken: p => `Beim Beschwören: Verringere den Angriff gegnerischer Wesen in ihrer nächsten Angriffsphase um ${p}, mindestens auf 0. Es gilt nur die stärkste Schwächung.`,
  pulse: p => `Beim Beschwören: Erzeuge ${p} Resonanz. Dein Held erhält ${p} Schild. Beide eigenen Nachbarwesen erhalten +1 Angriff.`,
});
const EVENTS = Object.freeze({
  bolt: p => `Beim Ausspielen: Füge dem Wesen auf dem gewählten gegnerischen Pfad ${p} Schaden zu. Ist der Pfad leer, trifft der Schaden den gegnerischen Helden.`,
  heal: p => `Beim Ausspielen: Heile deinen Helden um ${p} Leben.`,
  stasis: p => `Beim Ausspielen: Versetze ein gegnerisches Wesen für mindestens ${p} gegnerische Angriffsphasen in Stasis.`,
  surge: () => 'Beim Ausspielen: Ein kampfbereites eigenes Wesen erhält für diese Angriffsphase 1 zusätzlichen Angriff.',
  recall: () => 'Beim Ausspielen: Beschwöre das zuletzt abgelegte Wesen aus deiner Ablage auf einem freien eigenen Pfad. Beschwörungseffekte werden erneut ausgelöst.',
  delay: p => `Beim Ausspielen: Füge nach 2 Zugwechseln dem Wesen auf dem gewählten gegnerischen Pfad ${p} Schaden zu. Ist der Pfad dann leer, trifft der Schaden den gegnerischen Helden.`,
  redirect: () => 'Beim Ausspielen: Lenke deinen ältesten verzögerten Treffer auf den gewählten gegnerischen Pfad um. Der Zeitpunkt bleibt gleich.',
  displace: () => 'Beim Ausspielen: Verschiebe ein gegnerisches Wesen auf den freien linken Nachbarpfad, sonst auf den freien rechten Nachbarpfad.',
  cascade: p => `Beim Ausspielen: Füge dem gegnerischen Helden nacheinander ${p}-mal je 1 Schaden zu. Block und Schild absorbieren jeden Treffer.`,
});
const RELICS = Object.freeze({
  relic_res: () => 'Beim Aktivieren für 1 Energie: Erzeuge 1 Resonanz. Nur 1 Reliktaktivierung je eigenem Zug.',
  relic_ward: () => 'Beim Aktivieren für 1 Energie: Dein Held erhält 2 Schild, höchstens 25 insgesamt. Nur 1 Reliktaktivierung je eigenem Zug.',
  relic_heal: () => 'Beim Aktivieren für 1 Energie: Heile deinen Helden um 2 Leben. Nur 1 Reliktaktivierung je eigenem Zug.',
  relic_draw: () => 'Beim Aktivieren für 1 Energie: Ziehe 1 Karte. Benötigt einen nicht leeren Nachziehstapel und weniger als 6 Handkarten. Nur 1 Reliktaktivierung je eigenem Zug.',
});
const HANDLERS = Object.freeze({creature: CREATURE, event: EVENTS, relic: RELICS});

function descriptionFor(card) {
  if (!card || typeof card !== 'object' || Array.isArray(card)) throw new TypeError('Kartendaten fehlen.');
  if (!Object.hasOwn(HANDLERS, card.kind)) throw new Error(`${card.id || '?'}: unbekannter Kartentyp ${card.kind}`);
  if (!Object.hasOwn(HANDLERS[card.kind], card.effect)) throw new Error(`${card.id || '?'}: unbekannter Effekt ${card.effect} für ${card.kind}`);
  if (!Number.isSafeInteger(card.power) || card.power < 0) throw new Error(`${card.id || '?'}: ungültiger Effektparameter power`);
  return HANDLERS[card.kind][card.effect](card.power);
}

function validateTexts(data) {
  if (!data || !Array.isArray(data.cards)) return ['Kartenliste fehlt.'];
  const errors = [];
  for (const card of data.cards) {
    try {
      const expected = descriptionFor(card);
      if (card.description !== expected) errors.push(`${card.id}: Text stimmt nicht mit dem vorhandenen Effekt überein.`);
      if (!TRIGGERS.some(t => expected.startsWith(t))) errors.push(`${card.id}: Auslöser muss zuerst stehen.`);
      if (expected.length > 320) errors.push(`${card.id}: Text überschreitet die geprüfte Grenze von 320 Zeichen.`);
      if (/\b(?:TODO|TBD|Platzhalter|unsupported|undefined|NaN)\b/i.test(expected)) errors.push(`${card.id}: nicht fertiger Kartentext.`);
    } catch (error) { errors.push(error.message); }
  }
  return errors;
}

function withGeneratedTexts(data) {
  const next = structuredClone(data);
  for (const card of next.cards) card.description = descriptionFor(card);
  return next;
}

function main(args) {
  if (args.length > 1 || (args.length && !['--check', '--write'].includes(args[0]))) {
    throw new Error('Aufruf: node tools/alpha_card_texts.cjs [--check|--write]');
  }
  let data = JSON.parse(fs.readFileSync(CARD_PATH, 'utf8'));
  if (args[0] === '--write') {
    data = withGeneratedTexts(data);
    const errors = validateTexts(data);
    if (errors.length) throw new Error(errors.join('\n'));
    fs.writeFileSync(CARD_PATH, JSON.stringify(data, null, 2) + '\n');
  }
  const errors = validateTexts(data);
  if (errors.length) throw new Error(errors.join('\n'));
  console.log(`ALPHA CARD TEXTS: ${data.cards.length} geprüfte Texte; Werte und Regeln unverändert.`);
}
if (require.main === module) {
  try { main(process.argv.slice(2)); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
module.exports = {descriptionFor, validateTexts, withGeneratedTexts, HANDLERS};
