# Secrets Management

## Secret sources

- Rails credentials for framework-level encrypted configuration.
- Environment variables for deploy-time secrets.
- GitHub repository secrets for CI/CD deployment.
- `.kamal/secrets.sample` is the tracked template; the real local `.kamal/secrets`
  file stays ignored and should only reference environment variables or local
  secret sources.

## Application secrets

| Secret | Purpose |
| --- | --- |
| `RAILS_MASTER_KEY` | Rails encrypted credentials. |
| `SECRET_KEY_BASE` | Rails session and message verifier base secret. |
| `DATABASE_URL` | Primary database connection. |
| `QUEUE_DATABASE_URL` | Solid Queue database connection. |
| `CACHE_DATABASE_URL` | Solid Cache database connection. |
| `CABLE_DATABASE_URL` | Solid Cable database connection. |
| `KAMAL_REGISTRY_PASSWORD` | Container registry authentication. |
| `KAMAL_SSH_PRIVATE_KEY` | SSH access for Kamal deploy. |

## Product secrets

- API keys are stored as digests and raw tokens are returned once.
- Webhook secrets are encrypted per workflow version.
- Credentials are encrypted per organization.
- Webhook signatures, authorization headers, cookies, credential-bearing headers, and sensitive URL query parameters are masked before being stored as webhook headers, node outputs, errors, audit metadata, or dead-letter evidence.

## Operational rules

- Never commit raw production secrets.
- Rotate API keys when token leakage is suspected.
- Rotate webhook secrets by publishing a new workflow version.
- Do not put connector credentials in URLs. When an upstream requires query credentials, FlowBridge still masks common sensitive parameters in stored evidence, but headers plus encrypted credentials remain the preferred path.
- Rotate database and registry credentials through environment configuration, not code changes.
- Treat CI logs as observable by maintainers and avoid printing secret values.
