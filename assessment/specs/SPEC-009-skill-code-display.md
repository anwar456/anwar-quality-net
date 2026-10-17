# SPEC-009 - A skill's code is shown once, as stored

Audit items: none (found while using the app; a cosmetic P3 that also serves as the demonstration of the PR gate)
Status: accepted

## Problem
The skill card shows a short code next to the skill name. Taxonomy skills already carry ids such as `SK-ENG-001`,
but the card pads whatever it receives and prefixes it with `SK-` again, so the screen shows `SK-SK-ENG-001`. The
card was written when skill ids were numbers.

## Rules
1. A taxonomy id (a string that already starts with a letter) is shown exactly as stored.
2. A numeric id (a number, or a string of digits, as in older data) is shown as `SK-` followed by the number padded to three digits.
3. A missing id shows nothing. A custom skill shows "Custom" (unchanged).

## Acceptance criteria
Given a skill from the taxonomy with the id SK-ENG-001
When its card is shown
Then the code reads SK-ENG-001, not SK-SK-ENG-001.

Given an older skill whose id is the number 7
When its card is shown
Then the code reads SK-007.

Given a skill with no id
When its card is shown
Then no code is shown.

## Out of scope
Renaming ids, or changing how custom skills are labelled.

## Checks
web/src/lib/skillCode.test.ts
