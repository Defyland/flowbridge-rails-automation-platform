# Data Consistency

## Transaction boundaries

- Organization creation and owner API key issuance happen in one transaction.
- Webhook ingestion persists `WebhookEvent` and `WorkflowExecution` in one transaction before enqueueing work.
- Workflow execution writes each `NodeExecution` before calling a node and updates it after success or failure.
- Dead-letter creation is part of terminal failure handling.

## Idempotency

Webhook idempotency is enforced by a unique index on `[workflow_version_id, idempotency_key]`. Workflow execution idempotency has the same unique boundary. Duplicate webhook submissions return the original execution without enqueueing duplicate work.

## Immutable execution input

`WorkflowExecution` stores the inbound payload, correlation ID, idempotency key, workflow ID, and workflow version ID. `WorkflowVersion` cannot be updated after creation, so retries use the same graph.

## Indexes and constraints

- `organizations.slug` is unique.
- `api_keys.token_digest` is unique.
- `workflows` are unique per organization slug.
- `workflow_versions` are unique per workflow version number.
- `workflow_versions.trigger_key` is globally unique.
- `webhook_events` and `workflow_executions` enforce idempotency uniqueness.
- status fields use database check constraints.
- retry and attempt counters use non-negative or positive check constraints.

## Rollback strategy

Failed validation rolls back the request transaction. For execution failures, the system does not roll back historical evidence; it records failed node evidence and transitions the execution to `retrying` or `failed`. Manual operator retry creates a new execution attempt while preserving previous node attempts.
