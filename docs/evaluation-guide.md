# Evaluation Guide

This guide is written for a reviewer evaluating FlowBridge as a senior Ruby on Rails or technical leadership portfolio project. It focuses on what to run, what to read, and what engineering signals the repository is intended to demonstrate.

## Fast path

1. Read the README for product context and local setup.
2. Run the full CI entrypoint:

   ```bash
   bin/ci
   ```

3. Inspect the API contract:

   ```bash
   npx --yes @redocly/cli lint openapi.yaml
   ```

4. Build the deployable image:

   ```bash
   docker build -t flowbridge:test .
   ```

5. Start the app and log in to the operator console with the seeded user:

   ```text
   operator@flowbridge.local / password123
   ```

## Senior Rails signals

- Idiomatic Rails 8 hybrid monolith instead of a premature service split.
- Clear separation between API controllers, web controllers, domain services, jobs, and models.
- PostgreSQL-backed development, test, and production instead of a local-only SQLite design.
- Rails defaults used intentionally: ERB, Turbo, Stimulus, Importmap, Propshaft, Minitest, fixtures, Active Job, Active Storage, Action Mailer, Solid Queue, Solid Cache, and Solid Cable.
- Rails authentication generator adapted without collapsing API authentication into browser sessions.
- `CurrentAttributes` limited to request boundaries for user, session, and organization context.
- Database constraints and application validations both used for product invariants.

## Architecture signals

- Immutable workflow versions prevent in-flight executions from changing underneath operators.
- Webhook ingestion is signed, idempotent, and correlation-aware.
- Workflow execution keeps product state separate from queue transport state.
- Dead letters are explicit domain objects, not only failed queue jobs.
- Credential and webhook secrets are encrypted and masked in observable outputs.
- Tenant isolation is enforced through scoped queries and tested request flows.
- ADRs explain why this implementation favors a Rails monolith and database-backed Solid services.

## Operational signals

- `/up`, `/ready`, and `/metrics` provide health, readiness, and Prometheus-style observability.
- Structured JSON logging carries request and correlation identifiers.
- OpenTelemetry instrumentation can be enabled without changing application code.
- Kamal and Thruster configuration show a credible deployment path.
- Runbooks document common failure modes such as invalid signatures, stuck retries, and open dead letters.
- Benchmarks include smoke, load, stress, and spike scenarios with documented methodology.

## Security signals

- API tokens are stored as digests.
- Browser users authenticate through Rails sessions and bcrypt.
- Authorization is role-based for API keys and organization memberships.
- Secret-bearing fields are filtered, encrypted, or masked.
- CI runs Brakeman and bundler-audit.
- The threat model and authorization matrix are documented under `docs/security`.

## Testing signals

- Minitest covers models, integrations, jobs, authorization, tenant isolation, retries, and failure scenarios.
- Fixtures are used as stable domain examples.
- Capybara system tests cover the operator console.
- The CI task runs tests, lint, security checks, OpenAPI validation, and coverage reporting.

## Known boundaries

- The visual workflow editor is intentionally out of scope for this implementation slice.
- RabbitMQ is documented as a future adapter, but Solid Queue is the current durable job transport.
- OAuth connector credential rotation is a roadmap item.
- Production queue concurrency should be tuned from real traffic data.

## Review recommendation

Evaluate the project less as a feature checklist and more as a production-shaped backend slice. The strongest signals are the consistency of tenant boundaries, immutable execution semantics, failure recovery, operational documentation, and the decision to lean into modern Rails defaults where they reduce unnecessary infrastructure.
