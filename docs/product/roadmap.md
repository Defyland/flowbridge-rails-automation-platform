# Roadmap

## Current MVP

- Versioned API for organizations, workflows, workflow versions, credentials, executions, and dead letters.
- Signed webhook ingress.
- Immutable workflow versions.
- Async execution with Solid Queue.
- Dead-letter retry and resolution.
- Operator console.
- Security, observability, CI, Docker, and Kamal deployment path.

## Next milestone

- Capture k6 benchmark results from a stable environment.
- Add real provider adapters with outbound idempotency keys.
- Add connector-level credential rotation.
- Add alert thresholds for queue depth, DLQ growth, and signature failures.
- Add production backup and restore drill documentation.

## Later product expansion

- Visual workflow editor.
- Workflow graph validation for branches, fan-out, joins, and dependency cycles.
- Event stream export for downstream analytics or audit consumers.
- Optional broker adapter for high-throughput queueing.
- Organization-level usage plans and quotas.
