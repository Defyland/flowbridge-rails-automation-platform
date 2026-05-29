# FlowBridge Engineering Baseline

FlowBridge now implements the initiative baseline beyond phase 0. The repository contains a runnable Rails API, product documentation, OpenAPI contract, tests, CI, security controls, observability endpoints, and benchmark scripts.

## Implemented outcomes

- Product-grade README with all required sections.
- Rails hybrid monolith with versioned `/api/v1` endpoints and an authenticated operator console.
- `openapi.yaml` contract.
- Mandatory docs folders: `docs/adr`, `docs/architecture`, `docs/benchmarks`, `docs/api`, `docs/diagrams`, and `docs/runbooks`.
- Multi-tenant domain model with API key roles and operator memberships.
- Immutable workflow versions and graph checksums.
- Signed webhook ingestion with idempotency.
- Async execution job with Solid Queue transport, retry, and dead-letter semantics.
- Encrypted credential storage and secret masking.
- Structured logs, request IDs, correlation IDs, readiness, liveness, metrics, Solid Cache, Solid Cable, and OpenTelemetry hooks.
- Minitest coverage across models, services, jobs, request flows, and Capybara system tests.
- GitHub Actions for PostgreSQL-backed tests, system tests, lint, security, Docker build, OpenAPI validation, and coverage artifact upload.
- k6 scripts for smoke, load, stress, and spike tests.

## Remaining production hardening

- Tune Solid Queue worker concurrency and queue names from production load data.
- Split web and worker runtimes if `SOLID_QUEUE_IN_PUMA` stops matching production traffic.
- Add RabbitMQ adapter for broker-native retry queues and DLQs.
- Add OAuth connector credential rotation.
- Add a graph editor UI.
