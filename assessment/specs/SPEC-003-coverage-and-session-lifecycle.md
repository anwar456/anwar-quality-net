# SPEC-003 - Coverage means evidence; a session ends for a recorded, true reason

Audit items: R-06, R-09 (R-12 tracked, not yet checked)
Known consequence of rule 1: a partial skill that left the analyzer's 6-turn window is not re-evaluated, so an interview may run to its time limit instead of ending early. Accepted; follow-up is to give the analyzer more context for partial skills.
Status: accepted

## Problem
Partial skills are promoted to "covered" once probe_count reaches 4 without any evidence check, and the public
`audio_complete` endpoint ends any session, including one that never started, recording it as `all_covered`.

## Rules
1. A skill becomes covered only through the analyzer's decision, subject to the state machine (forward only, two probes before leaving "initiated"). No job promotes a skill by counting probes alone.
2. `POST /sessions/:token/audio_complete` ends a session only if it is active and every configured skill is covered; otherwise it answers 409 and changes nothing. Ending an already ended session stays idempotent (200).
3. `end_reason` states what actually happened.

## Acceptance criteria
Given a partial skill with 5 probes
When the coverage analyzer job runs and reports no change
Then the skill is still partial.

Given a session that never started
When the candidate endpoint audio_complete is called with its token
Then the answer is 409, the session is still pending and no portfolio exists.

Given an active session with one open configured skill
When audio_complete is called
Then the answer is 409 and the session is still active.

Given an active session whose configured skills are all covered
When audio_complete is called
Then the session is ended with reason all_covered.

## Out of scope
Closing the live audio connection when an assessor ends a session (R-12) - needs a socket-level test.

## Checks
api/spec/critical/coverage_spec.rb, api/spec/critical/session_lifecycle_spec.rb
