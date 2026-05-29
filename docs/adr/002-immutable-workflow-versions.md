# ADR 002: Immutable workflow versions

## Status

Accepted

## Context

Automation platforms become hard to debug when a workflow definition changes while events are queued or running. Operators need to replay an execution against the exact graph that originally accepted the webhook.

FlowBridge also needs a stable idempotency and security boundary. Webhook secrets, trigger keys, retry policies, and graph checksums cannot drift while source systems are retrying deliveries or operators are replaying failures.

## Decision

Treat `Workflow` as mutable metadata and `WorkflowVersion` as the immutable executable artifact. Each version stores a canonical graph checksum, trigger key, encrypted webhook secret, retry policy, and publication timestamp. Updates to a persisted workflow version are blocked at the model layer.

Workflow execution, webhook events, node executions, audit logs, and dead letters must reference the `workflow_version_id` that was actually used. New graph behavior requires publishing a new version number. Manual replay must use the original immutable version unless a future migration feature explicitly records an operator-approved replay into a newer version.

## Consequences

- Every execution points at a stable graph.
- Replays and dead-letter retries are deterministic for a given version.
- Publishing a new graph creates a new version number rather than mutating existing records.
- Operators can compare graph checksums across deployments and incidents.
- Webhook idempotency can be scoped to `source + source_event_id + workflow_version_id`.
- Version rows may grow over time, but they are cheap operational evidence compared with ambiguous execution history.

## Alternatives considered

- Mutable workflow definitions: rejected because queued executions and retries could silently run different logic.
- Copying the graph JSON onto every execution: useful as a defensive cache, but not enough to model publication lifecycle, trigger secrets, or version-level retry policy.
- Event Sourcing workflow definitions from change events: deferred because the MVP only needs immutable publication artifacts, not aggregate rehydration.
