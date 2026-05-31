# Tech Lead Hardening Spec

This spec closes the hardening gaps found during the senior/tech-lead review. A criterion is `Done` only when code, tests, and docs prove the behavior without requiring production access or third-party services.

## Target

FlowBridge must behave like a production-near Rails automation platform in local and CI validation:

- outbound HTTP connector execution is real, not simulated;
- outbound HTTP connector egress blocks SSRF targets by default;
- workflow graphs fail fast before publication when node config is invalid;
- duplicate jobs cannot run the same execution concurrently;
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
bin/rails test test/services/http_egress_policy_test.rb test/services/node_executor_test.rb test/models/workflow_version_test.rb test/services/execution_runner_test.rb test/integration/rate_limiting_and_metrics_test.rb
```

Expected result: all checks pass locally using only PostgreSQL and loopback HTTP.
