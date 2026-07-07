# Deployment View

## Local development

```text
Rails server
PostgreSQL primary / queue / cache / cable databases
Solid Queue in Puma or bin/jobs
```

Local setup is optimized for reviewer reproducibility:

```bash
bundle install
bin/rails db:prepare
bin/ci
```

## CI

GitHub Actions runs on pull requests and pushes to `main`:

- PostgreSQL-backed Rails tests
- RuboCop
- Brakeman
- bundler-audit
- Redocly OpenAPI validation
- Docker build
- coverage artifact upload

## Production path

Production is designed around Docker, Thruster, and Kamal:

- `Dockerfile` builds the deployable image.
- `bin/thrust` runs Thruster in front of Rails.
- `config/deploy.yml` defines Kamal service, image, hosts, proxy, env, and volume.
- `.github/workflows/deploy.yml` provides a manual protected deployment workflow.

## Serverless edge path

High-volume or provider-specific webhook ingress can be deployed separately from the Rails container:

```text
Provider webhook
API Gateway HTTP API
Ruby Lambda normalizer
POST /api/v1/serverless/webhooks/:trigger_key
Rails webhook ingestor
PostgreSQL + Solid Queue
```

The infrastructure lives in [../../infra/opentofu/aws-serverless-ingress](../../infra/opentofu/aws-serverless-ingress). It provisions API Gateway, Lambda, CloudWatch log groups, IAM policies, throttling, and Secrets Manager access. The Lambda package is built from [../../services/serverless/webhook_ingress](../../services/serverless/webhook_ingress).

This path is not a replacement for the monolith. It is an edge microservice for normalization, throttling, and independent provider-facing deployment. Rails remains the source of truth for idempotency and execution.

## Required production secrets

- `KAMAL_SSH_PRIVATE_KEY`
- `KAMAL_REGISTRY_PASSWORD`
- `RAILS_MASTER_KEY`
- `SECRET_KEY_BASE`
- `DATABASE_URL`
- `QUEUE_DATABASE_URL`
- `CACHE_DATABASE_URL`
- `CABLE_DATABASE_URL`
- `FLOWBRIDGE_SERVERLESS_INGRESS_SECRET`

## Deferred deployment work

- Hosted staging environment evidence.
- Backup and restore drill.
- Alert routing.
- Separate worker host sizing.
- Multi-region strategy.
- API Gateway/Lambda CloudWatch alarms and secret rotation drill for the serverless edge.
