# SPEC-001 - Tenant isolation and login binding

Audit items: R-01, R-02
Status: accepted

## Problem
Portfolios, portfolio skills and fit/gap reports have no tenant of their own and are looked up by bare id, so an
assessor of one organisation can read, export and change another organisation's candidates. Login takes the tenant
from a client-supplied header, so any admin can obtain a token for any organisation.

## Rules
1. Every record reachable by id through the API belongs to exactly one tenant; a lookup from another tenant behaves as "not found" (404), never 403, so existence is not disclosed.
2. Child records (portfolio, portfolio skill, fit/gap report, override) inherit their tenant from the session they belong to; they are resolved through that tenant-scoped parent.
3. The tenant of a login is the tenant of the user. A `X-Tenant-Scheme` header sent by the client is ignored for authentication.
4. Background jobs act on ids they were given by an already-checked request; they do not widen access.

## Acceptance criteria
Given an admin of organisation A and a finished interview of organisation B
When the admin requests B's portfolio export, fit/gap, fit/gap regeneration, fit/gap report or rating override by id
Then every request answers 404, nothing is enqueued and no override row exists.

Given an admin of organisation A who is logged in
When they log in sending `X-Tenant-Scheme` of organisation B
Then the token's scheme claim is not B's scheme.

Given an admin of organisation A
When they list assessments
Then they only see A's assessments.

## Out of scope
Row-level security in the database; the WebSocket endpoints (tracked as audit R-19).

## Checks
api/spec/critical/tenant_isolation_spec.rb
