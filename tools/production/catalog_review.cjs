#!/usr/bin/env node
'use strict';

// Read-only editorial inventory. Field presence is never proof of executable
// effects, accepted canon, balance, illustration quality or commercial rights.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const ROOT = path.resolve(__dirname, '../..');
const AFFILIATIONS = ['Zwölf Häuser', 'Stillwacht', 'Vielgestalt', 'Neunte Stunde', 'Neutral'];
const KINDS = ['Wesen', 'Impuls', 'Relikt'];
const RARITIES = ['Gewöhnlich', 'Selten', 'Episch', 'Legendär'];
const SPECIES = ['Menschen', 'Bestien', 'Geister', 'Konstrukte', 'Pflanzen', 'Amalgame', 'Morphiden', 'Paradoxe', 'Wiedergänger', 'Elementare', 'Zehrer', 'Mechanoide'];
const LORE_STATUSES = ['KANON', 'ARBEITSSTAND', 'VORSCHLAG', 'ALTENTWURF', 'VERWORFEN', 'VERWORFEN/ABGELÖST', 'OFFEN'];
const SOURCE_PATHS = {
  cards: 'data/lore/card-concepts.json',
  characters: 'data/lore/characters.json',
  locations: 'data/lore/locations.json',
  organizations: 'data/lore/organizations.json',
  families: 'data/lore/card-families.json',
  alpha: 'data/alpha/cards.json'
};
const REQUIRED_EDITORIAL = ['id', 'name', 'affiliation', 'card_type', 'rarity', 'region', 'organization', 'location_id', 'character_id', 'family_id', 'lore', 'flavor', 'visual_brief', 'mechanical_intent', 'status', 'story_hook', 'causal_link', 'narrative_role_detail', 'art_direction'];
const REQUIRED_GAME = ['energy_cost', 'abilities', 'text_de', 'art'];

function nonempty(value) { return typeof value === 'string' && value.trim().length > 0; }
function count(values) {
  const result = Object.create(null);
  for (const value of values) result[String(value)] = (result[String(value)] || 0) + 1;
  return {...result};
}
function normalize(value) { return typeof value === 'string' ? value.normalize('NFC').trim().replace(/\s+/gu, ' ').toLocaleLowerCase('de-DE') : ''; }
function duplicateSummary(rows, field, transform = value => value) {
  const groups = new Map();
  for (const row of rows) {
    const value = transform(row[field], row);
    if (!nonempty(value)) continue;
    if (!groups.has(value)) groups.set(value, []);
    groups.get(value).push(row.id);
  }
  const repeated = [...groups.entries()].filter(([, ids]) => ids.length > 1).sort((a, b) => b[1].length - a[1].length || a[0].localeCompare(b[0], 'de'));
  return {
    distinct_values: groups.size,
    duplicate_group_count: repeated.length,
    cards_in_duplicate_groups: repeated.reduce((sum, [, ids]) => sum + ids.length, 0),
    redundant_rows: repeated.reduce((sum, [, ids]) => sum + ids.length - 1, 0),
    largest_group_size: repeated[0]?.[1].length || 0,
    examples: repeated.slice(0, 5).map(([value, ids]) => ({value, count: ids.length, card_ids: ids}))
  };
}
function indexReferences(rows, name, errors) {
  const index = new Map();
  for (const row of rows) {
    if (!row || typeof row !== 'object' || !nonempty(row.id)) { errors.push({code: 'invalid_reference_record', source: name}); continue; }
    if (index.has(row.id)) errors.push({code: 'duplicate_reference_id', source: name, id: row.id});
    index.set(row.id, row);
  }
  return index;
}
function analyze(input) {
  for (const key of ['cards', 'characters', 'locations', 'organizations', 'families', 'alpha']) {
    if (!Array.isArray(input[key])) throw new TypeError(`${key} must be an array`);
  }
  const errors = [];
  const cards = input.cards.filter(row => {
    if (!row || typeof row !== 'object' || Array.isArray(row)) { errors.push({code: 'invalid_card_record'}); return false; }
    return true;
  });
  const refs = {
    character_id: indexReferences(input.characters, 'characters', errors),
    location_id: indexReferences(input.locations, 'locations', errors),
    family_id: indexReferences(input.families, 'families', errors)
  };
  indexReferences(input.organizations, 'organizations', errors);
  const organizations = new Map(input.organizations.filter(row => row && nonempty(row.name)).map(row => [row.name, row]));
  const seenIds = new Set();
  const seenNames = new Set();
  const namesWithIds = [];
  const characterAffiliation = [];
  const characterRegion = [];
  const referenceStatus = [];
  const missingGameFields = Object.fromEntries(REQUIRED_GAME.map(field => [field, []]));
  missingGameFields.attack = [];
  missingGameFields.health = [];
  let candidateDefinitions = 0;
  for (const card of cards) {
    const issue = (code, detail = {}) => errors.push({code, card_id: card.id ?? null, ...detail});
    for (const field of REQUIRED_EDITORIAL) if (!nonempty(card[field])) issue('missing_editorial_field', {field});
    if (nonempty(card.id) && !/^(?:ZH|SW|VG|NS|NE)-\d{3}$/u.test(card.id)) issue('invalid_concept_id');
    if (seenIds.has(card.id)) issue('duplicate_card_id');
    seenIds.add(card.id);
    const normalizedName = normalize(card.name);
    if (seenNames.has(normalizedName)) issue('duplicate_normalized_name');
    seenNames.add(normalizedName);
    if (!AFFILIATIONS.includes(card.affiliation)) issue('invalid_affiliation');
    if (!KINDS.includes(card.card_type)) issue('invalid_card_type');
    if (!RARITIES.includes(card.rarity)) issue('invalid_rarity');
    if (!LORE_STATUSES.includes(card.status)) issue('invalid_lore_status');
    if (typeof card.prototype_only !== 'boolean') issue('missing_prototype_flag');
    const species = card.species;
    if (!Array.isArray(species)) issue('invalid_species_array');
    else {
      if (card.card_type === 'Wesen' ? species.length < 1 || species.length > 2 : species.length !== 0) issue('invalid_species_count');
      if (new Set(species).size !== species.length || species.some(value => !SPECIES.includes(value))) issue('invalid_species_member');
    }
    for (const [field, index] of Object.entries(refs)) {
      const target = index.get(card[field]);
      if (!target) issue('missing_reference', {field, reference: card[field] ?? null});
      else if (target.status !== 'KANON') referenceStatus.push({card_id: card.id, field, reference: target.id, status: target.status ?? null});
    }
    const location = refs.location_id.get(card.location_id);
    if (location && location.region !== card.region) issue('location_region_mismatch', {reference: location.id});
    const family = refs.family_id.get(card.family_id);
    if (family && family.affiliation !== card.affiliation) issue('family_affiliation_mismatch', {reference: family.id});
    const organization = organizations.get(card.organization);
    if (!organization) issue('missing_organization_reference', {reference: card.organization ?? null});
    else {
      if (organization.power !== card.affiliation) issue('organization_affiliation_mismatch', {reference: organization.id});
      if (organization.status !== 'KANON') referenceStatus.push({card_id: card.id, field: 'organization', reference: organization.id, status: organization.status ?? null});
    }
    const character = refs.character_id.get(card.character_id);
    // Cross-power and travelling characters are possible. These are review
    // observations, not inferred canon contradictions or automatic errors.
    if (character && character.affiliation !== card.affiliation) characterAffiliation.push(card.id);
    if (character && character.region !== card.region) characterRegion.push(card.id);
    if (typeof card.name === 'string' && /\((?:ZH|SW|VG|NS|NE)-\d{3}\)/u.test(card.name)) namesWithIds.push(card.id);
    const missing = REQUIRED_GAME.filter(field => !Object.hasOwn(card, field));
    for (const field of missing) missingGameFields[field].push(card.id);
    if (card.card_type === 'Wesen') for (const field of ['attack', 'health']) {
      if (!Object.hasOwn(card, field)) { missingGameFields[field].push(card.id); missing.push(field); }
    }
    if (!missing.length) candidateDefinitions++;
  }
  const affiliationCounts = count(cards.map(card => card.affiliation));
  if (input.cards.length !== 550) errors.push({code: 'wrong_total', expected: 550, actual: input.cards.length});
  for (const affiliation of AFFILIATIONS) if (affiliationCounts[affiliation] !== 110) errors.push({code: 'wrong_affiliation_count', affiliation, expected: 110, actual: affiliationCounts[affiliation] || 0});
  const alphaCards = input.alpha;
  const alphaIds = new Set(alphaCards.map(card => card.id));
  const fieldRepetition = Object.fromEntries(['name', 'visual_brief', 'art_direction', 'lore', 'flavor', 'story_hook', 'mechanical_intent'].map(field => [field, duplicateSummary(cards, field)]));
  fieldRepetition.lore_without_card_name = duplicateSummary(cards, 'lore', (value, row) => typeof value === 'string' && nonempty(row.name) ? value.split(row.name).join('{CARD_NAME}') : value);
  return {
    schema_version: 1,
    scope: 'read_only_proposal_catalog_review',
    source_sha256: input.source_sha256 || {},
    counts: {
      cards: input.cards.length,
      affiliations: affiliationCounts,
      card_types: count(cards.map(card => card.card_type)),
      rarities: count(cards.map(card => card.rarity)),
      lore_status: count(cards.map(card => card.status)),
      prototype_only: cards.filter(card => card.prototype_only === true).length,
      reference_card_flag: cards.filter(card => card.reference_card === true).length,
      creatures_by_species: count(cards.filter(card => card.card_type === 'Wesen').flatMap(card => Array.isArray(card.species) ? card.species : [])),
      creatures_by_species_count: count(cards.filter(card => card.card_type === 'Wesen').map(card => Array.isArray(card.species) ? card.species.length : 'invalid')),
      active_alpha_cards: alphaCards.length,
      concept_ids_also_in_alpha: cards.filter(card => alphaIds.has(card.id)).map(card => card.id)
    },
    structure: {valid: errors.length === 0, errors},
    references: {
      characters: input.characters.length,
      locations: input.locations.length,
      organizations: input.organizations.length,
      families: input.families.length,
      non_canon_reference_edges: referenceStatus.length,
      character_affiliation_differs: {count: characterAffiliation.length, card_ids: characterAffiliation},
      character_region_differs: {count: characterRegion.length, card_ids: characterRegion},
      interpretation: 'Cross-power or travelling characters are possible; these links require editorial review and are not automatically invalid.'
    },
    editorial: {
      names_with_technical_id_suffix: {count: namesWithIds.length, card_ids: namesWithIds},
      repetition: fieldRepetition,
      interpretation: 'Exact text reuse is measured, not artistic quality. A unique string alone does not establish a unique scene or card mechanic.'
    },
    gameplay_data: {
      missing_fields: Object.fromEntries(Object.entries(missingGameFields).map(([field, ids]) => [field, {count: ids.length, card_ids: ids}])),
      candidate_definitions_with_all_fields_present: candidateDefinitions,
      runtime_verified_cards: null,
      individual_illustrations_verified: null,
      balance_simulated_matches: 0,
      release_ready: false,
      release_blockers: [
        ...(candidateDefinitions < cards.length ? ['incomplete_game_definitions'] : []),
        'runtime_execution_not_verified_by_static_review',
        'individual_illustration_and_rights_review_not_verified_by_static_review',
        'complete_match_balance_evidence_not_collected_by_static_review'
      ],
      interpretation: 'Field presence is only a prerequisite. This tool executes no abilities or matches, decodes no images and grants no canon or rights approval.'
    }
  };
}

function loadRepository(root = ROOT) {
  const result = {source_sha256: {}};
  for (const [key, file] of Object.entries(SOURCE_PATHS)) {
    const bytes = fs.readFileSync(path.join(root, file));
    const parsed = JSON.parse(bytes.toString('utf8'));
    result[key] = key === 'alpha' && !Array.isArray(parsed) ? parsed.cards : parsed;
    result.source_sha256[file] = crypto.createHash('sha256').update(bytes).digest('hex');
  }
  return result;
}

function renderMarkdown(report) {
  const c = report.counts;
  const lines = [
    '# ORAFOLD – reproduzierbare Konzeptprüfung', '',
    'Statische Bestandsprüfung; keine Spielbarkeits-, Bild-, Kanon- oder Balanceabnahme.', '',
    `Erfasst: **${c.cards} Konzepte**, **${c.active_alpha_cards} aktive Alpha-Karten**, **${c.concept_ids_also_in_alpha.length} gemeinsame IDs**.`, '',
    '| Zugehörigkeit | Konzepte |', '|---|---:|',
    ...AFFILIATIONS.map(power => `| ${power} | ${c.affiliations[power] || 0} |`), '',
    '| Kartentyp | Konzepte |', '|---|---:|',
    ...KINDS.map(kind => `| ${kind} | ${c.card_types[kind] || 0} |`), '',
    '| Seltenheit | Konzepte |', '|---|---:|',
    ...RARITIES.map(rarity => `| ${rarity} | ${c.rarities[rarity] || 0} |`), '',
    `Strukturprüfung: ${report.structure.valid ? 'bestanden' : 'FEHLER'} (${report.structure.errors.length} Fehler).`,
    `Vorschläge: ${c.lore_status.VORSCHLAG || 0}; prototype_only: ${c.prototype_only}; Referenzmarkierung: ${c.reference_card_flag}.`, '',
    '| Wesensart | Wesen |', '|---|---:|',
    ...SPECIES.map(species => `| ${species} | ${c.creatures_by_species[species] || 0} |`), '',
    `Artenzahl je Wesen: ${Object.entries(c.creatures_by_species_count).map(([amount, total]) => `${total} mit ${amount}`).join(', ')}. Beide Arten bleiben bei einer späteren Doppelklassifikation gleichwertig.`,
    `Referenzbestand: ${report.references.characters} Figuren, ${report.references.locations} Orte, ${report.references.organizations} Organisationen und ${report.references.families} Familien. Nicht kanonisierte Referenzkanten: ${report.references.non_canon_reference_edges}.`, '',
    '| Wiederverwendetes Feld | Unterschiedliche Werte | Zeilen in Mehrfachgruppen | Größte Gruppe |', '|---|---:|---:|---:|',
    ...Object.entries(report.editorial.repetition).map(([field, result]) => `| ${field} | ${result.distinct_values} | ${result.cards_in_duplicate_groups} | ${result.largest_group_size} |`), '',
    `Namen mit technischem ID-Anhang: ${report.editorial.names_with_technical_id_suffix.count}.`,
    `Figurenverweise mit anderer Zugehörigkeit: ${report.references.character_affiliation_differs.count}; mit anderer Region: ${report.references.character_region_differs.count}. Diese Befunde verlangen redaktionelle Prüfung; wechselnde Zugehörigkeit oder Reisen sind möglich.`, '',
    '| Fehlendes Gameplayfeld | Betroffene Konzepte |', '|---|---:|',
    ...Object.entries(report.gameplay_data.missing_fields).map(([field, result]) => `| ${field} | ${result.count} |`), '',
    `Konzepte mit sämtlichen geprüften Gameplayfeldern vorhanden: ${report.gameplay_data.candidate_definitions_with_all_fields_present}; keine Ausführbarkeit daraus abgeleitet.`,
    `Vollständige Partien in diesem Werkzeug: ${report.gameplay_data.balance_simulated_matches}. Releasefreigabe: **nein**.`, '',
    '## Folgerungen für die nächste Autorencharge', '',
    'Die bestehende Lore-Bibel bleibt die Kanonreferenz. Die Konzeptnamen, Orte, Figurenbeziehungen und Schauplätze bleiben Vorschläge. Ein formal existierender Verweis bestätigt weder eine Biografie noch die behauptete Beziehung der Karte zur Figur.', '',
    'Wiederverwendete Konflikte können Kartenfamilien verbinden; jede Karte braucht dennoch eine konkrete eigene Szene, einen lesbaren individuellen Namen und eine eigene Funktion. Technische ID-Anhänge ersetzen keine eigenständigen Namen. Identische Texte sind hier exakt gemessen; ähnliche Texte können zusätzlich vorhanden sein.', '',
    'Zuerst kleine kuratierte Chargen mit Gegenstrategien, Energie-/Resonanzkosten und tatsächlich unterstützten Effektprogrammen erstellen. Eine Feldanwesenheitsprüfung ersetzt keine Vertrags- und Ausführungstests. Ohne Zahlen und Effekte ist das Wertebudget nicht berechenbar; das Werkzeug erzeugt daher keine Scheinsimulation oder Siegraten.', '',
    'Keine Alpha- oder Legacy-Karte wird durch diese Prüfung ersetzt oder gelöscht. Die Konzept-IDs sind ein getrennter Namensraum. Aktive Migration, Umleitung, Trigger-, Session- und Replayintegration bleiben von der zusammengeführten Enginearbeit und einer anschließenden Gesamtprüfung abhängig.', '',
    '## Reproduktion', '',
    '```sh', 'node tools/production/catalog_review.cjs --check', 'node tools/production/catalog_review.cjs --format markdown', 'node tools/production/catalog_review.cjs --require-release', '```', '',
    '`--check` prüft die Struktur der Vorschläge. `--require-release` schlägt bewusst fehl, solange Laufzeit-, Einzelbild- und Partiennachweise fehlen. Die Ausgabe erfolgt nur auf stdout; keine Quelldatei wird verändert.', '',
    '## Quellenfingerabdrücke', '', '```json', JSON.stringify(report.source_sha256, null, 2), '```', ''
  ];
  if (report.structure.errors.length) lines.push('## Strukturfehler', '', '```json', JSON.stringify(report.structure.errors, null, 2), '```', '');
  return lines.join('\n');
}

function main(args = process.argv.slice(2)) {
  let format = 'json';
  let check = false;
  let requireRelease = false;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--format') {
      format = args[++i];
      if (!['json', 'markdown'].includes(format)) throw new Error('--format requires json or markdown');
    } else if (args[i] === '--check') check = true;
    else if (args[i] === '--require-release') requireRelease = true;
    else throw new Error(`Unknown argument: ${args[i]}`);
  }
  const report = analyze(loadRepository());
  process.stdout.write(format === 'markdown' ? renderMarkdown(report) : `${JSON.stringify(report, null, 2)}\n`);
  if ((check && !report.structure.valid) || (requireRelease && !report.gameplay_data.release_ready)) process.exitCode = 1;
}

if (require.main === module) {
  try { main(); } catch (error) { process.stderr.write(`${error.message}\n`); process.exitCode = 2; }
}
module.exports = {analyze, loadRepository, renderMarkdown, AFFILIATIONS, KINDS, RARITIES, SPECIES};
