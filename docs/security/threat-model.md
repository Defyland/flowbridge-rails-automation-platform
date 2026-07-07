# Threat Model

## Assets

- API key tokens
- encrypted credential material
- webhook secrets
- workflow execution payloads
- audit logs
- tenant data boundaries

## Controls

- API keys are stored as SHA-256 digests and the raw token is returned once.
- Credentials and webhook secrets are encrypted with `ActiveSupport::MessageEncryptor`.
- Tenant resources are queried through `Current.organization`.
- Webhooks require HMAC SHA-256 signatures.
- Serverless webhook envelopes require a separate Lambda-to-Rails HMAC signature.
- Webhook and execution idempotency are enforced by unique indexes.
- Sensitive keys are masked in outputs, audit metadata, and stored webhook headers.
- Rate limiting is enforced per API key per minute.
- HTTP connector egress resolves target hosts, blocks SSRF-sensitive networks by default, and pins the socket to the vetted IP address.
- Brakeman and bundler-audit run in CI.

## Threats and mitigations

| Threat | Mitigation |
| --- | --- |
| Stolen API key | token digest storage, revocation column, role-scoped permissions |
| Cross-tenant read | tenant-scoped queries and request tests |
| Webhook spoofing | per-version HMAC signatures |
| Serverless edge spoofing | separate `X-FlowBridge-Serverless-Signature`, Secrets Manager-backed edge secret, and OpenAPI-documented internal envelope |
| Webhook replay | idempotency key uniqueness |
| Secret leakage in logs | recursive secret masking and encrypted storage |
| SSRF through connector URL | egress policy blocks loopback, private, link-local, multicast, documentation, and metadata-service networks |
| Workflow mutation during replay | immutable workflow versions |
| Retry storm | retry policy with max attempts and dead letters |

## Focused workflow-engine threats

### Webhook spoofing

Risk: an attacker posts a fake event to a known trigger URL to create executions or exfiltrate behavior through node outputs.

Controls:

- verify HMAC SHA-256 before creating `WebhookEvent` or `WorkflowExecution`
- use per-version webhook secrets instead of shared global secrets
- scope trigger keys to immutable workflow versions
- reject unknown trigger keys with generic responses
- store sanitized headers only

Residual risk:

- source systems with weak signing practices still require source-specific adapters before production onboarding

### Serverless edge spoofing

Risk: an attacker bypasses API Gateway and posts a forged normalized envelope directly to Rails.

Controls:

- require `X-FlowBridge-Serverless-Signature` before parsing the envelope;
- sign the exact raw envelope body with HMAC SHA-256;
- keep the shared serverless secret separate from per-workflow provider webhook secrets;
- load the Lambda-side secret from Secrets Manager ARN rather than a plaintext Terraform variable;
- preserve source, external event id, raw-body SHA-256, and correlation id in the envelope for auditability.

Residual risk:

- a leaked shared serverless secret can target any trigger key exposed through the internal endpoint; production should pair this with network controls, secret rotation, and provider-specific signature verification at the Lambda boundary.

### Token leakage

Risk: API keys, reset tokens, or deployment secrets leak through logs, exceptions, CI output, audit metadata, or browser-visible payloads.

Controls:

- store API keys as digests and return raw tokens only once
- filter sensitive params through Rails parameter filtering
- keep Kamal and database credentials in GitHub secrets, not repository files
- keep API authentication separate from browser session authentication
- role-scope API keys to owner/operator/viewer permissions

Residual risk:

- leaked one-time API tokens cannot be recovered from storage, but they still require revocation and rotation if copied by the receiver

### Manual replay abuse

Risk: an operator retries a dead letter or execution repeatedly, causing duplicate downstream writes or hiding original failure evidence.

Controls:

- preserve original webhook identity and workflow version during replay
- append new attempt evidence instead of overwriting old node evidence
- record replay through audit logs and dead-letter status transitions
- keep idempotency scoped to `source + source_event_id + workflow_version_id`
- require operator permissions for retry and resolve actions

Residual risk:

- downstream systems without idempotent APIs may still observe duplicate side effects; connector-specific idempotency keys should be added before real integrations

### Connector SSRF

Risk: a workflow author points an HTTP connector at instance metadata, loopback services, private control planes, or documentation/bogon networks to extract internal data.

Controls:

- reject non-HTTP schemes before publication
- reject IP-literal connector URLs that target blocked networks before publication
- resolve connector hosts before execution
- block loopback, private, link-local, multicast, documentation, and metadata-service ranges by default
- pin `Net::HTTP` to the vetted address to reduce DNS rebinding exposure
- require explicit `FLOWBRIDGE_CONNECTOR_PRIVATE_HOST_ALLOWLIST` for intentional private targets in local/test/on-prem scenarios
- optionally restrict all connector egress with `FLOWBRIDGE_CONNECTOR_ALLOWED_HOSTS`

Residual risk:

- production deployments should still pair this app-level guard with network-level egress policy and connector-specific allowlists

### Credentials masking

Risk: credentials appear in node inputs, outputs, event payloads, logs, audit metadata, or dead-letter records.

Controls:

- encrypt credential material at rest
- mask recursive secret-bearing keys before rendering or recording execution evidence
- avoid copying raw credential values into event payloads
- treat dead-letter payloads as operator-visible evidence, not a secret vault

Residual risk:

- custom node types must pass a masking review before production use

### Dead-letter queue exposure

Risk: DLQ records become a secondary data leak, replay footgun, or unbounded storage sink.

Controls:

- store reason, execution reference, and masked payload evidence
- restrict DLQ read/retry/resolve actions by role
- require explicit resolution rather than silent deletion
- expose DLQ metrics so growth is visible
- document DLQ triage in runbooks

Residual risk:

- high-volume poison events can still fill the database; production should add retention and alert thresholds

## Residual risks

- Local rate limiting uses Rails cache and is not distributed until backed by Redis or another shared cache.
- Credential rotation workflows are planned but not yet implemented.
- External HTTP calls are real `http_request` connector nodes with local-loopback tests; production connector onboarding still needs vendor-specific idempotency and contract tests.

## Transversal architecture additions

- Webhook signatures must be verified before workflow lookup or execution creation.
- Credential values must never appear in event payloads, execution outputs, audit metadata, or dead-letter records.
- Replay is an operator action and should preserve original event identity while creating new attempt evidence.
- Workflow versions are the execution boundary; mutable drafts must never be used by running executions.
- Dead-letter queues are operational evidence, not a place to hide validation failures.
