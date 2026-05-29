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
- Webhook and execution idempotency are enforced by unique indexes.
- Sensitive keys are masked in outputs, audit metadata, and stored webhook headers.
- Rate limiting is enforced per API key per minute.
- Brakeman and bundler-audit run in CI.

## Threats and mitigations

| Threat | Mitigation |
| --- | --- |
| Stolen API key | token digest storage, revocation column, role-scoped permissions |
| Cross-tenant read | tenant-scoped queries and request tests |
| Webhook spoofing | per-version HMAC signatures |
| Webhook replay | idempotency key uniqueness |
| Secret leakage in logs | recursive secret masking and encrypted storage |
| Workflow mutation during replay | immutable workflow versions |
| Retry storm | retry policy with max attempts and dead letters |

## Residual risks

- Local rate limiting uses Rails cache and is not distributed until backed by Redis or another shared cache.
- Credential rotation workflows are planned but not yet implemented.
- External HTTP calls are represented by deterministic mock nodes in this implementation slice.
