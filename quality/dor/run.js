#!/usr/bin/env node
'use strict';

// CLI wrapper used by CI (and runnable locally):
//   node quality/dor/run.js                       -> reads the PR from $GITHUB_EVENT_PATH
//   node quality/dor/run.js --body pr.md --base origin/main --title "fix: x"   -> local dry run
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { evaluate, renderMarkdown } = require('./check');

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i > -1 ? process.argv[i + 1] : undefined;
}

function git(...args) {
  return execFileSync('git', args, { encoding: 'utf8' }).trim();
}

let title = arg('title') || '';
let body = '';
let base = arg('base');

if (arg('body')) {
  body = fs.readFileSync(arg('body'), 'utf8');
} else if (process.env.GITHUB_EVENT_PATH) {
  const event = JSON.parse(fs.readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8'));
  const pr = event.pull_request;
  if (!pr) {
    console.log('Not a pull_request event; nothing to check.');
    process.exit(0);
  }
  title = pr.title || '';
  body = pr.body || '';
  base = base || `origin/${pr.base.ref}`;
} else {
  console.error('Provide --body <file> or run inside a pull_request workflow.');
  process.exit(2);
}

const changedFiles = git('diff', '--name-only', `${base}...HEAD`).split('\n').filter(Boolean);
const result = evaluate({
  title,
  body,
  changedFiles,
  readFile: (p) => {
    const full = path.resolve(p);
    return fs.existsSync(full) ? fs.readFileSync(full, 'utf8') : null;
  },
});

const markdown = renderMarkdown(result);
console.log(markdown);
if (process.env.GITHUB_STEP_SUMMARY) fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${markdown}\n`);
process.exit(result.ok ? 0 : 1);
