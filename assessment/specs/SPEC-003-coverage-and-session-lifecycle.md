# SPEC-003 - Coverage means evidence; a session ends for a recorded, true reason

Audit items: R-06, R-09, R-12
Known consequence of rule 1: a partial skill that left the analyzer's 6-turn window is not re-evaluated, so an interview may run to its time limit instead of ending early. Accepted; follow-up is to give the analyzer more context for partial skills.
Status: accepted

## Problem
Partial skills are promoted to "covered" once probe_count reaches 4 without any evidence check, and the public
`audio_complete` endpoint ends any session, including one that never started, recording it as `all_covered`.

## Rules
1. A skill becomes covered only through the analyzer's decision, subject to the state machine (forward only, two probes before leaving "initiated"). No job promotes a skill by counting probes alone.
2. `POST /sessions/:token/audio_complete` ends a session only if it is active and every configured skill is covered; otherwise it answers 409 and changes nothing. Ending an already ended session stays idempotent (200).
   Known gap: when the live socket closes the interview on its own (the AI said goodbye early), it still ends the session itself after its 30-second poll and records `all_covered`. That label can be wrong (audit R-18, follow-up).
3. `end_reason` states what actually happened.
4. When a session is ended by anyone other than the live connection itself (an assessor, a job), the live connection follows within a few seconds: the browser is told (`session_ended` with the recorded reason) and both the browser and the model connections are closed. It is announced once. The connection checks the database row every 3 seconds, off the event-loop thread.

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

Given a candidate connected to a running interview
When an assessor ends the session
Then the candidate's connection receives session_ended with the assessor's reason, the model connection is closed, and the browser connection is closed.

Given the middleware ended the session itself (for example at the time limit)
When it later notices the row is ended
Then it does not announce the end a second time.

## Out of scope
Driving a real WebSocket and the real model connection: R-12 is verified with a fake socket (the middleware's own logic), not end to end.

## Checks
api/spec/critical/coverage_spec.rb, api/spec/critical/session_lifecycle_spec.rb, api/spec/critical/live_session_spec.rb
