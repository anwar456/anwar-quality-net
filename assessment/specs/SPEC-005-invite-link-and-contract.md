# SPEC-005 - The invite link opens the interview; web and API agree on field names

Audit items: R-07, R-08
Status: accepted

## Problem
The invite URL is built from the API's base URL, but the interview page is served by the web app, so every link a
candidate receives is dead. The fit/gap table reads `required_level` while the API sends `expected_level`, so the
required level is blank on every row.

## Rules
1. The invite URL is `WEB_BASE_URL + /interview/:token`. `WEB_BASE_URL` is a separate setting from `APP_BASE_URL` (the API origin). In production the app refuses to boot when it is missing, is not an http(s) URL, or is the same origin as `APP_BASE_URL`.
2. The OpenAPI document (`api/swagger/v1/swagger.yaml`) is generated from the request specs and is the contract between the two services; CI fails if it is stale.
3. A web component that renders an API response is tested with a body generated from that contract, not with a hand-written fixture.

## Acceptance criteria
Given WEB_BASE_URL and APP_BASE_URL are different origins
When an assessor invites a candidate
Then the invite URL starts with WEB_BASE_URL.

Given a fit/gap row with expected level 4 and candidate level 2
When the comparison table is rendered
Then both L4 and L2 are visible.

## Out of scope
Versioning the API; generating TypeScript types from the contract (a sensible next step).

## Checks
api/spec/critical/session_lifecycle_spec.rb, web/src/components/fitgap/ComparisonTable.contract.test.tsx, CI step "OpenAPI document is up to date"
