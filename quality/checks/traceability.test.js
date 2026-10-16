'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { evaluate, severeAuditIds } = require('./traceability');

const audit = ['### P0 - blocker', '| R-31 | BW | x |', '### P1 - major', '| R-01 | BW | y |', '| R-02 | BW | z |', '### P2 - minor', '| R-16 | BW | w |'].join('\n');
const trace = (rows) => ['| Audit | Sev | Spec | Check | Status |', '|---|---|---|---|---|', ...rows].join('\n');
const exists = (p) => p.startsWith('ok/');

test('only P0 and P1 rows are required', () => {
  assert.deepEqual(severeAuditIds(audit), ['R-31', 'R-01', 'R-02']);
});

test('passes when every severe item has an existing spec and check', () => {
  const t = trace(['| R-31 | P0 | ok/s.md | ok/c.rb | open |', '| R-01 | P1 | ok/s.md | ok/c.rb | open |', '| R-02 | P1 | ok/s.md | none: needs a socket-level test | open |']);
  assert.deepEqual(evaluate({ auditText: audit, traceText: t, exists }), []);
});

test('BLOCKS an audit item that is missing from the matrix', () => {
  const t = trace(['| R-31 | P0 | ok/s.md | ok/c.rb | open |', '| R-01 | P1 | ok/s.md | ok/c.rb | open |']);
  assert.match(evaluate({ auditText: audit, traceText: t, exists }).join('\n'), /R-02.*missing/);
});

test('BLOCKS a spec or check that does not exist, and a gap without a reason', () => {
  const t = trace(['| R-31 | P0 | nope.md | ok/c.rb | open |', '| R-01 | P1 | ok/s.md | gone.rb | open |', '| R-02 | P1 | ok/s.md | none: x | open |']);
  const out = evaluate({ auditText: audit, traceText: t, exists }).join('\n');
  assert.match(out, /R-31: spec/);
  assert.match(out, /R-01: check/);
  assert.match(out, /R-02: a disclosed gap needs a reason/);
});
