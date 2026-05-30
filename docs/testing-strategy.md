# Testing Strategy

FlowBridge uses the Rails 8 default testing stack: Minitest, fixtures, integration tests, job tests, service tests, system tests, and repository compliance checks.

## Test Layers

| Layer | Files | Responsibility |
| --- | --- | --- |
| Model tests | `test/models/*` | Validate local invariants such as tenant ownership, immutable versions, credential masking, and auth-related constraints. |
| Service tests | `test/services/*` | Exercise workflow execution behavior, retry transitions, node evidence, and dead-letter creation. |
| Job tests | `test/jobs/*` | Verify Active Job integration around workflow execution. |
| Integration tests | `test/integration/*` | Cover API lifecycle, authorization, tenant isolation, webhook signatures, duplicate delivery, rate limits, metrics, and failure scenarios. |
| Controller tests | `test/controllers/*` | Cover Rails-auth session and password flows. |
| System tests | `test/system/*` | Verify the operator console can render real workflow and execution data through the browser stack. |
| Repository compliance | `test/repository_spec_compliance_test.rb` | Guards README sections, required docs, OpenAPI shape, and parseable workflow event contracts. |

## Fixture Strategy

Fixtures are used instead of factories because the project is intentionally aligned with the Rails omakase stack. They keep domain examples stable and readable:

- one organization with operator users and memberships
- API keys with role-specific permissions
- workflows and immutable workflow versions
- webhook events and workflow executions
- node executions, credentials, audit logs, and dead letters

When a test needs a one-off state, it can still create records inline. Shared examples should become fixtures only when they represent durable domain language.

## CI Gate

`bin/ci` is the primary local and CI entry point. It runs:

- `bin/setup --skip-server`
- `bin/rubocop`
- `bin/bundler-audit`
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`
- OpenAPI YAML parsing
- `bin/rails test:all`
- `RAILS_ENV=test bin/rails db:seed:replant`

Additional release confidence checks used for the spec-driven pass:

- `bin/rails test:system`
- Redocly OpenAPI lint
- Markdown relative-link validation
- event JSON schema parsing
- CI/deploy workflow YAML parsing
- `docker build -t flowbridge:test .`

## Coverage Expectation

Coverage is useful as a regression signal, not as a substitute for behavioral tests. The current senior-readiness bar is that critical paths are covered:

- API key authentication and authorization
- tenant isolation
- webhook signature validation
- idempotent webhook ingestion
- execution retry and failure transitions
- dead-letter creation and remediation
- metrics endpoint behavior
- required repository documentation and contracts

## What Is Intentionally Not Tested Yet

- Real third-party connector calls; the MVP simulates node execution.
- Production Kamal deployment against an actual VPS/cloud host.
- Browser coverage for every operator action; the current system test is a smoke-level console check.
- Long-running k6 benchmark results; scripts and methodology exist, but stable p50/p95/p99 captures still need a long-lived app server run.
