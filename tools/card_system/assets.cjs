#!/usr/bin/env node
'use strict';
// Inventories real pilot references only. Target counts never create fake cards or assets.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const ROOT = path.resolve(__dirname, '../..');
const output = path.join(ROOT, 'data/card_system/illustration_manifest.json');
const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex');

function inventory() {
  const pilot = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/card_system/pilot.json'), 'utf8'));
  const source = JSON.parse(fs.readFileSync(path.join(ROOT, 'data/alpha/cards.json'), 'utf8'));
  const atlasPath = 'assets/art/atlas.png';
  const atlas = fs.readFileSync(path.join(ROOT, atlasPath));
  if (!atlas.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) throw new Error('Concept atlas is not a PNG');
  const width = atlas.readUInt32BE(16), height = atlas.readUInt32BE(20);
  if (width % 3 || height % 3) throw new Error('Concept atlas is not a 3x3 grid');
  const entries = pilot.cards.map(card => {
    if (card.art.asset_id !== 'shared:orafold-atlas' || card.art.status !== 'shared_concept') throw new Error(`Unreviewed illustration mapping: ${card.id}`);
    const candidate = `assets/cards/originals/${card.id}.png`;
    const originalExists = fs.existsSync(path.join(ROOT, candidate));
    return {
      card_id: card.id,
      name: card.name,
      power: card.power,
      current_status: 'shared_concept',
      shared_reference: {asset_id: card.art.asset_id, path: atlasPath, provenance: card.art.provenance},
      individual_original: {expected_path: candidate, exists: originalExists, status: originalExists ? 'unreviewed' : 'missing', commercially_cleared: false},
      release_note_de: 'Geteiltes Konzeptmotiv; keine fertiggestellte individuelle Kartenillustration behauptet.',
    };
  });
  return {
    schema_version: 1,
    scope: 'real_v2_pilot_references_only',
    generator: 'node tools/card_system/assets.cjs',
    source_catalog_card_count: source.cards.length,
    inventory_card_count: entries.length,
    shared_concept_card_count: entries.length,
    missing_individual_original_count: entries.filter(entry => !entry.individual_original.exists).length,
    final_individual_original_count: 0,
    atlas: {path: atlasPath, sha256: sha256(atlas), width, height, columns: 3, rows: 3, cell_width: width / 3, cell_height: height / 3, available_portrait_cells: 9, alpha_reused_portrait_indices: [0, 1, 2, 3, 4, 5, 6], selection_source: 'scripts/alpha/card_view.gd', provenance: 'assets/ASSET_MANIFEST.md'},
    future_plan: {desired_catalogue_cards: 550, desired_per_power: 110, generated_future_card_rows: 0, individual_artwork_status: 'not_created_by_this_tool'},
    original_metadata_required: ['asset_id', 'card_id', 'creator_or_generator', 'creation_date', 'source_or_prompt', 'reference_sources', 'commercial_usage_basis', 'original_width', 'original_height', 'sha256', 'edits', 'review_status', 'alternative_text'],
    entries,
  };
}

function main() {
  const expected = JSON.stringify(inventory(), null, 2) + '\n';
  if (process.argv.includes('--check')) {
    if (!fs.existsSync(output) || fs.readFileSync(output, 'utf8') !== expected) { console.error('Illustration inventory is stale. Run node tools/card_system/assets.cjs'); process.exitCode = 1; }
  } else fs.writeFileSync(output, expected);
}
if (require.main === module) main();
module.exports = {inventory};
