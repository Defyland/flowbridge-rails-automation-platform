# ADR 002: Immutable workflow versions

## Status

Accepted

## Context

Automation platforms become hard to debug when a workflow definition changes while events are queued or running. Operators need to replay an execution against the exact graph that originally accepted the webhook.

## Decision

Treat `Workflow` as mutable metadata and `WorkflowVersion` as the immutable executable artifact. Each version stores a canonical graph checksum, trigger key, encrypted webhook secret, retry policy, and publication timestamp. Updates to a persisted workflow version are blocked at the model layer.

## Consequences

- Every execution points at a stable graph.
- Replays and dead-letter retries are deterministic for a given version.
- Publishing a new graph creates a new version number rather than mutating existing records.
- Operators can compare graph checksums across deployments and incidents.
