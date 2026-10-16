#!/usr/bin/env node
'use strict';

// Every P0/P1 item of the audit must be traced to a spec and to a check (or to an explicitly disclosed gap).
// Nothing can be dropped from the register without this going red.
const fs = require('fs');
const path = require('path');

// Audit ids that are P0/P1: table rows (`| R-NN |`) located under a "### P0" or "### P1" heading.
function severeAuditIds(auditText) {
  const ids = [];
  let inSevere = false;
  for (const line of auditText.split(/\r?\n/)) {
    const h = /^###\s+(P\d)/.exec(line);
    if (h) inSevere = h[1] === 'P0' || h[1] === 'P1';
    const row = /^\|\s*(R-\d+)\s*\|/.exec(line);
    if (inSevere && row) ids.push(row[1]);
  }
  return ids;
}

function parseTraceability(text) {
  const rows = {};
  for (const line of text.split(/\r?\n/)) {
    const cells = line.split('|').map((c) => c.trim());
    if (cells.length >= 6 && /^R-\d+$/.test(cells[1])) rows[cells[1]] = { sev: cells[2], spec: cells[3], check: cells[4], status: cells[5] };
  }
  return rows;
}

function evaluate({ auditText, traceText, exists }) {
  const problems = [];
  const rows = parseTraceability(traceText);
  for (const id of severeAuditIds(auditText)) {
    const row = rows[id];
    if (!row) {
      problems.push(`${id}: P0/P1 in the audit but missing from docs/traceability.md`);
      continue;
    }
    if (!exists(row.spec)) problems.push(`${id}: spec ${row.spec} does not exist`);
    if (row.check.startsWith('none:')) {
      if (row.check.length < 20) problems.push(`${id}: a disclosed gap needs a reason`);
    } else if (!exists(row.check)) {
      problems.push(`${id}: check ${row.check} does not exist`);
    }
  }
  return problems;
}

module.exports = { evaluate, severeAuditIds, parseTraceability };

if (require.main === module) {
  const root = path.resolve(__dirname, '..', '..');
  const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');
  const problems = evaluate({
    auditText: read('assessment/01-audit.md'),
    traceText: read('docs/traceability.md'),
    exists: (p) => fs.existsSync(path.join(root, p)),
  });
  if (problems.length) {
    console.error(`Traceability: ${problems.length} problem(s)\n  ${problems.join('\n  ')}`);
    process.exit(1);
  }
  console.log('Traceability: every P0/P1 audit item has a spec and a check (or a disclosed gap).');
}
