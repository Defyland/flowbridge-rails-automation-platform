# Use Cases

## Publish a workflow version

A platform engineer creates a workflow and publishes a version with a webhook trigger, transform node, and HTTP action node. The published version receives a trigger key and encrypted webhook secret.

Acceptance signals:

- graph checksum is stable
- version number increments
- workflow status becomes active
- published version is immutable

## Ingest a signed webhook

A source system sends a JSON payload with `X-FlowBridge-Signature` and `X-FlowBridge-Event-Id`. FlowBridge verifies the signature, stores the event, creates an execution, and enqueues work.

Acceptance signals:

- invalid signature is rejected
- duplicate event ID does not enqueue duplicate execution
- correlation ID is preserved

## Inspect execution evidence

An operator opens the console, reviews workflow executions, and drills into node attempts, inputs, outputs, durations, and failures.

Acceptance signals:

- node evidence is persisted
- secrets are masked
- tenant boundary is enforced

## Retry a dead letter

An operator reviews an open dead letter and retries after the downstream dependency recovers.

Acceptance signals:

- retry is permission-gated
- prior evidence remains visible
- audit log records the action

## Resolve an accepted loss

An operator resolves a dead letter when the business owner accepts the loss or remediation happened outside FlowBridge.

Acceptance signals:

- dead letter status changes to resolved
- resolution timestamp is recorded
- resolved records remain queryable
