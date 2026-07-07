# Architecture Overview

FlowBridge is split into clear HTTP, domain, execution, and observability boundaries.

## Runtime components

- `Api::V1::*Controller`: validates request shape, authenticates API keys, enforces permissions, and renders JSON.
- `Api::V1::ServerlessWebhooksController`: accepts signed internal envelopes produced by the serverless edge.
- `Operator::*Controller`: authenticates Rails sessions and renders the ERB/Hotwire operator console.
- `FlowBridge::WorkflowPublisher`: creates immutable workflow versions and graph checksums.
- `FlowBridge::ServerlessWebhookEnvelope`: validates the normalized provider-event contract before it reaches the durable webhook ingestor.
- `FlowBridge::WebhookIngestor`: verifies the idempotency boundary by storing webhook event and execution state in one transaction.
- `services/serverless/webhook_ingress`: standalone Ruby Lambda adapter for API Gateway webhook events.
- `WorkflowExecutionJob`: Solid Queue-backed async boundary for workflow execution.
- `FlowBridge::ExecutionRunner`: execution state machine that records attempts, retries, success, and terminal failure.
- `FlowBridge::NodeExecutor`: deterministic node executor for trigger, transform, filter, HTTP action, and event emission nodes.
- `DeadLetter`: operator-facing failure queue.
- `AuditLog`: append-only tenant scoped action log.

## Request flow

1. API client creates an organization and receives a one-time API key token.
2. Client creates a workflow container.
3. Client publishes a workflow version with a graph and retry policy.
4. Webhook sender signs a JSON payload with the version secret.
5. Ingress verifies the HMAC signature and idempotency key.
6. The event and execution are persisted in a database transaction.
7. `WorkflowExecutionJob` executes the version graph through Solid Queue.
8. Operators inspect execution and dead-letter state through authenticated HTML screens or JSON APIs.

## Serverless edge flow

1. Provider posts to API Gateway `POST /webhooks/{trigger_key}`.
2. Lambda normalizes the API Gateway event into a `schema_version: 1` envelope.
3. Lambda signs the envelope with the serverless ingress secret loaded from Secrets Manager.
4. Rails receives `POST /api/v1/serverless/webhooks/:trigger_key`.
5. Rails verifies `X-FlowBridge-Serverless-Signature`, validates the envelope, and delegates to `FlowBridge::WebhookIngestor`.

This keeps the microservice boundary at the edge. The workflow engine, idempotency model, audit trail, and execution queue stay inside Rails.

## Workflow engine direction

The workflow engine is intentionally modeled as a deterministic execution core around immutable workflow versions. A workflow draft may change, but an execution only runs a published `WorkflowVersion`. The engine boundary is `WorkflowExecutionJob` plus `FlowBridge::ExecutionRunner`; HTTP controllers are only orchestration entry points.

Engine responsibilities:

- validate that the graph belongs to a published immutable workflow version
- execute nodes in a deterministic order derived from the persisted graph
- record workflow, execution, node, webhook, retry, and dead-letter timeline events
- preserve idempotency by `event_id`, `source`, and workflow identity before creating new execution evidence
- keep credentials out of node inputs, node outputs, event payloads, audit metadata, and dead-letter records
- make replay an explicit operator action that appends new attempt evidence rather than rewriting history

Non-responsibilities for the MVP:

- visual graph editing
- distributed workflow orchestration across services
- Event Sourcing as the source of truth
- broker-native DLQ semantics
- dynamic code execution inside nodes

See [workflow-engine.md](workflow-engine.md) for workflow engine boundaries and evolution rules.

## Observability flow

Every request receives a request ID and correlation ID. Correlation IDs propagate from webhook headers into `WebhookEvent`, `WorkflowExecution`, `AuditLog`, JSON logs, and response headers. Metrics are exposed at `/metrics` in Prometheus text format.
