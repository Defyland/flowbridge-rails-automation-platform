# Workflow Engine Architecture

FlowBridge's workflow engine is the domain boundary that turns a signed webhook or API-triggered execution request into deterministic node-level evidence. The MVP is relational and job-driven, not event-sourced. Events are documented as contracts and timeline semantics so the engine can evolve without forcing a storage rewrite.

## Engine boundary

The engine starts after ingress has authenticated the caller, verified webhook signatures, and established idempotency. `WorkflowExecutionJob` is the asynchronous boundary, and `FlowBridge::ExecutionRunner` is the execution state machine. `FlowBridge::NodeExecutor` owns node behavior.

The engine must not depend on controller state, browser sessions, or mutable workflow drafts. It receives persisted identifiers, reloads durable records, and runs against the immutable `WorkflowVersion` referenced by the execution.

## Execution invariants

- A `WorkflowExecution` always references exactly one `WorkflowVersion`.
- A published `WorkflowVersion` is immutable and carries the graph checksum used for execution.
- A webhook-created execution must be unique for the tuple `source`, external `event_id`, and workflow identity.
- A manual replay must preserve the original event identity and create new attempt evidence.
- A node result must be recorded before the execution advances to the next node.
- A terminal failure must be visible as a `DeadLetter` unless the failure was resolved by successful retry.
- Secret-bearing values must be masked before they cross the execution evidence boundary.
- A recently `running` execution is treated as actively leased; duplicate jobs must not start a second attempt.
- HTTP connector nodes must use validated `http` or `https` URLs and explicit timeout budgets.

## Event taxonomy

The engine emits or records semantic events in these families:

- workflow events: version publication and retirement semantics
- webhook events: accepted, rejected, duplicate, and signature failure semantics
- execution events: started, retrying, succeeded, failed, and replay requested semantics
- node events: started, succeeded, failed, skipped, and retried semantics
- dead-letter events: created, retried, and resolved semantics

The current MVP stores these facts in relational records. Future external consumers should rely on the contracts in [../events/README.md](../events/README.md), not on database table shapes.

## Connector execution

`http_request` nodes execute through `FlowBridge::HttpClient`, which uses real `Net::HTTP` requests with bounded open/read/write timeouts. Tests use loopback HTTP endpoints so CI proves connector behavior without depending on internet access or third-party systems. Non-2xx responses are classified as retriable for transient HTTP status codes and permanent for client/configuration failures.

## Idempotency boundaries

The canonical idempotency key for webhook ingress is:

```text
source + external event_id + workflow_version_id
```

If a provider cannot guarantee globally unique event IDs, FlowBridge scopes the uniqueness by source and workflow. If a workflow is republished, the same external event may be accepted for the new immutable version only if the source intentionally sends it to the new trigger key.

Internal event publication uses `event_id` as the consumer deduplication key. Execution records use domain-level uniqueness to prevent duplicated work before downstream events are considered.

## Replay model

Manual replay is append-only from an evidence perspective. It may enqueue another job or create another node attempt, but it must not mutate prior webhook, node, execution, or dead-letter evidence beyond explicit status transitions such as `resolved`.

Replay must answer three questions:

- Which original webhook or execution caused the replay?
- Which operator or API key requested it?
- Which workflow version and graph checksum were used?

## Evolution path

The engine can evolve in three controlled steps:

1. Add more node types while preserving the same execution evidence model.
2. Add external event publication from the documented event contracts.
3. Introduce Event Sourcing for execution history only if product requirements need aggregate replay, projection rebuilding, or long-term timeline reconstruction.

Event Sourcing is documented as a future option in [ADR 004](../adr/004-defer-event-sourcing-for-execution-history.md). It is not required for the MVP.
