# Tech Lead Hardening Spec

This spec closes the hardening gaps found during the senior/tech-lead review. A criterion is `Done` only when code, tests, and docs prove the behavior without requiring production access or third-party services.

## Target

FlowBridge must behave like a production-near Rails automation platform in local and CI validation:

- outbound HTTP connector execution is real, not simulated;
- outbound HTTP connector egress blocks SSRF targets by default;
- workflow graphs fail fast before publication when node config is invalid;
- duplicate jobs cannot run the same execution concurrently;
- outbound unsafe HTTP methods carry deterministic idempotency and correlation headers;
- Prometheus metrics expose node execution, retry, duration, and dead-letter dimensions;
- OpenAPI documents every versioned API route with executable JSON response schemas;
- API and bootstrap rate limits use atomic cache increments;
- public tenant bootstrap has abuse controls and does not allow clients to self-assign privileged limits;
- tests prove the above with local-only infrastructure.

## Acceptance Criteria

| Gap | Required behavior | Evidence |
| --- | --- | --- |
| Simulated HTTP connector | `http_request` performs a real `http` or `https` request with timeouts, response capture, and secret-safe evidence. | `FlowBridge::HttpClient`, `FlowBridge::NodeExecutor`, `test/services/node_executor_test.rb` |
| SSRF through HTTP connector | Connector targets are resolved and blocked when they hit loopback, private, link-local, multicast, documentation, or metadata-service networks unless explicitly allowlisted. | `FlowBridge::HttpEgressPolicy`, `test/services/http_egress_policy_test.rb`, `test/services/node_executor_test.rb` |
| Unsafe graph publication | Invalid node type, duplicate key, bad trigger position, bad HTTP config, bad filter config, and invalid retry policy are rejected before `WorkflowVersion` creation succeeds. | `FlowBridge::WorkflowGraphValidator`, `test/models/workflow_version_test.rb` |
| Duplicate execution attempts | A recent `running` execution is treated as actively leased and a second job does not create another attempt. | `FlowBridge::ExecutionRunner`, `test/services/execution_runner_test.rb` |
| Outbound duplicate side effects | Non-GET HTTP connectors receive deterministic `Idempotency-Key` and `X-FlowBridge-Correlation-Id` headers by default. | `FlowBridge::NodeExecutor`, `test/services/node_executor_test.rb` |
| Thin operational metrics | `/metrics` exposes workflow execution status, webhook status, node execution status/type, node duration average, retry count, and dead letters by reason/status. | `FlowBridge::Metrics`, `test/integration/rate_limiting_and_metrics_test.rb` |
| API contract drift | Every `/api/v1` route is present in OpenAPI and every successful JSON response has a schema validated against real integration-test payloads. | `openapi.yaml`, `test/repository_spec_compliance_test.rb`, `test/integration/openapi_response_contract_test.rb` |
| Non-atomic rate limit | API rate limits and public bootstrap limits use cache `increment` with a synchronized fallback. | `FlowBridge::RateLimiter`, `test/integration/rate_limiting_and_metrics_test.rb` |
| Public tenant abuse | Organization creation is IP/hour limited and ignores client-supplied `plan` or `rate_limit_per_minute`. | `Api::V1::OrganizationsController`, OpenAPI create schema, integration tests |
| External dependency in tests | HTTP connector tests use a local TCP server, not internet or SaaS dependencies. | `test/support/api_test_helper.rb` |

## Non-Goals

- Proving hosted production deployment.
- Calling a real SaaS connector.
- Replacing Solid Queue with RabbitMQ.
- Adding a visual workflow editor.

## Reviewer Checklist

Run:

```bash
bin/ci
bin/rails test test/services/http_egress_policy_test.rb test/services/node_executor_test.rb test/models/workflow_version_test.rb test/services/execution_runner_test.rb test/integration/rate_limiting_and_metrics_test.rb test/integration/openapi_response_contract_test.rb test/repository_spec_compliance_test.rb
npx --yes @redocly/cli lint openapi.yaml
```

Expected result: all checks pass locally using only PostgreSQL and loopback HTTP.
