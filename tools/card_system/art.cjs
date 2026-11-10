'use strict';
const fs = require('node:fs');
const path = require('node:path');
const ROOT = path.resolve(__dirname, '../..');
const SHARED_ATLAS = 'assets/art/atlas.png';

// File existence and format validation do not establish copyright clearance,
// thematic suitability or final artistic review. Godot must also decode the file.
function resolveArtAsset(art, options = {}) {
  const root = options.root || ROOT;
  const reject = reason => ({ok: false, reason, resource_path: null});
  if (!art || typeof art.asset_id !== 'string') return reject('invalid_asset_id');
  if (art.status === 'missing') return /^missing:[a-z][a-z0-9-]+$/u.test(art.asset_id)
    ? {ok: true, reason: 'explicitly_missing', resource_path: null} : reject('missing_status_requires_missing_id');
  if (art.status === 'shared_concept') {
    if (art.asset_id !== 'shared:orafold-atlas') return reject('unknown_shared_asset');
    const checked = resolveImage(`res://${SHARED_ATLAS}`, root);
    return checked.ok ? {...checked, reason: 'known_shared_concept'} : checked;
  }
  if (!['concept', 'final'].includes(art.status)) return reject('invalid_art_status');
  const checked = resolveImage(art.asset_id, root);
  if (!checked.ok) return checked;
  // Do not turn the same shared atlas into an individual original by changing
  // its ID to a file path or an in-tree symlink alias.
  let shared;
  try { shared = fs.realpathSync(path.join(root, SHARED_ATLAS)); } catch { shared = null; }
  if (shared && checked.absolute_path === shared) return reject('shared_atlas_requires_shared_concept_status');
  return checked;
}

function resolveImage(resource, root) {
  const reject = reason => ({ok: false, reason, resource_path: null});
  if (typeof resource !== 'string' || !resource.startsWith('res://assets/')) return reject('individual_asset_requires_res_assets_path');
  const relative = resource.slice('res://'.length);
  if (/[\\\u0000-\u001f<>:"|?*#%]/u.test(relative)) return reject('unsafe_asset_path');
  const segments = relative.split('/');
  if (segments.some(segment => !segment || segment === '.' || segment === '..')) return reject('asset_path_traversal');
  const extension = path.extname(relative).toLowerCase();
  if (!['.png', '.jpg', '.jpeg', '.webp', '.svg'].includes(extension)) return reject('unsupported_image_format');
  try {
    const assetsRoot = fs.realpathSync(path.join(root, 'assets'));
    if (assetsRoot !== path.join(fs.realpathSync(root), 'assets')) return reject('asset_root_symlink_redirect');
    const absolute = fs.realpathSync(path.join(root, relative));
    if (!absolute.startsWith(assetsRoot + path.sep)) return reject('asset_symlink_escape');
    const stat = fs.statSync(absolute);
    if (!stat.isFile()) return reject('asset_is_not_regular_file');
    if (stat.size > 32 * 1024 * 1024 || stat.size < 12) return reject('invalid_image_size');
    const fd = fs.openSync(absolute, 'r');
    const head = Buffer.alloc(Math.min(stat.size, 4096));
    const tail = Buffer.alloc(Math.min(stat.size, 12));
    try { fs.readSync(fd, head, 0, head.length, 0); fs.readSync(fd, tail, 0, tail.length, stat.size - tail.length); }
    finally { fs.closeSync(fd); }
    let image = false;
    if (extension === '.png') image = head.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])) && head.length >= 24 && head.toString('ascii', 12, 16) === 'IHDR' && head.readUInt32BE(16) > 0 && head.readUInt32BE(20) > 0 && tail.toString('ascii', tail.length - 8, tail.length - 4) === 'IEND';
    else if (extension === '.jpg' || extension === '.jpeg') image = head[0] === 255 && head[1] === 216 && head[2] === 255 && tail[tail.length - 2] === 255 && tail[tail.length - 1] === 217;
    else if (extension === '.webp') image = head.toString('ascii', 0, 4) === 'RIFF' && head.toString('ascii', 8, 12) === 'WEBP' && head.readUInt32LE(4) + 8 === stat.size;
    else if (extension === '.svg') { const text = head.toString('utf8'); image = /<svg(?:\s|>)/u.test(text) && !/<!DOCTYPE|<!ENTITY/iu.test(text); }
    if (!image) return reject('file_does_not_match_image_format');
    return {ok: true, reason: 'existing_image_file', resource_path: resource, absolute_path: absolute};
  } catch { return reject('asset_file_missing_or_unreadable'); }
}

module.exports = {resolveArtAsset};
