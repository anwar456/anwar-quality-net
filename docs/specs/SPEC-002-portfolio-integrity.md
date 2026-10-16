# SPEC-002 - A rating is derived from the interview and our own records

Audit items: R-04, R-05, R-11
Status: accepted

## Problem
The portfolio generator stores whatever skill id, label, level and confidence the LLM returned. A missing level
becomes L1 silently, confidence is not computed by the rule in PRD 01, partial results are persisted when a later
skill is invalid, an interview with no transcript is still rated, and fit/gap fails to match skills whose stored id
differs in case from the configured one.

## Rules
1. The identity (skill id and label) of a configured skill's rating is copied from the assessment's configured skill that the LLM output refers to; LLM text is only used to find that skill (case- and whitespace-insensitive on the id).
2. `level` must be an integer 1..5. Anything else makes the whole generation fail; it is never clamped or defaulted.
3. `confidence` is computed: high = covered and probe_count >= 3; medium = probe_count = 2 or partial; low = probe_count <= 1 or initiated. The LLM's confidence is ignored.
4. Generation is all-or-nothing: if any skill is invalid, no portfolio skill is stored and the portfolio is marked failed with the reason.
5. An interview with no transcript, or whose turn numbers have a gap, is not rated; the portfolio is marked failed ("transcript incomplete").
6. Fit/gap matches a requirement to a rated skill by normalised id first, then by case-insensitive label.

## Acceptance criteria
Given a finished interview with a complete transcript and a coverage map
When the LLM answers with a different id/label casing for a configured skill
Then the stored portfolio skill carries the configured id and label.

Given an LLM answer with a missing, zero or out-of-range level
When the portfolio is generated
Then generation fails, the portfolio is failed and no skill is stored.

Given a skill that is partial with 2 probes
When the LLM says its confidence is high
Then the stored confidence is medium.

Given an interview whose transcript is empty or has missing turns
When the portfolio is generated
Then it is marked failed and nothing is stored.

## Out of scope
Whether the LLM's level is a good judgement; retry policy of the job.

## Checks
api/spec/critical/portfolio_generation_spec.rb, api/spec/critical/fit_gap_spec.rb
