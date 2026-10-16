'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { checkSource } = require('./no-dev-token.cjs');

test('flags an unguarded read of the dev token', () => {
  const p = checkSource('return localStorage.getItem(K) ?? import.meta.env.VITE_DEV_TOKEN ?? null;', 'authAtom.ts');
  assert.equal(p.length, 1);
  assert.match(p[0], /authAtom\.ts:1/);
});

test('accepts a read guarded by import.meta.env.DEV on the same line', () => {
  assert.deepEqual(checkSource('const dev = import.meta.env.DEV ? import.meta.env.VITE_DEV_TOKEN : null;'), []);
});

test('ignores code that does not mention the token', () => {
  assert.deepEqual(checkSource('const x = 1;\nconst y = 2;'), []);
});
