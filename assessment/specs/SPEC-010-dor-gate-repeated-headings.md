# SPEC-010 - The Definition of Ready gate reads a pull request body as written

Audit items: none (found by using the gate on a real pull request)
Status: accepted

## Problem
GitHub fills a new pull request with the commit message when the branch has one commit, and then appends the
repository's template below it. The gate split the body at each `## Heading` and kept the last occurrence of a
heading, so the empty template section below the author's filled section replaced it: a pull request that
carried every input in its commit message would have been reported as carrying none. Found while looking at why
a real pull request, opened with the auto-filled body, was blocked. That block was correct (its commit message had
no sections, so the template stayed empty), but it showed that a body can contain a heading twice and that the
last copy won.

## Rules
1. If a heading appears more than once in the body, the content under all of its occurrences is joined, in order.
2. An empty or placeholder occurrence therefore never hides a filled one, and a filled occurrence is never required to be the last.
3. A body whose every occurrence of a required heading is empty or a placeholder is still blocked.

## Acceptance criteria
Given a pull request body with a filled Spec, Acceptance criteria and Design plan, followed by the empty template
When the Definition of Ready check runs
Then it passes.

Given a pull request body that contains only the empty template, twice
When the Definition of Ready check runs
Then it is blocked, with one reason for the spec, one for the acceptance criteria and one for the design plan.

## Out of scope
Judging whether the spec or the plan is any good; the gate only checks that they exist and are not placeholders.

## Checks
web/quality/dor/check.test.cjs
