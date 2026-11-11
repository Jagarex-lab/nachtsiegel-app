const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

// Execute the exact JavaScriptBridge transaction, not a second implementation.
// Storage errors below are explicitly injected unit fixtures, not browser QA.
const source = fs.readFileSync('scripts/production/profile_store.gd', 'utf8');
const script = source.match(/const WEB_STORAGE_SCRIPT := """([\s\S]*?)"""/)[1];
const primary = 'orafold.profile.v2', backup = primary + '.bak';
class Storage {
  constructor(values = {}) { this.values = new Map(Object.entries(values)); this.fail = () => false; }
  getItem(key) { return this.values.has(key) ? this.values.get(key) : null; }
  setItem(key, value) {
    if (this.fail(key, value)) { const e = new Error('Injected unit quota'); e.name = 'QuotaExceededError'; throw e; }
    this.values.set(key, String(value));
  }
  removeItem(key) { this.values.delete(key); }
}
function run(storage, request) {
  return JSON.parse(vm.runInNewContext(`(${script})(request)`, {localStorage: storage, request}, {timeout: 2000}));
}
function write(storage, value, backupValue) {
  const before = run(storage, {operation: 'read'});
  return run(storage, {operation: 'write', value, backup_value: backupValue,
    expected_primary: before.primary, expected_backup: before.backup});
}
function snapshot(storage) { return [...storage.values.entries()].sort(); }

test('read returns both independent namespace keys without touching old-client data', () => {
  const s = new Storage({[primary]: 'new-v2', [backup]: 'last-good', 'orafold_alpha_profile_v1.json': 'old'});
  const before = snapshot(s);
  assert.deepEqual(run(s, {operation: 'read'}), {ok: true, primary: 'new-v2', backup: 'last-good'});
  assert.deepEqual(snapshot(s), before);
});
test('first commit preserves the exact imported backup and writes primary synchronously', () => {
  const s = new Storage();
  assert.deepEqual(write(s, '{"version":2}', '{"version":1,"wins":17}'), {ok: true});
  assert.equal(s.getItem(primary), '{"version":2}');
  assert.equal(s.getItem(backup), '{"version":1,"wins":17}');
});
test('normal commit rotates previous primary to backup', () => {
  const s = new Storage({[primary]: 'old-current', [backup]: 'older-backup'});
  assert.deepEqual(write(s, 'next-current', 'old-current'), {ok: true});
  assert.equal(s.getItem(primary), 'next-current');
  assert.equal(s.getItem(backup), 'old-current');
});
test('primary quota failure restores an existing backup exactly', () => {
  const s = new Storage({[primary]: 'old-current', [backup]: 'older-backup'});
  const before = snapshot(s);
  s.fail = key => key === primary;
  assert.deepEqual(write(s, 'larger-next-current', 'old-current'), {ok: false, error: 'storage_full'});
  assert.deepEqual(snapshot(s), before);
});
test('primary quota failure removes a newly created backup, keeping no false commit', () => {
  const s = new Storage({[primary]: 'old-current'});
  const before = snapshot(s);
  s.fail = key => key === primary;
  assert.equal(write(s, 'next-current', 'old-current').ok, false);
  assert.deepEqual(snapshot(s), before);
});
test('backup quota failure leaves both original keys unchanged', () => {
  const s = new Storage({[primary]: 'old-current', [backup]: 'older-backup'});
  const before = snapshot(s);
  s.fail = key => key === backup;
  assert.deepEqual(write(s, 'next-current', 'old-current'), {ok: false, error: 'storage_full'});
  assert.deepEqual(snapshot(s), before);
});
test('changed storage between snapshot and transaction is rejected without writes', () => {
  const s = new Storage({[primary]: 'concurrently-newer', [backup]: 'last-good'});
  const before = snapshot(s);
  assert.deepEqual(run(s, {operation: 'write', value: 'stale', backup_value: 'old',
    expected_primary: 'old', expected_backup: 'last-good'}), {ok: false, error: 'storage_changed'});
  assert.deepEqual(snapshot(s), before);
});
test('unavailable browser storage returns a recoverable structured result', () => {
  const s = {getItem() { throw new Error('Injected unavailable localStorage'); }};
  assert.deepEqual(run(s, {operation: 'read'}), {ok: false, error: 'storage_unavailable'});
  assert.deepEqual(run(s, {operation: 'write', value: 'never-stored'}), {ok: false, error: 'storage_unavailable'});
});
test('an unavailable rollback is explicitly reported and never claims primary success', () => {
  const s = new Storage({[primary]: 'old-current', [backup]: 'older-backup'});
  let backupWrites = 0;
  s.fail = key => key === primary || key === backup && ++backupWrites > 1;
  assert.deepEqual(write(s, 'next-current', 'old-current'), {ok: false, error: 'backup_rollback_failed'});
  assert.equal(s.getItem(primary), 'old-current');
});
