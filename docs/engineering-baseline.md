# FlowBridge Engineering Baseline

This repository follows the initiative-wide standards below.

## Mandatory outcomes

- product-grade `README.md` with product and engineering sections
- `openapi.yaml` once the HTTP surface exists
- `docs/adr/`, `docs/architecture/`, `docs/benchmarks/`, `docs/api/`, `docs/diagrams/`, and `docs/runbooks/`
- atomic Conventional Commit history
- GitHub Actions for lint, tests, security, build, coverage, and OpenAPI validation
- observability with structured logs, metrics, traces, request IDs, and readiness endpoints
- documented k6 performance baselines

## FlowBridge-specific emphasis

- immutable workflow versions as the only executable workflow shape
- webhook event idempotency keyed by workflow and source identity
- async execution pipeline with retry, jittered backoff, and dead-letter semantics
- masked credential storage and secret-safe execution logs
- node-level execution evidence with durations, inputs, outputs, and failures
- replay-safe operational tooling for dead letters and manual retries

## Phase 0 boundary

This repository intentionally stops before scaffolding Rails, execution workers, credential vaulting, or workflow graph code. The goal of this phase is only to lock scope and standards.
