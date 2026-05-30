# Engineering Case Study

## 1. Product Context

FlowBridge is a Rails 8 hybrid monolith for reliable webhook-driven automation. It serves SaaS and fintech teams that need to receive external events, deduplicate delivery, execute versioned workflows asynchronously, and give operators enough evidence to retry or resolve failures safely.

The product problem is not "run background jobs." The problem is making webhook automation auditable when source systems retry events, workflow definitions change, downstream APIs fail, and support teams need to explain what happened.

## 2. Domain Model

The core language is organization, API key, workflow, workflow version, webhook event, workflow execution, node execution, credential, dead letter, and audit log. `Workflow` is mutable product metadata; `WorkflowVersion` is the immutable executable artifact. `WorkflowExecution` and `NodeExecution` form the evidence trail.

This split is the central domain decision. It keeps retries and incident review tied to the graph that actually accepted the event.

## 3. Architecture

FlowBridge uses a modular Rails monolith with two HTTP surfaces:

- JSON API and webhook ingress under `/api/v1`
- authenticated ERB/Hotwire operator console

Domain behavior lives in `app/services/flow_bridge`. Async work runs through Active Job with Solid Queue. PostgreSQL remains the source of truth for tenant data, workflow versions, executions, node evidence, dead letters, queue, cache, and cable state.

## 4. Key Trade-offs

Accepted:

- Rails monolith before microservices.
- Solid Queue before Sidekiq/RabbitMQ.
- ERB/Hotwire before React SPA.
- Relational execution history before full Event Sourcing.
- Manual Kamal deployment before automatic production deploy.

Rejected:

- Mutable workflow execution definitions.
- Running workflow nodes inside webhook requests.
- Storing raw API keys or credentials.
- Fake benchmark claims without measured output.

## 5. Data Model

The data model uses explicit tenant foreign keys, unique constraints, and status checks. API key digests are unique. Workflow slugs are unique per organization. Workflow version numbers are unique per workflow. Trigger keys are unique. Webhook events and workflow executions enforce idempotency.

## 6. Consistency Model

Webhook ingress persists the webhook event and execution in one transaction before enqueueing work. Execution failures do not roll back history; they create node evidence and move the execution into retrying or failed states. Terminal failures create dead letters.

This is an evidence-preserving consistency model rather than an all-or-nothing execution model.

## 7. Failure Scenarios

Covered failure modes include invalid API keys, forbidden role actions, cross-tenant reads, invalid webhook signatures, duplicate webhooks, transient node failures, retry exhaustion, non-retryable failures, and dead-letter remediation.

Runbooks document invalid signatures, duplicate deliveries, stuck retries, dead letters, readiness failures, and event contract drift.

## 8. Performance Strategy

The hot path is webhook ingress. It is intentionally short: verify signature, enforce idempotency, persist event/execution, enqueue job, return `202`. Node execution happens asynchronously.

k6 scripts exist for smoke, load, stress, and spike scenarios. The repository currently documents budgets and methodology; measured p50/p95/p99 output is a remaining evidence gap.

## 9. Scalability Strategy

Initial scale is vertical and process-level horizontal scaling: more Rails web processes, more worker processes, and tuned PostgreSQL resources. The first likely bottlenecks are webhook uniqueness indexes, `workflow_executions`, `node_executions`, queue depth, and dead-letter growth.

Future options include table partitioning by organization/time, dedicated worker hosts, broker-backed queue adapters, and retention policies.

## 10. Security Model

Security controls include API key digest storage, Rails session auth for operators, role permissions, tenant-scoped queries, encrypted credentials, per-version webhook secrets, HMAC signatures, idempotency constraints, recursive masking, rate limiting, audit logs, Brakeman, and bundler-audit.

The threat model covers spoofing, replay, token leakage, credential leakage, dead-letter exposure, and operator replay abuse.

## 11. Observability

FlowBridge exposes structured JSON logs, request IDs, correlation IDs, `/up`, `/ready`, `/metrics`, OpenTelemetry hooks, and a Grafana dashboard definition. Execution evidence is itself an observability surface because operators can inspect each node attempt.

## 12. Operational Cost

The MVP chooses fewer external systems. PostgreSQL backs primary data, jobs, cache, and cable. This lowers deployment and debugging cost for a portfolio-sized product, but it concentrates load in the database. The docs name where that cost changes as traffic grows.

## 13. Maintainability

Controllers are thin and split by API vs operator concerns. Services are named by use case. Tests use Rails defaults with Minitest and fixtures. ADRs document major decisions. The spec-driven docs make the readiness bar auditable.

## 14. Product Decisions

The product prioritizes reliability and operator visibility over a broad connector catalog. That is why the MVP includes immutable workflow versions, signed ingress, node evidence, dead letters, and runbooks before a visual editor or marketplace.

## 15. What I Would Do Next

- Capture benchmark results from a stable environment.
- Add real provider adapters and outbound idempotency keys.
- Add alert thresholds and retention policies.
- Run a production backup/restore drill.
- Add graph validation for branching, fan-out, and dependency cycles.
- Revisit Event Sourcing only if execution timeline reconstruction becomes a primary product requirement.
