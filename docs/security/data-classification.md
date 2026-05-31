# Data Classification

| Data class | Examples | Sensitivity | Handling |
| --- | --- | --- | --- |
| Public metadata | workflow name, plan name, status labels | Low | Safe in docs and UI. |
| Tenant identifiers | organization ID, workflow ID, execution ID | Medium | Scoped by tenant and role. |
| Webhook payloads | source event body, customer lifecycle data | High | Persist only for execution evidence, mask secrets. |
| Credential material | API tokens, bearer tokens, webhook secrets | Critical | Encrypt at rest, never render raw. |
| Signature material | webhook signatures, signed callback query tokens | Critical | Verify at ingress, mask before persistence. |
| API key raw token | `fbk_*` token returned on creation | Critical | Return once, store digest only. |
| Audit metadata | actor, action, subject, IP address | Medium | Append-only evidence, no secret values. |
| Logs and metrics | request ID, correlation ID, counts, timings | Medium | Structured logs, no payload secrets. |
| Dead-letter evidence | failure reason, execution reference, masked payload | High | Operator-only, retention required. |

## Rules

- Raw credentials must not appear in events, node outputs, audit logs, dead letters, or logs.
- Raw signatures and sensitive connector URL query parameters must not be stored as operational evidence.
- Webhook payloads are operational evidence and should be retained only as long as needed.
- Correlation IDs are safe to propagate but should not encode PII.
- Metrics should aggregate counts and durations rather than expose payload content.
