# Traceability: audit item -> spec -> check

Every P0/P1 item in `assessment/01-audit.md` has a row here (enforced by `web/quality/checks/traceability.cjs`).
A check cell is either a file that exists, or `none: <reason>`, which is a disclosed gap, not a pass.

| Audit | Sev | Spec | Check | Status |
|---|---|---|---|---|
| R-31 | P0 | assessment/specs/SPEC-006-production-readiness.md | api/spec/critical/boot_spec.rb | fixed |
| R-01 | P1 | assessment/specs/SPEC-001-tenant-isolation.md | api/spec/critical/tenant_isolation_spec.rb | fixed |
| R-02 | P1 | assessment/specs/SPEC-001-tenant-isolation.md | api/spec/critical/tenant_isolation_spec.rb | fixed |
| R-03 | P1 | assessment/specs/SPEC-004-data-integrity-crud.md | web/src/pages/assessments/AssessmentEditPage.test.tsx | fixed |
| R-04 | P1 | assessment/specs/SPEC-002-portfolio-integrity.md | api/spec/critical/fit_gap_spec.rb | fixed |
| R-05 | P1 | assessment/specs/SPEC-002-portfolio-integrity.md | api/spec/critical/portfolio_generation_spec.rb | fixed |
| R-06 | P1 | assessment/specs/SPEC-003-coverage-and-session-lifecycle.md | api/spec/critical/coverage_spec.rb | fixed |
| R-07 | P1 | assessment/specs/SPEC-005-invite-link-and-contract.md | api/spec/critical/session_lifecycle_spec.rb | fixed |
| R-08 | P1 | assessment/specs/SPEC-005-invite-link-and-contract.md | web/src/components/fitgap/ComparisonTable.contract.test.tsx | fixed |
| R-09 | P1 | assessment/specs/SPEC-003-coverage-and-session-lifecycle.md | api/spec/critical/session_lifecycle_spec.rb | fixed |
| R-10 | P1 | assessment/specs/SPEC-004-data-integrity-crud.md | api/spec/critical/session_lifecycle_spec.rb | fixed |
| R-11 | P1 | assessment/specs/SPEC-002-portfolio-integrity.md | api/spec/critical/portfolio_generation_spec.rb | fixed |
| R-12 | P1 | assessment/specs/SPEC-003-coverage-and-session-lifecycle.md | api/spec/critical/live_session_spec.rb | fixed (fake socket; not verified end to end) |
| R-13 | P1 | assessment/specs/SPEC-006-production-readiness.md | api/spec/tasks/create_admin_task_spec.rb | fixed |
| R-14 | P1 | assessment/specs/SPEC-007-candidate-hardware-check.md | web/src/utils/internetSpeedTest.test.ts | fixed |
| R-15 | P1 | assessment/specs/_template.md | web/quality/dor/check.cjs | open: consent, retention and NFRs are not specified (product decision); the gate stops new work without a spec |
| R-16 | P1 | assessment/specs/SPEC-008-report-export.md | api/spec/requests/api/v1/portfolios_spec.rb | fixed |
