#!/usr/bin/env node
'use strict';

// A production bundle must never contain a login token (audit R-13).
// Rule: VITE_DEV_TOKEN may only be read in code that is stripped from production builds, i.e. on a line that
// also tests `import.meta.env.DEV`; and no committed .env.production* file may set it.
const fs = require('fs');
const path = require('path');

function checkSource(text, file = 'source') {
  const problems = [];
  text.split(/\r?\n/).forEach((line, i) => {
    if (/VITE_DEV_TOKEN/.test(line) && !/import\.meta\.env\.DEV/.test(line)) {
      problems.push(`${file}:${i + 1} reads VITE_DEV_TOKEN outside an import.meta.env.DEV guard`);
    }
  });
  return problems;
}

function walk(dir, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) walk(full, out);
    else if (/\.(ts|tsx|js|jsx)$/.test(e.name) && !/\.test\./.test(e.name)) out.push(full);
  }
  return out;
}

module.exports = { checkSource };

if (require.main === module) {
  const web = path.resolve(__dirname, '..', '..', 'web');
  const problems = [];
  for (const f of walk(path.join(web, 'src'))) problems.push(...checkSource(fs.readFileSync(f, 'utf8'), path.relative(web, f)));
  for (const f of fs.readdirSync(web).filter((n) => /^\.env\.production/.test(n))) {
    if (/^\s*VITE_DEV_TOKEN\s*=\s*\S+/m.test(fs.readFileSync(path.join(web, f), 'utf8'))) problems.push(`${f} sets VITE_DEV_TOKEN`);
  }
  if (process.env.NODE_ENV === 'production' && process.env.VITE_DEV_TOKEN) problems.push('VITE_DEV_TOKEN is set in the production build environment');
  if (problems.length) {
    console.error(`Dev-token check: ${problems.length} problem(s)\n  ${problems.join('\n  ')}`);
    process.exit(1);
  }
  console.log('Dev-token check: clean.');
}
