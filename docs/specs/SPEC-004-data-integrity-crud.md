# SPEC-004 - What the form shows is what is stored

Audit items: R-03, R-10
Status: accepted

## Problem
Removing a skill from the assessment or vacancy edit form only removes it from the screen: the API deletes nested
records only when it receives `{ id, _destroy: true }`, which the web never sends. Deleting an assessment that has
candidates answers "deleted" although the model refused.

## Rules
1. When a user removes an existing skill in an edit form, the submitted payload contains `{ id, _destroy: true }` for it, and only for it.
2. Deleting a record that the model refuses to delete answers 409 with the reason, and the record remains.
3. The API contract for nested attributes is documented in the OpenAPI file and checked by the API specs.

## Acceptance criteria
Given an assessment with two skills open in the edit form
When the user removes the first skill and saves
Then the update request contains the first skill's id with `_destroy: true` and does not destroy the second.

Given a vacancy with two expected skills open in the edit form
When the user removes the first and saves
Then the update request destroys it, so fit/gap no longer compares against it.

Given an assessment that already has candidate sessions
When an admin deletes it
Then the answer is 409 and the assessment still exists.

## Out of scope
A confirmation dialog or soft-delete; both are product decisions.

## Checks
web/src/pages/assessments/AssessmentEditPage.test.tsx, web/src/pages/vacancies/VacancyEditPage.test.tsx, api/spec/critical/session_lifecycle_spec.rb
