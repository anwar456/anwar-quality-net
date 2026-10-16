# SPEC-007 - The candidate hardware check measures our API and fails closed

Audit items: R-14
Status: accepted

## Problem
Before an interview starts, the candidate's browser measures ping, download and upload. It called third-party
hosts (a search engine, two CDNs, two echo services), which the production Content-Security-Policy blocks, so in the
default production configuration every candidate failed the check and could not start. When a measurement failed it
also substituted a plausible number: the upload fallback (0.5 MB/s = 4 Mbps) equals the minimum, so an unreachable
server could still pass.

## Rules
1. Ping, download and upload are measured against the API the interview audio uses (`/health`, `GET /speed_test`, `POST /speed_test`). Each URL can be overridden by configuration. No request goes to a host the CSP does not allow.
2. A measurement that cannot be taken (network error, non-2xx answer) counts as failed: download 0, upload 0, ping 999. No fallback value is ever invented.
3. `GET /speed_test?bytes=N` returns N bytes of zeros, defaults to 500 000, is capped at 2 000 000, needs no login, and is rate limited to 30 requests a minute per IP.

## Acceptance criteria
Given the API base URL is https://api.example.test/api/v1
When the hardware check runs
Then every request goes to that origin and no request goes to any other host.

Given the browser cannot reach the API (blocked or offline)
When the hardware check runs
Then the result is not passed, with download 0 and upload 0.

Given the API answers the speed test with an error status
When the hardware check runs
Then the result is not passed.

Given a request for 999 999 999 bytes
When the download sink answers
Then it returns exactly 2 000 000 bytes.

## Out of scope
Measuring the candidate's microphone or camera quality; changing the minimum speeds.

## Checks
web/src/utils/internetSpeedTest.test.ts, api/spec/requests/api/v1/auth_spec.rb (speed_test operations)
