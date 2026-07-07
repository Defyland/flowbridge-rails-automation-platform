# Senior Readiness Spec

This spec translates the shared portfolio standards into acceptance criteria for FlowBridge. It is intentionally evidence-driven: a criterion is `Done` only when a concrete file, test, or command proves it.

## Product Bar

FlowBridge must read as a believable B2B automation product for SaaS and fintech teams that need replay-safe webhook workflows. The README and product docs must name the problem, users, core workflow, non-goals, and roadmap without relying on source-code reading.

## Domain Bar

The domain must use consistent language for organizations, API keys, workflows, workflow versions, webhook events, executions, node executions, credentials, dead letters, and audit logs. Aggregate boundaries, invariants, and state machines must be explicit and backed by tests where behavior is implemented.

## Architecture Bar

The architecture must justify a Rails hybrid monolith, separate API and operator surfaces, isolate workflow engine responsibilities, document deployment shape, and name deferred complexity such as microservices, RabbitMQ, Kubernetes, and Event Sourcing.

## API Bar

The HTTP API must remain versioned, authenticated, documented through OpenAPI, and accompanied by examples for success, validation failure, authorization failure, webhook signature failure, duplicate webhook delivery, retry, and dead-letter flows.

## Data and Consistency Bar

The data model must document transaction boundaries, unique indexes, foreign keys, status constraints, idempotency, rollback behavior, and the consistency boundary between webhook ingress, job enqueueing, execution evidence, and dead letters.

## Security Bar

Security evidence must cover assets, actors, trust boundaries, abuse cases, authorization matrix, token strategy, webhook spoofing, tenant isolation, token leakage, replay abuse, credentials masking, DLQ exposure, audit logs, and residual risks.

## Observability Bar

The system must expose structured logs, request ID, correlation ID, health check, readiness check, Prometheus metrics, OpenTelemetry hooks, Grafana dashboard definition, and runbooks for operational failures.

## Performance Bar

The repository must include k6 smoke, load, stress, and spike scripts plus a methodology and honest baseline. If measured p50/p95/p99 results are not available, the docs must say so and identify the measurement step.

## Scalability Bar

The docs must name hot paths, read-heavy paths, write-heavy paths, fastest-growing tables, queue buildup risks, hot partitions, horizontal scale boundaries, future partitioning/sharding options, and flows that must not become eventually consistent.

## Operational Cost Bar

The docs must describe infrastructure cost, debugging cost, deploy cost, backup/retention cost, monitoring burden, vendor lock-in, and simpler alternatives that were intentionally chosen or deferred.

## Maintainability Bar

The codebase must keep controllers thin, domain services named by use case, Rails defaults where they fit, scripts for common validation, seed data, documented extension points, and ADRs for major choices.

## Readability Bar

Docs, tests, and code must use domain language instead of generic process names. Claims like "production-ready", "scalable", or "secure" must point to real evidence or be marked as partial.

## Test and CI Bar

CI must cover lint, security, tests, OpenAPI validation, Docker build, and coverage artifact generation. Local verification must use `bin/ci` and targeted documentation checks.

## Evidence Matrix

| Criterion | Evidence | Status | Notes |
| --- | --- | --- | --- |
| Product problem is explicit | `README.md`, `docs/product/problem.md` | Done | Names webhook automation reliability problem and target teams. |
| Personas and workflows are documented | `docs/product/personas.md`, `docs/product/use-cases.md` | Done | Covers API clients and operators. |
| Non-goals are explicit | `docs/product/non-goals.md` | Done | Avoids fake scope such as visual editor in MVP. |
| Domain glossary exists | `docs/domain/glossary.md` | Done | Matches model and service names. |
| Aggregates and invariants are documented | `docs/domain/aggregates.md`, `docs/domain/invariants.md` | Done | Critical invariants also covered by tests. |
| State machines are documented | `docs/domain/state-machines.md` | Done | Workflow, execution, node, and dead-letter states. |
| Architecture boundaries are explicit | `docs/architecture/module-boundaries.md`, `docs/architecture/workflow-engine.md` | Done | Distinguishes API, operator, engine, observability, and infra. |
| C4 and sequence views exist | `docs/architecture/c4-context.md`, `docs/architecture/c4-container.md`, `docs/architecture/sequence-diagrams.md` | Done | Text plus Mermaid diagrams. |
| Deployment view exists | `docs/architecture/deployment-view.md`, `config/deploy.yml`, `.github/workflows/deploy.yml` | Done | Manual Kamal deploy is documented. |
| Serverless edge boundary exists | `services/serverless/webhook_ingress`, `app/controllers/api/v1/serverless_webhooks_controller.rb`, `infra/opentofu/aws-serverless-ingress` | Done | API Gateway/Lambda normalizes provider traffic and Rails keeps idempotency/execution ownership. |
| Infrastructure as code exists | `infra/opentofu/aws-serverless-ingress`, `bin/infra-check` | Done | Terraform provider lock and local validation gate are present. |
| OpenAPI is present | `openapi.yaml` | Done | Redocly lint passes. |
| API examples and error format exist | `docs/api/http-examples.md`, `docs/api/error-format.md` | Done | Includes webhook and failure examples. |
| Consistency model is documented | `docs/architecture/data-consistency.md` | Done | Covers idempotency, transactions, rollback. |
| Event contracts exist | `docs/events/README.md`, `docs/events/*.v1.json` | Done | JSON parsing verified. |
| Threat model is specific | `docs/security/threat-model.md`, `docs/security/abuse-cases.md` | Done | Covers webhook spoofing, replay, masking, DLQ. |
| Authorization matrix exists | `docs/security/authorization-matrix.md` | Done | API key roles and operator actions. |
| Secrets strategy is documented | `docs/security/secrets.md`, `.kamal/secrets` | Done | No raw production secrets in repo. |
| Data classification exists | `docs/security/data-classification.md` | Done | Names payload, credential, audit, metric sensitivity. |
| Observability evidence exists | `docs/observability.md`, `docs/diagrams/grafana-flowbridge-overview.json`, `config/initializers/logging.rb`, `config/initializers/open_telemetry.rb` | Done | Health/readiness/metrics implemented. |
| Runbooks exist | `docs/runbooks/common-issues.md`, `docs/runbooks/workflow-event-contract-drift.md` | Done | Covers common operational recovery paths. |
| Performance scripts exist | `benchmarks/*.js`, `docs/benchmarks/methodology.md` | Done | k6 scripts are present. |
| Measured benchmark results exist | `benchmarks/baseline.md` | Partial | Scripts and budgets exist; long-lived server run has not been captured. |
| Scalability analysis exists | `docs/scalability.md` | Done | Names hot paths and growth risks. |
| Operational cost analysis exists | `docs/operational-cost.md` | Done | Covers infra, debug, deploy, backup, and monitoring cost. |
| Senior case study exists | `docs/engineering-case-study.md` | Done | Central reviewer narrative. |
| Repository docs are tested | `test/repository_spec_compliance_test.rb` | Done | Verifies required docs and event schemas. |
| Test strategy is documented | `docs/testing-strategy.md`, `bin/ci` | Done | Minitest, fixtures, system tests, CI, and release checks are explicit. |
| CI passes | `.github/workflows/ci.yml`, `bin/ci` | Done | Recorded in verification report. |
| HTTP connector executes real requests | `app/services/flow_bridge/http_client.rb`, `test/services/node_executor_test.rb` | Done | Uses loopback HTTP in tests; no third-party service dependency. |
| HTTP connector blocks SSRF egress | `app/services/flow_bridge/http_egress_policy.rb`, `test/services/http_egress_policy_test.rb` | Done | Blocks private/link-local/loopback/metadata ranges unless explicitly allowlisted. |
| Workflow graph is validated before publication | `app/services/flow_bridge/workflow_graph_validator.rb`, `test/models/workflow_version_test.rb` | Done | Rejects invalid node shape, HTTP config, filter config, trigger placement, and retry policy. |
| Duplicate execution attempts are guarded | `app/services/flow_bridge/execution_runner.rb`, `test/services/execution_runner_test.rb` | Done | Recent running executions are treated as active leases. |
| Rate limits use atomic increments | `app/services/flow_bridge/rate_limiter.rb`, `test/integration/rate_limiting_and_metrics_test.rb` | Done | API key limit and public bootstrap limit share the limiter. |
| Public bootstrap has abuse controls | `app/controllers/api/v1/organizations_controller.rb`, `openapi.yaml`, `test/integration/rate_limiting_and_metrics_test.rb` | Done | IP/hour cap and client-supplied plan/limit ignored. |
| Internal serverless API is documented | `openapi.yaml`, `test/integration/openapi_response_contract_test.rb`, `test/integration/serverless_webhook_ingress_test.rb` | Done | `/api/v1/serverless/webhooks/{trigger_key}` has schema, response contract, signature, and idempotency tests. |

## Out of Scope

- Visual workflow graph editor.
- OAuth connector lifecycle and credential rotation UI.
- Full Event Sourcing for execution history.
- RabbitMQ or broker-native DLQ adoption.
- Kubernetes, service mesh, and multi-region deployment.
- Published production benchmark numbers from a hosted environment.
