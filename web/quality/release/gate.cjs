#!/usr/bin/env node
'use strict';

// Release gate: is this version releasable, yes or no, and why.
//
// It does not look at "do the tests pass" alone. A version is RELEASABLE only if
//   1. the whole quality net is green,
//   2. every P0 is fixed, and every P1 is fixed or carries a signed, unexpired risk acceptance (owner + reason + date),
//   3. the release notes name the version and disclose every P0/P1 that is not fixed,
//   4. someone recorded an end-to-end check of the live interview for exactly this version.
// Otherwise it is BLOCKED, and the reasons are listed. Nothing here is specific to one release.
const fs = require('fs');
const path = require('path');

// ---- parsing -----------------------------------------------------------------------------------------------

// Rows of assessment/traceability.md: | R-01 | P1 | spec | check | status |
function parseRegister(text) {
  const rows = [];
  for (const line of text.split(/\r?\n/)) {
    const c = line.split('|').map((x) => x.trim());
    if (c.length >= 6 && /^R-\d+$/.test(c[1]) && /^P[0-3]$/.test(c[2])) rows.push({ id: c[1], sev: c[2], status: c[5] });
  }
  return rows;
}

function stateOf(status) {
  const s = status.toLowerCase();
  if (s.startsWith('fixed')) return 'fixed';
  if (s.startsWith('mitigated') || s.startsWith('dimitigasi')) return 'mitigated';
  return 'open';
}

// Rows of assessment/risk-acceptances.md: | R-15 | owner | accepted until (YYYY-MM-DD) | reason |
function parseAcceptances(text) {
  const out = {};
  for (const line of text.split(/\r?\n/)) {
    const c = line.split('|').map((x) => x.trim());
    if (c.length >= 6 && /^R-\d+$/.test(c[1])) out[c[1]] = { owner: c[2], until: c[3], reason: c[4] };
  }
  return out;
}

function validAcceptance(a, today) {
  if (!a) return { ok: false, why: 'no risk acceptance recorded' };
  if (!a.owner || /^(tbd|todo|-|n\/a)$/i.test(a.owner)) return { ok: false, why: 'acceptance has no named owner' };
  if (!a.reason || a.reason.length < 20) return { ok: false, why: 'acceptance has no real reason' };
  const until = new Date(`${a.until}T23:59:59Z`);
  if (Number.isNaN(until.getTime())) return { ok: false, why: 'acceptance has no valid expiry date' };
  if (until < today) return { ok: false, why: `acceptance expired on ${a.until}` };
  return { ok: true, why: `accepted by ${a.owner} until ${a.until}` };
}

// ---- the decision ------------------------------------------------------------------------------------------

function evaluate({ tag, netResult, registerText, acceptancesText = '', notesText = '', e2eText = '', today = new Date() }) {
  const reasons = [];
  const accepted = [];
  const checks = [];

  if (!/^v\d+\.\d+\.\d+$/.test(tag || '')) reasons.push(`"${tag}" is not a version tag like v1.2.3`);

  checks.push(['Quality net (all CI jobs)', netResult === 'success' ? 'pass' : 'FAIL']);
  if (netResult !== 'success') reasons.push(`the quality net is not green (result: ${netResult || 'unknown'})`);

  const register = parseRegister(registerText);
  const severe = register.filter((r) => r.sev === 'P0' || r.sev === 'P1');
  if (severe.length === 0) reasons.push('the risk register has no P0/P1 rows: it cannot be read, so it cannot vouch for anything');
  const acceptances = parseAcceptances(acceptancesText);
  const undisclosed = [];

  for (const r of severe) {
    const state = stateOf(r.status);
    if (state === 'fixed') continue;
    if (r.sev === 'P0') {
      reasons.push(`${r.id} (P0) is not fixed; a P0 cannot be accepted`);
      continue;
    }
    const verdict = validAcceptance(acceptances[r.id], today);
    if (verdict.ok) accepted.push(`${r.id} (P1, ${state}): ${verdict.why}`);
    else reasons.push(`${r.id} (P1) is ${state} and ${verdict.why}`);
    if (!new RegExp(`\\b${r.id}\\b`).test(notesText)) undisclosed.push(r.id);
  }
  const fixedCount = severe.filter((r) => stateOf(r.status) === 'fixed').length;
  checks.push([`Risk register: P0/P1 fixed (${fixedCount}/${severe.length})`, fixedCount === severe.length ? 'pass' : 'FAIL']);

  if (!notesText.includes(tag || '\u0000')) reasons.push(`RELEASE_NOTES.md does not mention ${tag}`);
  if (undisclosed.length) reasons.push(`RELEASE_NOTES.md does not disclose open risk(s): ${undisclosed.join(', ')}`);
  checks.push(['Release notes name the version and disclose open risks', !notesText.includes(tag || '\u0000') || undisclosed.length ? 'FAIL' : 'pass']);

  const e2eOk = new RegExp(`^\\s*Version:\\s*${(tag || '').replace(/\./g, '\\.')}\\s*$`, 'mi').test(e2eText) && /^\s*Result:\s*pass\s*$/im.test(e2eText);
  checks.push(['End-to-end check of the live interview recorded for this version', e2eOk ? 'pass' : 'FAIL']);
  if (!e2eOk) reasons.push(`no end-to-end verification of the live interview is recorded for ${tag} (assessment/e2e-verification.md with "Version: ${tag}" and "Result: pass")`);

  return { status: reasons.length === 0 ? 'RELEASABLE' : 'BLOCKED', reasons, accepted, checks };
}

function render(tag, result) {
  const lines = [`## ${tag}: ${result.status}`, ''];
  lines.push(result.status === 'RELEASABLE' ? 'Every gate passed. This version may be released.' : 'This version must not be released until the reasons below are resolved.', '');
  lines.push('| Gate | Result |', '|---|---|', ...result.checks.map(([n, v]) => `| ${n} | ${v} |`), '');
  if (result.reasons.length) lines.push('### Why it is blocked', ...result.reasons.map((r) => `- ${r}`), '');
  if (result.accepted.length) lines.push('### Risks released with explicit acceptance', ...result.accepted.map((r) => `- ${r}`), '');
  return lines.join('\n');
}

module.exports = { evaluate, render, parseRegister, parseAcceptances, stateOf };

if (require.main === module) {
  const root = path.resolve(__dirname, '..', '..', '..');
  const read = (p) => (fs.existsSync(path.join(root, p)) ? fs.readFileSync(path.join(root, p), 'utf8') : '');
  const tag = process.env.TAG || process.argv[2];
  const result = evaluate({
    tag,
    netResult: process.env.NET_RESULT || process.argv[3] || 'unknown',
    registerText: read('assessment/traceability.md'),
    acceptancesText: read('assessment/risk-acceptances.md'),
    notesText: read('RELEASE_NOTES.md'),
    e2eText: read('assessment/e2e-verification.md'),
  });
  const markdown = render(tag, result);
  console.log(markdown);
  if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${markdown}\n`);
  if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, `status=${result.status}\n`);
  if (process.env.RELEASE_BODY_FILE) fs.writeFileSync(process.env.RELEASE_BODY_FILE, markdown);
  process.exit(result.status === 'RELEASABLE' ? 0 : 1);
}
