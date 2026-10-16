# SPEC-006 - The service starts in production and carries no secrets or foreign identifiers

Audit items: R-31, R-13, R-28
Status: accepted

## Problem
Booting with the production settings fails twice (a constant whose name does not match its file, and a
configuration call for a component that is not loaded). A login token can be compiled into the web bundle. The
repository names the organisation that owns the exercise, its hosts and its registry.

## Rules
1. `rails zeitwerk:check` passes and the application boots with `RAILS_ENV=production` and only the production gem groups.
2. No production web bundle contains `VITE_DEV_TOKEN`: the code reads it only behind `import.meta.env.DEV`, and because Vite publishes every `VITE_*` variable of the build environment (a library pulls in the whole `import.meta.env`), the production build itself refuses to run while that variable is set.
3. No tracked file or path contains an identifier from the forbidden list (stored as hashes in web/quality/scan/forbidden-terms.sha256).
4. A fresh installation can create its first assessor with `rails users:create_admin EMAIL=.. PASSWORD=.. SCHEME=..`: the admin is bound to the organization, the password is at least 12 characters, running it twice updates the same user, and bad input creates nothing.

## Acceptance criteria
Given the production gem groups and production settings
When the application is eager loaded
Then it boots without error.

Given a production build of the web app
When the source is checked
Then no unguarded read of VITE_DEV_TOKEN exists.

Given VITE_DEV_TOKEN is set in the environment of a production build
When the build runs
Then it stops with an error and publishes nothing.

Given a fresh installation with one organization and no users
When the operator runs the create-admin task
Then the admin can log in and the token carries that organization's scheme.

Given the git-tracked files of the repository
When the confidentiality scan runs
Then it reports no forbidden identifier.

## Out of scope
Secret management of the real deployment (Kubernetes Secrets are owned by the platform team).

## Checks
api/spec/critical/boot_spec.rb, api/spec/tasks/create_admin_task_spec.rb, CI job "API boots in production mode", web/quality/checks/no-dev-token.cjs, web/quality/scan/identifiers.cjs
