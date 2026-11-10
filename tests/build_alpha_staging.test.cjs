'use strict';
// Filesystem/failure unit tests with an explicitly simulated exporter. These do
// not establish that a Godot export or playable browser build has succeeded.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const REPO = path.resolve(__dirname, '..');
const SHA = '1234567890abcdef1234567890abcdef12345678';
const PREFIX = `orafold-${SHA.slice(0, 12)}`;

function fixture(mode) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'orafold-staging-test-'));
  for (const dir of ['tools', 'bin', 'work/alpha/web']) fs.mkdirSync(path.join(root, dir), {recursive: true});
  fs.copyFileSync(path.join(REPO, 'tools/build_alpha.sh'), path.join(root, 'tools/build_alpha.sh'));
  fs.copyFileSync(path.join(REPO, 'tools/alpha02_pack_inventory.gd'), path.join(root, 'tools/alpha02_pack_inventory.gd'));
  const original = {'index.html': 'previous verified page', 'old-prefix.wasm': 'previous verified bytes'};
  for (const [name, bytes] of Object.entries(original)) fs.writeFileSync(path.join(root, 'work/alpha/web', name), bytes);
  fs.writeFileSync(path.join(root, 'bin/git'), `#!/bin/sh\nprintf '%s\\n' '${SHA}'\n`, {mode: 0o700});
  fs.writeFileSync(path.join(root, 'bin/mv'), `#!${process.execPath}
const {spawnSync}=require('node:child_process');
const args=process.argv.slice(2);
if(process.env.STAGING_TEST_MODE==='rename-failure' && args[0].includes('/.web-staging.') && args[1].endsWith('/work/alpha/web'))process.exit(9);
const result=spawnSync('/bin/mv',args,{stdio:'inherit'});process.exit(result.status===null?1:result.status);
`, {mode: 0o700});
  const mock = path.join(root, 'bin/mock-godot.cjs');
  fs.writeFileSync(mock, `#!${process.execPath}
const fs=require('node:fs'),path=require('node:path');
const args=process.argv.slice(2);
if(args.includes('--export-debug')) {
 const target=args.at(-1), stem=target.slice(0,-5);
 fs.writeFileSync(target,'simulated index referring to '+path.basename(stem));
 for(const extension of ['pck','wasm','js']) {
  if(process.env.STAGING_TEST_MODE==='missing-file' && extension==='wasm')continue;
  fs.writeFileSync(stem+'.'+extension,'explicitly simulated '+extension);
 }
 process.exit(process.env.STAGING_TEST_MODE==='export-failure'?7:0);
}
if(args.includes('--main-pack')) {
 if(process.env.STAGING_TEST_MODE==='pack-failure')process.exit(8);
 console.log(JSON.stringify({test_double:true,forbidden:[]}));process.exit(0);
}
process.exit(9);
`, {mode: 0o700});
  const result = spawnSync('bash', ['tools/build_alpha.sh'], {cwd: root, encoding: 'utf8', env: {...process.env,
    PATH: path.join(root, 'bin') + path.delimiter + process.env.PATH, GODOT_BIN: mock, STAGING_TEST_MODE: mode,
    XDG_DATA_HOME: path.join(root, 'work/xdg/data'), XDG_CONFIG_HOME: path.join(root, 'work/xdg/config'),
    XDG_CACHE_HOME: path.join(root, 'work/xdg/cache'), GITHUB_REF_NAME: 'isolated-unit-test'}});
  return {root, result, original};
}

for (const mode of ['export-failure', 'pack-failure', 'missing-file', 'rename-failure']) test(`failed staging preserves complete previous directory: ${mode}`, () => {
  const {root, result, original} = fixture(mode);
  try {
    assert.notEqual(result.status, 0, result.stdout + result.stderr);
    const web = path.join(root, 'work/alpha/web');
    assert.deepEqual(fs.readdirSync(web).sort(), Object.keys(original).sort());
    for (const [name, bytes] of Object.entries(original)) assert.equal(fs.readFileSync(path.join(web, name), 'utf8'), bytes);
    assert.deepEqual(fs.readdirSync(path.join(root, 'work/alpha')).filter(name => name.startsWith('.web-')), []);
  } finally { fs.rmSync(root, {recursive: true, force: true}); }
});

test('successful staging replaces history with only the verified candidate', () => {
  const {root, result} = fixture('success');
  try {
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const web = path.join(root, 'work/alpha/web');
    assert.deepEqual(fs.readdirSync(web).sort(), ['build-info.json', 'index.html', ...['js', 'pck', 'wasm'].map(ext => `${PREFIX}.${ext}`)].sort());
    const info = JSON.parse(fs.readFileSync(path.join(web, 'build-info.json'), 'utf8'));
    assert.equal(info.commit, SHA);
    assert.equal(info.channel, 'isolated-unit-test');
    assert.deepEqual(fs.readdirSync(path.join(root, 'work/alpha')).filter(name => name.startsWith('.web-')), []);
  } finally { fs.rmSync(root, {recursive: true, force: true}); }
});
