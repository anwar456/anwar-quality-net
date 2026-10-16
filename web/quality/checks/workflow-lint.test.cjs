'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { lint } = require('./workflow-lint.cjs');

test('flags a single-line run that YAML would cut at " #"', () => {
  const p = lint(`        run: bundle exec rails runner 'puts "booted in #{Rails.env}"'`, 'ci.yml');
  assert.equal(p.length, 1);
  assert.match(p[0], /ci\.yml:1/);
});

test('accepts the same command as a block scalar', () => {
  assert.deepEqual(lint(['        run: |', `          bundle exec rails runner 'puts "booted in #{Rails.env}"'`].join('\n')), []);
});

test('accepts a "#" that is not preceded by a space, and ordinary commands', () => {
  assert.deepEqual(lint('        run: echo a#b'), []);
  assert.deepEqual(lint('        run: npm ci'), []);
});

test('the real workflows are clean', () => {
  const fs = require('fs');
  const path = require('path');
  const dir = path.resolve(__dirname, '..', '..', '..', '.github', 'workflows');
  for (const f of fs.readdirSync(dir)) assert.deepEqual(lint(fs.readFileSync(path.join(dir, f), 'utf8'), f), []);
});
