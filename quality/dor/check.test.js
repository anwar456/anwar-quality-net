'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { evaluate, sections, specReference } = require('./check');

const SPEC = `# Spec\n${'A real spec has real content. '.repeat(12)}\nGiven a signed-in assessor\nWhen they open another tenant's portfolio\nThen they get 404.`;
const files = { 'docs/specs/SPEC-001-tenancy.md': SPEC, 'docs/specs/stub.md': '# todo' };
const readFile = (p) => (p in files ? files[p] : null);

const goodBody = `## Spec
docs/specs/SPEC-001-tenancy.md

## Acceptance criteria
Given an assessor of tenant A
When they request a portfolio of tenant B
Then the API answers 404

## Design plan
Scope Portfolio lookups through the session, which is already tenant scoped, instead of adding a tenant column.
Rejected: a default_scope on Portfolio, because workers run without a tenant and would silently see everything.

## Tests
api/spec/critical/tenant_isolation_spec.rb
`;

const withTests = ['api/app/controllers/api/v1/portfolios_controller.rb', 'api/spec/critical/tenant_isolation_spec.rb'];

test('a change that carries all its inputs passes', () => {
  const r = evaluate({ title: 'fix: tenant isolation (R-01)', body: goodBody, changedFiles: withTests, readFile });
  assert.equal(r.ok, true, r.failures.join('\n'));
});

test('BLOCKS a change with no spec', () => {
  const body = goodBody.replace('docs/specs/SPEC-001-tenancy.md', 'TBD');
  const r = evaluate({ title: 'fix: x', body, changedFiles: withTests, readFile });
  assert.equal(r.ok, false);
  assert.match(r.failures.join('\n'), /Spec:/);
});

test('BLOCKS a spec that points at a file which does not exist', () => {
  const body = goodBody.replace('SPEC-001-tenancy', 'SPEC-404-missing');
  const r = evaluate({ title: 'fix: x', body, changedFiles: withTests, readFile });
  assert.match(r.failures.join('\n'), /does not exist/);
});

test('BLOCKS a spec that is only a stub', () => {
  const body = goodBody.replace('SPEC-001-tenancy', 'stub');
  const r = evaluate({ title: 'fix: x', body, changedFiles: withTests, readFile });
  assert.match(r.failures.join('\n'), /stub/);
});

test('BLOCKS a change with no acceptance criteria anywhere', () => {
  const body = goodBody.replace(/## Acceptance criteria[\s\S]*?## Design plan/, '## Acceptance criteria\n\n## Design plan');
  const spec = SPEC.replace(/Given[\s\S]*$/, 'No scenarios here.');
  const r = evaluate({ title: 'fix: x', body, changedFiles: withTests, readFile: (p) => (p.endsWith('tenancy.md') ? spec : null) });
  assert.match(r.failures.join('\n'), /Acceptance criteria/);
});

test('accepts acceptance criteria that live in the linked spec', () => {
  const body = goodBody.replace(/## Acceptance criteria[\s\S]*?## Design plan/, '## Acceptance criteria\nSee spec.\n\n## Design plan');
  const r = evaluate({ title: 'fix: x', body, changedFiles: withTests, readFile });
  assert.equal(r.ok, true, r.failures.join('\n'));
});

test('BLOCKS a change with no design plan, or a placeholder one', () => {
  for (const plan of ['', 'TBD', 'N/A', 'fix it']) {
    const body = goodBody.replace(/## Design plan[\s\S]*?## Tests/, `## Design plan\n${plan}\n\n## Tests`);
    const r = evaluate({ title: 'fix: x', body, changedFiles: withTests, readFile });
    assert.match(r.failures.join('\n'), /Design plan/, `plan "${plan}" should be rejected`);
  }
});

test('BLOCKS production code with no test change', () => {
  const r = evaluate({ title: 'fix: x', body: goodBody, changedFiles: ['api/app/models/session.rb'], readFile });
  assert.equal(r.ok, false);
  assert.match(r.failures.join('\n'), /Tests:/);
});

test('web production code is also covered', () => {
  const r = evaluate({ title: 'fix: x', body: goodBody, changedFiles: ['web/src/components/fitgap/ComparisonTable.tsx'], readFile });
  assert.match(r.failures.join('\n'), /Tests:/);
});

test('a docs/tooling-only change does not need tests but still needs its inputs', () => {
  const r = evaluate({ title: 'docs: audit', body: goodBody, changedFiles: ['assessment/01-audit.md', '.github/workflows/ci.yml'], readFile });
  assert.equal(r.ok, true, r.failures.join('\n'));
  const noInputs = evaluate({ title: 'docs: audit', body: '', changedFiles: ['assessment/01-audit.md'], readFile });
  assert.equal(noInputs.ok, false);
});

test('an empty template (only comments) is blocked', () => {
  const body = '## Spec\n<!-- link -->\n\n## Acceptance criteria\n<!-- g/w/t -->\n\n## Design plan\n<!-- plan -->\n';
  const r = evaluate({ title: 'feat: x', body, changedFiles: withTests, readFile });
  assert.equal(r.ok, false);
  assert.equal(r.failures.length, 3);
});

test('helpers', () => {
  assert.deepEqual(Object.keys(sections('## A\nx\n## B\ny')), ['a', 'b']);
  assert.deepEqual(specReference('see https://example.test/spec).'), { type: 'url', value: 'https://example.test/spec' });
  assert.equal(specReference('nothing here'), null);
});
