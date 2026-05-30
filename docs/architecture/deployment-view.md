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

## Required production secrets

- `KAMAL_SSH_PRIVATE_KEY`
- `KAMAL_REGISTRY_PASSWORD`
- `RAILS_MASTER_KEY`
- `SECRET_KEY_BASE`
- `DATABASE_URL`
- `QUEUE_DATABASE_URL`
- `CACHE_DATABASE_URL`
- `CABLE_DATABASE_URL`

## Deferred deployment work

- Hosted staging environment evidence.
- Backup and restore drill.
- Alert routing.
- Separate worker host sizing.
- Multi-region strategy.
