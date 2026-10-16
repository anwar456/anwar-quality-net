'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { scanText, sha } = require('./identifiers.cjs');

const hashes = new Set([sha('acme'), sha('acmedev')]);

test('finds an identifier in prose, in a hostname and in a hyphenated name, any case', () => {
  const text = ['Welcome to Acme', 'host: api.ACME.example.com', 'image: registry/acme-poc/app', 'clean line'].join('\n');
  assert.deepEqual(scanText(text, hashes).map((h) => h.line), [1, 2, 3]);
});

test('finds a registered variant but does not flag words that merely contain the term', () => {
  assert.equal(scanText('github.com/acmedev/repo', hashes).length, 1);
  assert.equal(scanText('acmeology is not acme', hashes).length, 1); // only the standalone "acme"
});

test('does not echo the term itself, only its position in the list', () => {
  const [hit] = scanText('x acme', hashes);
  assert.deepEqual(Object.keys(hit).sort(), ['column', 'line', 'term']);
  assert.equal(hit.term, 1);
});

test('the shipped list contains hashes only', () => {
  const fs = require('fs');
  const path = require('path');
  const lines = fs.readFileSync(path.join(__dirname, 'forbidden-terms.sha256'), 'utf8').split(/\r?\n/).filter((l) => l && !l.startsWith('#'));
  assert.ok(lines.length > 0);
  for (const l of lines) assert.match(l, /^[0-9a-f]{64}$/);
});
