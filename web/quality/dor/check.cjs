'use strict';

// Definition-of-Ready / Definition-of-Done gate for a pull request.
//
// A change may not merge without its inputs:
//   1. a spec (a file in the repo, or a URL),
//   2. acceptance criteria written as Given / When / Then,
//   3. a short design / solution plan,
//   4. tests, whenever production code changed.
//
// Pure function: all I/O is injected, so the gate itself is unit-tested (check.test.cjs).

const PRODUCTION = [/^api\/(app|config|db|lib)\//, /^web\/src\//, /^web\/public\//, /^web\/quality\//];
const TESTS = [/^api\/spec\//, /^web\/src\/.*\.test\.(ts|tsx)$/, /^web\/src\/test\//, /^web\/quality\/.*\.test\.cjs$/];
const MIN_SPEC_CHARS = 200;
const MIN_PLAN_CHARS = 120;
const PLACEHOLDER = /^(tbd|todo|n\/?a|none|-+|\.\.\.|to be (decided|done|written))\.?$/i;

function stripComments(text) {
  return text.replace(/<!--[\s\S]*?-->/g, '').trim();
}

// Splits a PR body into { "section heading (lower-case)": "content" } on "## Heading" lines.
function sections(body) {
  const out = {};
  let current = null;
  for (const line of String(body || '').split(/\r?\n/)) {
    const m = /^##\s+(.+?)\s*$/.exec(line);
    if (m) {
      current = m[1].toLowerCase();
      // A heading can appear twice: GitHub fills a pull request with the commit message and then appends the
      // template. Content of repeated headings is joined, so an empty copy never hides the filled one.
      if (!(current in out)) out[current] = '';
    } else if (current) {
      out[current] += `${line}\n`;
    }
  }
  for (const k of Object.keys(out)) out[k] = stripComments(out[k]);
  return out;
}

function isPlaceholder(text) {
  const t = stripComments(text).replace(/^[-*]\s*/gm, '').trim();
  return t === '' || PLACEHOLDER.test(t);
}

function hasGivenWhenThen(text) {
  return /\bgiven\b[\s\S]*?\bwhen\b[\s\S]*?\bthen\b/i.test(text);
}

function matchesAny(file, patterns) {
  return patterns.some((p) => p.test(file));
}

// Returns the repo path or URL the "Spec" section points at, or null.
function specReference(specSection) {
  const url = /https?:\/\/\S+/.exec(specSection);
  if (url) return { type: 'url', value: url[0].replace(/[).,]+$/, '') };
  const file = /(?:^|[\s`(\[])((?:docs|assessment|api|web)\/[\w./-]+\.md)\b/.exec(specSection);
  if (file) return { type: 'file', value: file[1] };
  return null;
}

/**
 * @param {object} input
 * @param {string} input.title
 * @param {string} input.body
 * @param {string[]} input.changedFiles  repo-relative paths changed by the PR
 * @param {(path: string) => string|null} input.readFile  returns file content at the PR head, or null if missing
 */
function evaluate({ title = '', body = '', changedFiles = [], readFile = () => null }) {
  const failures = [];
  const warnings = [];
  const s = sections(body);

  const production = changedFiles.filter((f) => matchesAny(f, PRODUCTION) && !matchesAny(f, TESTS));
  const tests = changedFiles.filter((f) => matchesAny(f, TESTS));

  // 1. Spec ------------------------------------------------------------------------------------------------
  let specText = '';
  const specSection = s['spec'] || '';
  if (isPlaceholder(specSection)) {
    failures.push('Spec: link the spec or PRD this change implements (a file under assessment/specs/ or a URL).');
  } else {
    const ref = specReference(specSection);
    if (!ref) {
      failures.push('Spec: could not find a link. Use a repo path like assessment/specs/SPEC-001-xxx.md or an https:// URL.');
    } else if (ref.type === 'file') {
      const content = readFile(ref.value);
      if (content === null) failures.push(`Spec: ${ref.value} does not exist in this branch.`);
      else if (content.trim().length < MIN_SPEC_CHARS) failures.push(`Spec: ${ref.value} is a stub (under ${MIN_SPEC_CHARS} characters).`);
      else specText = content;
    }
  }

  // 2. Acceptance criteria -----------------------------------------------------------------------------------
  const acSection = s['acceptance criteria'] || '';
  if (!(hasGivenWhenThen(acSection) || hasGivenWhenThen(specText))) {
    failures.push('Acceptance criteria: write at least one scenario as Given / When / Then (in the PR or in the linked spec).');
  }

  // 3. Design / solution plan --------------------------------------------------------------------------------
  const plan = s['design plan'] || '';
  if (isPlaceholder(plan) || plan.replace(/\s+/g, ' ').length < MIN_PLAN_CHARS) {
    failures.push(`Design plan: describe the approach in at least ${MIN_PLAN_CHARS} characters (what changes, why this way, what you rejected).`);
  }

  // 4. Tests -------------------------------------------------------------------------------------------------
  if (production.length > 0 && tests.length === 0) {
    failures.push(
      `Tests: ${production.length} production file(s) changed (e.g. ${production[0]}) but no test file changed. ` +
        'Add or update a spec under api/spec/ or a *.test.ts(x) under web/src/.'
    );
  }

  // Soft signals - reported, never blocking, so the gate does not become bureaucracy.
  if (!/\bR-\d+\b/.test(`${title}\n${body}`) && /^(fix|feat)/i.test(title)) {
    warnings.push('Traceability: mention the audit item(s) this closes (e.g. R-01) so the matrix stays complete.');
  }
  if (changedFiles.length === 0) warnings.push('No changed files were detected; is the base branch fetched?');

  return { ok: failures.length === 0, failures, warnings, production, tests };
}

function renderMarkdown(result) {
  const lines = [];
  lines.push(result.ok ? '### Definition of Ready: PASSED' : '### Definition of Ready: BLOCKED');
  lines.push('');
  if (result.failures.length) {
    lines.push('This change cannot merge until:');
    for (const f of result.failures) lines.push(`- ${f}`);
    lines.push('');
  }
  if (result.warnings.length) {
    lines.push('Notes (not blocking):');
    for (const w of result.warnings) lines.push(`- ${w}`);
    lines.push('');
  }
  lines.push(`Production files changed: ${result.production.length} | test files changed: ${result.tests.length}`);
  return lines.join('\n');
}

module.exports = { evaluate, sections, hasGivenWhenThen, specReference, renderMarkdown, PRODUCTION, TESTS };
