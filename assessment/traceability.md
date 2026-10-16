# Traceability: audit item -> spec -> check

Every P0/P1 item in `assessment/01-audit.md` has a row here (enforced by `web/quality/checks/traceability.cjs`).
A check cell is either a file that exists, or `none: <reason>`, which is a disclosed gap, not a pass.

| Audit | Sev | Spec | Check | Status |
|---|---|---|---|---|
| R-31 | P0 | assessment/specs/SPEC-006-production-readiness.md | api/spec/critical/boot_spec.rb | open |
| R-01 | P1 | assessment/specs/SPEC-001-tenant-isolation.md | api/spec/critical/tenant_isolation_spec.rb | open |
| R-02 | P1 | assessment/specs/SPEC-001-tenant-isolation.md | api/spec/critical/tenant_isolation_spec.rb | open |
| R-03 | P1 | assessment/specs/SPEC-004-data-integrity-crud.md | web/src/pages/assessments/AssessmentEditPage.test.tsx | open |
| R-04 | P1 | assessment/specs/SPEC-002-portfolio-integrity.md | api/spec/critical/fit_gap_spec.rb | open |
| R-05 | P1 | assessment/specs/SPEC-002-portfolio-integrity.md | api/spec/critical/portfolio_generation_spec.rb | open |
| R-06 | P1 | assessment/specs/SPEC-003-coverage-and-session-lifecycle.md | api/spec/critical/coverage_spec.rb | open |
| R-07 | P1 | assessment/specs/SPEC-005-invite-link-and-contract.md | api/spec/critical/session_lifecycle_spec.rb | open |
| R-08 | P1 | assessment/specs/SPEC-005-invite-link-and-contract.md | web/src/components/fitgap/ComparisonTable.contract.test.tsx | open |
| R-09 | P1 | assessment/specs/SPEC-003-coverage-and-session-lifecycle.md | api/spec/critical/session_lifecycle_spec.rb | open |
| R-10 | P1 | assessment/specs/SPEC-004-data-integrity-crud.md | api/spec/critical/session_lifecycle_spec.rb | open |
| R-11 | P1 | assessment/specs/SPEC-002-portfolio-integrity.md | api/spec/critical/portfolio_generation_spec.rb | open |
| R-12 | P1 | assessment/specs/SPEC-003-coverage-and-session-lifecycle.md | none: needs a socket-level integration test (live audio); owner to assign | open, disclosed |
| R-13 | P1 | assessment/specs/SPEC-006-production-readiness.md | web/quality/checks/no-dev-token.cjs | open (first-admin path not covered) |
| R-14 | P1 | assessment/specs/SPEC-006-production-readiness.md | none: production CSP vs speed-test hosts needs a browser-level check | open, disclosed |
| R-15 | P1 | assessment/specs/_template.md | web/quality/dor/check.cjs | mitigated by the gate (specs now exist for R-01..R-13) |
