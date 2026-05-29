# Deployment Readiness

FlowBridge needs a Rails API, worker execution process, PostgreSQL, cache, and network egress controls for HTTP action nodes.

## Current posture

- Hybrid Rails application with API and operator surfaces.
- PostgreSQL-backed executions, dead letters, and workflow versions.
- Health, readiness, metrics, OpenTelemetry hooks, and Grafana dashboard.
- Deterministic mock nodes for the current implementation slice.

## Deferred platform work

- Kubernetes manifests are deferred until worker concurrency, egress controls, and credential rotation are stable.
- External broker adoption is deferred because database-backed dead letters already prove retry and replay semantics locally.
- Service mesh is out of scope; application-level signature validation, idempotency, masking, and rate limits are the current controls.
