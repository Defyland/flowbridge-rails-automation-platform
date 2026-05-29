# ADR 004: Defer Event Sourcing for Execution History

## Status

Accepted.

## Context

FlowBridge has a natural event history: webhook received, node started, node succeeded, node failed, retry scheduled, dead-letter created, replay requested. Full Event Sourcing would require aggregate replay, event migrations, snapshots, and projection rebuilds.

The MVP's primary operational queries are relational: list executions, inspect node evidence, retry dead letters, resolve dead letters, and filter by organization/workflow/status. Rails and PostgreSQL serve these queries directly with low complexity.

## Decision

The MVP stores workflow executions, node executions, webhook events, dead letters, and audit logs as transactional records. Event contracts document integration and timeline semantics, while full Event Sourcing remains a future option for richer execution-history reconstruction.

Event Sourcing is not a requirement for workflow correctness in the MVP. Correctness comes from immutable workflow versions, relational constraints, idempotent webhook ingress, explicit execution state, and append-oriented node/dead-letter evidence.

## Consequences

- Operator queries stay simple and relational.
- Replays remain explicit and audit-friendly.
- Workflow versions stay immutable without requiring aggregate rehydration.
- Event Store tooling is deferred until execution history becomes a primary product surface.
- Event contracts can be introduced now without committing storage to an event store.
- If Event Sourcing is adopted later, relational execution tables can become projections rather than the initial write model.

## Adoption triggers

Revisit Event Sourcing only when at least one of these becomes true:

- customers need a complete reconstructable execution timeline independent of relational snapshots
- downstream consumers require durable ordered event streams
- projection rebuilds become a product requirement
- compliance requires preserving every state transition as an immutable append-only log

## Alternatives considered

- Full Event Sourcing now: rejected because it adds event migrations, snapshots, projection rebuilds, and debugging overhead before the MVP needs them.
- Relational-only forever: rejected as a hard rule because event contracts and audit timelines may become product surfaces.
- Queue logs as history: rejected because queue transport is not a product audit boundary.
