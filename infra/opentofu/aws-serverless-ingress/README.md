# AWS Serverless Webhook Ingress

This module exposes a small API Gateway + Lambda edge service for provider webhooks that should be normalized before reaching the Rails monolith.

The Lambda receives an API Gateway HTTP API v2 event, builds the `ServerlessWebhookEnvelopeRequest` contract, signs it with the FlowBridge serverless ingress secret, and relays it to:

```text
POST /api/v1/serverless/webhooks/:trigger_key
```

The Rails endpoint remains the durable source of truth: it performs workflow lookup, idempotency, `WebhookEvent` persistence, `WorkflowExecution` creation, audit logging, and queueing.

## Why This Exists

Direct provider webhooks are simple, but they couple every provider edge concern to the Rails app. This module creates an explicit microservice boundary for:

- provider-specific header and event-id extraction;
- burst absorption through API Gateway throttling;
- independent deploy and rollback of ingress behavior;
- future migration to async SQS ingestion without changing public provider URLs.

## Required Inputs

- `rails_ingress_url`: the HTTPS origin of the Rails app.
- `provider_source`: stable provider/source name, for example `stripe`.
- `serverless_ingress_secret_arn`: Secrets Manager ARN containing the shared HMAC secret also configured in Rails as `FLOWBRIDGE_SERVERLESS_INGRESS_SECRET`.

The secret value is intentionally not passed as a Terraform variable because Terraform state would retain it.

## Validation

```bash
bin/infra-check
```

When `tofu` or `terraform` is installed, the gate runs `fmt`, `init -backend=false`, and `validate`. Without either tool it still checks that the module includes the expected API Gateway, Lambda, IAM, logging, and secret-ARN wiring.
