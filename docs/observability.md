# Observability

FlowBridge treats observability as part of the workflow engine, not as an external afterthought. The primary operational question is: can an operator connect an inbound webhook to the exact workflow version, execution, node attempts, retries, dead letter, and audit trail?

## Signals

| Signal | Implementation | Purpose |
| --- | --- | --- |
| Liveness | `GET /up` | Confirms the Rails process can respond. |
| Readiness | `GET /ready` | Confirms database and queue dependencies are usable before routing traffic. |
| Metrics | `GET /metrics` | Exposes Prometheus text metrics for webhook events, workflow executions, dead letters, and rate limits. |
| Logs | `config/initializers/logging.rb` | Emits structured JSON logs with request, correlation, and organization context. |
| Traces | `config/initializers/open_telemetry.rb` | Enables Rack, Action Pack, Active Job, and Active Record instrumentation when `OTEL_ENABLED=true`. |
| Dashboard | `docs/diagrams/grafana-flowbridge-overview.json` | Provides an importable Grafana view for webhook, execution, and DLQ health. |

## Correlation Model

Every HTTP request receives a Rails request ID. API and webhook requests also accept `X-Correlation-Id`; if the caller omits it, FlowBridge falls back to the request ID.

The correlation ID is persisted on:

- `WebhookEvent`
- `WorkflowExecution`
- `AuditLog`
- structured log lines
- API error responses
- workflow event contracts

This makes retry and incident analysis possible without relying on request logs alone.

## Workflow Execution Evidence

Execution rows are a first-class observability surface:

- `workflow_executions` stores the workflow, immutable workflow version, status, idempotency key, correlation ID, retry count, and payload snapshot.
- `node_executions` stores node-level status, attempts, started/finished timestamps, output, and error payloads.
- `dead_letters` stores terminal failure context and operator remediation state.

The operator console exposes these records so support and engineering can inspect failures without database access.

## Alert Candidates

These are not configured as production alerts in the MVP because routing and thresholds depend on the target environment. They are the first alerts to wire after deployment:

- readiness failures for more than one scrape interval
- webhook signature failures above normal baseline
- sustained growth in queue depth
- workflow execution failure ratio above the agreed SLO
- dead-letter count growth without operator resolution
- repeated manual replay by the same operator
- p95 webhook ingress latency above budget

## Logging Rules

- Log identifiers and state transitions, not raw credentials.
- Preserve `request_id`, `correlation_id`, and `organization_id` whenever available.
- Keep payload logging masked through the same recursive masking rules used for credentials and dead letters.
- Treat execution records as durable evidence; logs are supporting telemetry, not the source of truth.

## Runbook Entry Points

- [docs/runbooks/common-issues.md](runbooks/common-issues.md)
- [docs/runbooks/workflow-event-contract-drift.md](runbooks/workflow-event-contract-drift.md)
- [docs/security/threat-model.md](security/threat-model.md)
