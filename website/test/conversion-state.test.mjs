import test from 'node:test';
import assert from 'node:assert/strict';
import { createConversionController } from '../conversion-state.mjs';

function fixture() {
  const pending = [];
  const renders = [];
  let input = { sql: 'first', dialect: 'MySQL' };
  const controller = createConversionController({
    convert: (sql, dialect) => {
      const deferred = Promise.withResolvers();
      pending.push({ ...deferred, sql, dialect });
      return deferred.promise;
    },
    readInput: () => input,
    render: state => renders.push(state),
  });
  return { controller, pending, renders, state: () => renders.at(-1), change: next => { input = { ...input, ...next }; controller.invalidate(); } };
}
for (const rejectOlder of [false, true]) {
  test(`older ${rejectOlder ? 'error' : 'success'} cannot end a newer run's loading state`, async () => {
    const f = fixture();
    const first = f.controller.run();
    f.change({ sql: 'second', dialect: 'SQLite' });
    const second = f.controller.run();
    assert.deepEqual(f.pending.map(p => [p.sql, p.dialect]), [['first', 'MySQL'], ['second', 'SQLite']]);
    const before = f.renders.length;
    if (rejectOlder) f.pending[0].reject(new Error('stale error')); else f.pending[0].resolve('stale code');
    await first;
    assert.equal(f.renders.length, before);
    assert.deepEqual(f.state(), { busy: true, code: '', message: 'Converting…', error: false });
    f.pending[1].resolve('latest code'); await second;
    assert.equal(f.state().code, 'latest code'); assert.equal(f.state().busy, false);
  });
}
test('latest result remains when older work settles last', async () => {
  const f = fixture(); const first = f.controller.run();
  f.change({ sql: 'second' }); const second = f.controller.run();
  f.pending[1].resolve('latest'); await second;
  f.pending[0].reject(new Error('older')); await first;
  assert.equal(f.state().code, 'latest'); assert.equal(f.state().error, false);
});
test('changing SQL or dialect clears output and cancels the current loading state', async () => {
  for (const changed of [{ sql: 'changed' }, { dialect: 'PostgreSQL' }]) {
    const f = fixture(); const first = f.controller.run();
    f.change(changed);
    assert.equal(f.state().code, ''); assert.equal(f.state().busy, false);
    const before = f.renders.length;
    f.pending[0].resolve('obsolete'); await first;
    assert.equal(f.renders.length, before);
    const next = f.controller.run(); f.pending[1].resolve('new'); await next;
    f.change(changed); assert.equal(f.state().code, '');
  }
});
test('repeated shortcuts during the same run behave like a disabled Convert button', async () => {
  const f = fixture(); const first = f.controller.run();
  await f.controller.run(); await f.controller.run();
  assert.equal(f.pending.length, 1);
  f.pending[0].resolve('code'); await first;
});
test('parser failures leave no output and allow a retry', async () => {
  for (const error of [new Error('Parser failed'), 'Unexpected failure', null, { message: '' }]) {
    const f = fixture(); const first = f.controller.run();
    f.pending[0].reject(error); await first;
    assert.equal(f.state().busy, false); assert.equal(f.state().code, '');
    assert.equal(f.state().error, true); assert.ok(f.state().message);
    const next = f.controller.run(); f.pending[1].resolve('recovered'); await next;
    assert.equal(f.state().code, 'recovered'); assert.equal(f.state().error, false);
  }
});
test('synchronous parser exceptions also recover the controls', async () => {
  let state;
  const controller = createConversionController({ convert: () => { throw new Error('broken'); }, readInput: () => ({ sql: 'x', dialect: 'MySQL' }), render: value => { state = value; } });
  await controller.run();
  assert.equal(state.busy, false); assert.equal(state.error, true); assert.equal(state.message, 'broken');
});
