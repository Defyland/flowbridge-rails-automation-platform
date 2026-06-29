# Common Issues Runbook

## Webhook returns `invalid_webhook_signature`

1. Confirm the sender used the `webhook_secret` returned when the workflow version was published.
2. Confirm the signature is computed over the exact raw request body.
3. Confirm the header format is `X-FlowBridge-Signature: sha256=<hex>`.
4. Check whether the sender is using a trigger key from a different workflow version.

## Duplicate webhook is accepted but not executed again

This is expected. FlowBridge deduplicates by `[workflow_version_id, idempotency_key]`. Inspect the returned `workflow_execution.id` and use `GET /api/v1/executions/{id}`.

## Execution is stuck in `retrying`

1. Inspect `GET /api/v1/executions/{id}` and note the failed node.
2. Check whether a retry job is scheduled.
3. If the downstream dependency recovered, use `POST /api/v1/executions/{id}/retry`.
4. If max attempts are exhausted, inspect `GET /api/v1/dead_letters`.

## Execution is stuck in `queued`

1. Wait for the stale-queue recovery sweep to run. Production re-enqueues `queued` executions automatically after a short grace period.
2. Inspect `GET /api/v1/executions/{id}` and confirm `attempt_count` is still `0`.
3. Verify the queue database and worker process are healthy if the execution stays `queued` beyond the next sweep.
4. If queue health is restored, use `POST /api/v1/executions/{id}/retry` to force another enqueue from the product surface.

## Dead letter remains open

1. Confirm the failing node error code and payload.
2. Retry with `POST /api/v1/dead_letters/{id}/retry` if the error is recoverable.
3. Resolve with `POST /api/v1/dead_letters/{id}/resolve` after the business owner accepts the loss or remediates externally.

## Readiness is failing

1. Call `GET /ready`.
2. If database is not ready, verify `bin/rails db:prepare` was run.
3. In production, verify `DATABASE_URL` and database connectivity.
