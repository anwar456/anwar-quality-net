#!/usr/bin/env node
'use strict';

// Confidentiality gate: fails when a tracked file (or its path) contains an identifier from the forbidden list
// (company, product or client names). The list holds SHA-256 hashes, so the names are not written in the repo.
//
//   node quality/scan/identifiers.js            scan every git-tracked file
//   node quality/scan/identifiers.js --hash x   print the line to add for term "x"
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const sha = (s) => crypto.createHash('sha256').update(s.toLowerCase()).digest('hex');
const SKIP = /(^|\/)(node_modules|\.git|dist)\/|package-lock\.json$|Gemfile\.lock$|\.(png|jpe?g|gif|ico|pdf|woff2?)$/i;

function loadHashes(file) {
  return new Set(
    fs.readFileSync(file, 'utf8').split(/\r?\n/).map((l) => l.trim()).filter((l) => l && !l.startsWith('#'))
  );
}

// Returns [{ line, column, term }] where `term` is the 1-based index of the matching hash in the list.
function scanText(text, hashes) {
  const order = [...hashes];
  const hits = [];
  text.split(/\r?\n/).forEach((line, i) => {
    const re = /[A-Za-z0-9]+/g;
    let m;
    while ((m = re.exec(line))) {
      const idx = order.indexOf(sha(m[0]));
      if (idx > -1) hits.push({ line: i + 1, column: m.index + 1, term: idx + 1 });
    }
  });
  return hits;
}

function scanRepo(root, hashes) {
  const files = execFileSync('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard'], { cwd: root, encoding: 'utf8' })
    .split('\0')
    .filter(Boolean);
  const findings = [];
  for (const f of files) {
    if (SKIP.test(f)) continue;
    const full = path.join(root, f);
    if (!fs.existsSync(full)) continue;
    for (const h of scanText(f, hashes)) findings.push({ file: f, line: 0, column: h.column, term: h.term, where: 'path' });
    let text;
    try {
      text = fs.readFileSync(full, 'utf8');
    } catch {
      continue;
    }
    if (text.includes('\u0000')) continue; // binary
    for (const h of scanText(text, hashes)) findings.push({ file: f, line: h.line, column: h.column, term: h.term, where: 'content' });
  }
  return findings;
}

module.exports = { scanText, scanRepo, loadHashes, sha };

if (require.main === module) {
  if (process.argv[2] === '--hash') {
    console.log(sha(String(process.argv[3] || '')));
    process.exit(0);
  }
  const root = path.resolve(__dirname, '..', '..');
  const hashes = loadHashes(path.join(__dirname, 'forbidden-terms.sha256'));
  const findings = scanRepo(root, hashes);
  if (findings.length === 0) {
    console.log(`Confidentiality scan: clean (${hashes.size} forbidden identifiers checked).`);
    process.exit(0);
  }
  const byFile = new Map();
  for (const f of findings) byFile.set(f.file, (byFile.get(f.file) || 0) + 1);
  console.error(`Confidentiality scan: ${findings.length} forbidden identifier(s) in ${byFile.size} file(s).`);
  for (const [file, n] of [...byFile].slice(0, 60)) console.error(`  ${file}: ${n}`);
  if (byFile.size > 60) console.error(`  ... and ${byFile.size - 60} more files`);
  console.error('Replace them with neutral placeholders (example.com, <registry>, <org>) before publishing.');
  process.exit(1);
}
