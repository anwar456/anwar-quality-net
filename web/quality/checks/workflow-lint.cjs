#!/usr/bin/env node
'use strict';

// A single-line `run:` is a YAML plain scalar, and YAML starts a comment at " #". A command such as
//   run: rails runner 'puts "in #{x}"'
// is silently cut at " #" and the shell then fails on the unbalanced quote. Valid YAML, wrong command.
// Rule: a `run:` whose command contains " #" must use a block scalar (`run: |`).
const fs = require('fs');
const path = require('path');

function lint(text, file = 'workflow') {
  const problems = [];
  text.split(/\r?\n/).forEach((line, i) => {
    const m = /^\s*(?:-\s+)?run:\s+(?![|>])(.+)$/.exec(line);
    if (m && /\s#/.test(m[1])) problems.push(`${file}:${i + 1} single-line run contains " #", YAML will cut the command there; use "run: |"`);
  });
  return problems;
}

module.exports = { lint };

if (require.main === module) {
  const dir = path.resolve(__dirname, '..', '..', '..', '.github', 'workflows');
  const problems = fs.readdirSync(dir).filter((f) => /\.ya?ml$/.test(f)).flatMap((f) => lint(fs.readFileSync(path.join(dir, f), 'utf8'), f));
  if (problems.length) {
    console.error(`Workflow lint: ${problems.length} problem(s)\n  ${problems.join('\n  ')}`);
    process.exit(1);
  }
  console.log('Workflow lint: clean.');
}
