# FlowBridge

Automation workflows platform built in Ruby on Rails to showcase reliable webhook ingestion, asynchronous workflow execution, and operator-friendly execution tracing.

## Status

Phase 0 bootstrap only. This repository currently establishes naming, scope, documentation structure, and engineering expectations. It does not yet contain a Rails application scaffold, workflow engine, node executor, or credential storage layer.

## Product intent

FlowBridge is planned as a B2B automation platform for SaaS and fintech integrations that need to receive webhooks, execute API-driven workflow nodes, retry transient failures, isolate dead letters, and audit every execution against an immutable workflow version.

## Planned stack

- Ruby on Rails API
- PostgreSQL
- Redis
- Solid Queue or Sidekiq
- OpenAPI
- OpenTelemetry
- Prometheus and Grafana
- Docker Compose
- RSpec
- k6
- React Flow as an optional thin UI layer in a later phase

## Engineering focus

This project is meant to demonstrate:

- immutable workflow versioning for safe execution replay
- webhook ingestion with signature validation and idempotency
- asynchronous node execution with retry, backoff, and dead-letter handling
- execution logs with masked secrets and per-node timing evidence
- multi-tenant automation product design with credential isolation
- operational observability for workflow failures and replays

## Bootstrap contents

- repository initialized and synchronized with GitHub
- mandatory documentation folders created
- baseline engineering spec captured in `docs/engineering-baseline.md`

## Next phase

The first implementation slice should prioritize workflows, workflow versions, webhook triggers, API action nodes, execution lifecycle persistence, idempotent webhook events, and retry or dead-letter policies.
