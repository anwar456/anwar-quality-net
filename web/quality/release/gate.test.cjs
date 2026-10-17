'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { evaluate, stateOf } = require('./gate.cjs');

const register = (rows) => ['| Audit | Sev | Spec | Check | Status |', '|---|---|---|---|---|', ...rows].join('\n');
const allFixed = register(['| R-01 | P1 | s.md | c.rb | fixed |', '| R-31 | P0 | s.md | c.rb | fixed |', '| R-20 | P2 | s.md | c.rb | open |']);
const NOTES = '# v1.0.0\nWhat this version delivers.';
const E2E = 'Version: v1.0.0\nResult: pass\n';
const NOW = new Date('2026-10-16T10:00:00Z');
const base = { tag: 'v1.0.0', netResult: 'success', registerText: allFixed, notesText: NOTES, e2eText: E2E, today: NOW };

test('is RELEASABLE only when every gate passes', () => {
  const r = evaluate(base);
  assert.equal(r.status, 'RELEASABLE', r.reasons.join('\n'));
});

test('BLOCKED when the quality net is not green', () => {
  const r = evaluate({ ...base, netResult: 'failure' });
  assert.equal(r.status, 'BLOCKED');
  assert.match(r.reasons.join('\n'), /quality net is not green/);
});

test('BLOCKED by an open P1 with no acceptance, even though all tests are green', () => {
  const r = evaluate({ ...base, registerText: register(['| R-15 | P1 | s.md | c.rb | open: consent is not specified |']), notesText: `${NOTES}\nKnown: R-15` });
  assert.equal(r.status, 'BLOCKED');
  assert.match(r.reasons.join('\n'), /R-15 \(P1\) is open and no risk acceptance/);
});

test('a "mitigated" P1 is not "fixed": it still needs an acceptance', () => {
  assert.equal(stateOf('mitigated by the gate'), 'mitigated');
  assert.equal(stateOf('dimitigasi'), 'mitigated');
  assert.equal(stateOf('fixed (fake socket)'), 'fixed');
  const r = evaluate({ ...base, registerText: register(['| R-15 | P1 | s.md | c.rb | mitigated |']), notesText: `${NOTES} R-15` });
  assert.equal(r.status, 'BLOCKED');
});

test('an open P1 can be released with a named owner, a real reason and an unexpired date, if the notes disclose it', () => {
  const acceptances = '| Audit | Owner | Until | Reason |\n|---|---|---|---|\n| R-15 | A. Owner | 2026-12-31 | Pilot with two internal users only; consent text is handled by hand. |';
  const reg = register(['| R-15 | P1 | s.md | c.rb | open |']);
  const ok = evaluate({ ...base, registerText: reg, acceptancesText: acceptances, notesText: `${NOTES}\nKnown limitation R-15` });
  assert.equal(ok.status, 'RELEASABLE', ok.reasons.join('\n'));
  assert.match(ok.accepted.join('\n'), /accepted by A\. Owner until 2026-12-31/);

  const undisclosed = evaluate({ ...base, registerText: reg, acceptancesText: acceptances });
  assert.match(undisclosed.reasons.join('\n'), /does not disclose open risk\(s\): R-15/);
});

test('an acceptance without an owner, without a reason or past its date does not count', () => {
  const reg = register(['| R-15 | P1 | s.md | c.rb | open |']);
  const notes = `${NOTES} R-15`;
  const mk = (row) => evaluate({ ...base, registerText: reg, notesText: notes, acceptancesText: `| Audit | Owner | Until | Reason |\n|---|---|---|---|\n${row}` });
  assert.match(mk('| R-15 | TBD | 2026-12-31 | Pilot with two internal users only, by hand. |').reasons.join('\n'), /no named owner/);
  assert.match(mk('| R-15 | A. Owner | 2026-12-31 | ok |').reasons.join('\n'), /no real reason/);
  assert.match(mk('| R-15 | A. Owner | 2026-01-01 | Pilot with two internal users only, by hand. |').reasons.join('\n'), /expired on 2026-01-01/);
});

test('a P0 can never be accepted', () => {
  const acceptances = '| R-31 | A. Owner | 2026-12-31 | We would like to ship anyway, please. |';
  const r = evaluate({ ...base, registerText: register(['| R-31 | P0 | s.md | c.rb | open |']), acceptancesText: acceptances, notesText: `${NOTES} R-31` });
  assert.equal(r.status, 'BLOCKED');
  assert.match(r.reasons.join('\n'), /a P0 cannot be accepted/);
});

test('BLOCKED without an end-to-end record for exactly this version', () => {
  assert.equal(evaluate({ ...base, e2eText: '' }).status, 'BLOCKED');
  assert.equal(evaluate({ ...base, e2eText: 'Version: v0.9.0\nResult: pass' }).status, 'BLOCKED');
  assert.equal(evaluate({ ...base, e2eText: 'Version: v1.0.0\nResult: fail' }).status, 'BLOCKED');
});

test('BLOCKED when the notes do not mention the version, or the register is unreadable', () => {
  assert.match(evaluate({ ...base, notesText: 'nothing' }).reasons.join('\n'), /does not mention v1\.0\.0/);
  assert.match(evaluate({ ...base, registerText: 'garbage' }).reasons.join('\n'), /cannot be read/);
});

test('BLOCKED for a tag that is not a version', () => {
  assert.equal(evaluate({ ...base, tag: 'latest' }).status, 'BLOCKED');
});
