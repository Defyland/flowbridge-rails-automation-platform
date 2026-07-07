# ADR 007: Serverless Webhook Ingress Boundary

## Status

Accepted.

## Context

FlowBridge already supported direct signed webhook ingestion through Rails:

```text
POST /api/v1/webhooks/:trigger_key
```

That path is still the simplest local and demo route. The senior-readiness gap was not "more Markdown"; it was evidence that the project can isolate provider-edge concerns behind a small serverless boundary without moving the workflow engine out of the Rails monolith.

The concrete requirement being addressed is experience with serverless architectures, microservice boundaries, cloud deployment/ops, infrastructure as code, security, automated tests, and internal API documentation.

## Options considered

### Keep only direct Rails webhooks

Pros:

- fewer moving parts;
- easiest local setup;
- no cloud-specific code path.

Cons:

- every provider-specific ingress concern stays coupled to the Rails app;
- no concrete serverless or IaC evidence;
- harder to show burst throttling, edge deploy independence, and provider-specific normalization.

Rejected because it does not close the technical requirement.

### Move all webhook persistence to Lambda plus SQS

Pros:

- stronger burst absorption;
- Rails downtime would not necessarily reject provider traffic;
- clear async cloud-native ingress.

Cons:

- would introduce a second durable queue contract before the Rails source-of-truth boundary is stable;
- would require an SQS consumer and operational runbooks before the project has real production traffic;
- higher chance of speculative complexity for a portfolio-sized app.

Rejected for this iteration. It remains the next step if benchmarked provider volume justifies it.

### Add Lambda/API Gateway as a normalizing edge that signs an internal Rails envelope

Pros:

- creates a real serverless microservice boundary;
- keeps idempotency, audit logging, workflow lookup, execution creation, and queueing inside the existing Rails transaction boundary;
- gives the app a documented internal API contract through OpenAPI;
- lets the edge evolve per provider without rewriting the workflow engine;
- can later switch the Lambda relay target from Rails HTTP to SQS while preserving the provider-facing URL.

Cons:

- synchronous relay means Rails availability still affects provider acknowledgements;
- one shared serverless ingress secret must be protected and rotated;
- operational visibility now spans API Gateway, Lambda, Rails, PostgreSQL, and Solid Queue.

Chosen because it is concrete, testable, and proportionate to the current product stage.

## Decision

Add a serverless ingress boundary made of:

- `POST /api/v1/serverless/webhooks/:trigger_key`, an internal Rails endpoint that accepts signed normalized envelopes;
- `FlowBridge::ServerlessWebhookEnvelope`, the Rails contract parser for source, external event id, payload, raw-body digest, headers, and correlation id;
- `services/serverless/webhook_ingress`, a standalone Ruby Lambda handler that receives API Gateway HTTP API v2 events, normalizes provider payloads, signs the envelope, and relays it to Rails;
- `infra/opentofu/aws-serverless-ingress`, an OpenTofu/Terraform module for API Gateway, Lambda, CloudWatch logs, IAM, throttling, and Secrets Manager access;
- `bin/infra-check`, a local/CI gate that runs Terraform/OpenTofu `fmt`, `init -backend=false`, and `validate` when available, with static smoke checks as an environment fallback.

The Lambda reads `FLOWBRIDGE_SERVERLESS_INGRESS_SECRET_ARN` and fetches the shared HMAC secret from Secrets Manager. The Terraform module intentionally passes the ARN, not the secret value, so the secret is not stored in Terraform state by this module.

## Consequences

Positive:

- serverless and IaC requirements now have executable code, not only documentation;
- provider-edge concerns are isolated from the workflow engine;
- OpenAPI route coverage prevents internal API drift;
- Lambda code is testable without AWS and without Rails;
- Terraform provider versions are locked in `.terraform.lock.hcl`.

Negative:

- the ingress path has more operational surfaces;
- Rails remains in the synchronous acknowledgement path;
- API Gateway throttling must be tuned per provider and tenant;
- production use needs CloudWatch alarms, secret rotation procedure, and provider-specific signature validation.

## Evidence

- `PATH=/Users/allanflavio/.asdf/shims:$PATH bin/rails test test/services/serverless_webhook_envelope_test.rb test/integration/serverless_webhook_ingress_test.rb`
  - Result: passed, 6 runs, 28 assertions.
- `PATH=/Users/allanflavio/.asdf/shims:$PATH bin/rails test test/integration/openapi_response_contract_test.rb test/repository_spec_compliance_test.rb test/services/serverless_webhook_envelope_test.rb test/integration/serverless_webhook_ingress_test.rb`
  - Result: passed, 13 runs, 1234 assertions.
- `ruby -I services/serverless/webhook_ingress/lib services/serverless/webhook_ingress/test/flowbridge_serverless_ingress_test.rb`
  - Result: passed, 4 runs, 25 assertions.
- `ASDF_TERRAFORM_VERSION=1.9.8 bin/infra-check`
  - Result: passed; Terraform `fmt`, `init -backend=false`, and `validate` succeeded.
- `PATH=/Users/allanflavio/.asdf/shims:$PATH bin/rubocop app/services/flow_bridge/serverless_webhook_envelope.rb app/controllers/api/v1/serverless_webhooks_controller.rb test/services/serverless_webhook_envelope_test.rb test/integration/serverless_webhook_ingress_test.rb test/integration/openapi_response_contract_test.rb`
  - Result: passed, no offenses.
