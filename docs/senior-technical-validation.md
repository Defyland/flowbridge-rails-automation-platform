# Senior Technical Validation

## Product credibility

FlowBridge models a real B2B automation workflow: tenant onboarding, workflow publishing, webhook ingress, async execution, operator inspection, failure replay, and auditability. The public API and authenticated operator console are cohesive and documented.

## Engineering evidence

- Domain boundaries are explicit in Active Record models and service objects.
- The app is a hybrid Rails monolith with PostgreSQL, ERB, Turbo, Stimulus, Importmap, Propshaft, Solid Queue, Solid Cache, and Solid Cable.
- Workflow versions are immutable and executable.
- Webhook ingress is signed and idempotent.
- Retry and dead-letter behavior is deterministic and tested.
- Tenant isolation is enforced through scoped queries and tested through request specs.
- Credentials and webhook secrets are encrypted.
- Secret-bearing outputs are masked.
- Operational endpoints cover liveness, readiness, and Prometheus metrics.
- OpenAPI is not only descriptive: every `/api/v1` route is checked for contract coverage, and real integration responses are validated against documented schemas.
- CI validates PostgreSQL-backed tests, Capybara system tests, linting, security scans, OpenAPI, coverage artifact generation, and Docker build.

## Review notes

The project intentionally uses Active Job with Solid Queue and database-backed product dead letters. ADR 003 describes how broker-native RabbitMQ could be added later while preserving idempotency and audit semantics.

## Portfolio-grade acceptance

The repository should be accepted as a senior backend portfolio project when:

- `bin/rails test:all` passes.
- `bin/rubocop` passes or has only documented generated-file exceptions.
- `bin/brakeman --no-pager` passes.
- `bin/bundler-audit` passes.
- `ruby -e 'require "yaml"; YAML.load_file("openapi.yaml")'` passes.
- `bin/rails test test/integration/openapi_response_contract_test.rb test/repository_spec_compliance_test.rb` passes.
- `npx --yes @redocly/cli lint openapi.yaml` passes without warnings.
- The README and docs explain the product without relying on source code reading.
