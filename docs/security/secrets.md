# Secrets Management

## Secret sources

- Rails credentials for framework-level encrypted configuration.
- Environment variables for deploy-time secrets.
- GitHub repository secrets for CI/CD deployment.
- `.kamal/secrets` references environment variables; it does not contain raw production values.

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

## Operational rules

- Never commit raw production secrets.
- Rotate API keys when token leakage is suspected.
- Rotate webhook secrets by publishing a new workflow version.
- Rotate database and registry credentials through environment configuration, not code changes.
- Treat CI logs as observable by maintainers and avoid printing secret values.
