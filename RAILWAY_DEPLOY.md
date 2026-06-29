# Railway Deploy

This guide configures FlowBridge as a single-service Railway deployment for
public demo and reviewer evaluation.

## Runtime shape

- builder: `Dockerfile`
- activation health check: `/up`
- readiness endpoint available separately at `/ready`
- database migration/bootstrap: `bin/docker-entrypoint` runs `db:prepare`
- background jobs: `SOLID_QUEUE_IN_PUMA=true` keeps queue execution in the web
  process for the demo topology

The Railway path is intentionally smaller than the Kamal topology. It proves the
product surface without introducing a second deployment-specific container
layout.

## Required variables

Set these in Railway:

```bash
RAILS_ENV=production
APP_HOST=<your-public-railway-domain>
DATABASE_URL=${{Postgres.DATABASE_URL}}
QUEUE_DATABASE_URL=${{Postgres.DATABASE_URL}}
CACHE_DATABASE_URL=${{Postgres.DATABASE_URL}}
CABLE_DATABASE_URL=${{Postgres.DATABASE_URL}}
RAILS_MASTER_KEY=<local config/master.key>
SECRET_KEY_BASE=<generated-secret>
SOLID_QUEUE_IN_PUMA=true
RAILS_SERVE_STATIC_FILES=true
```

Optional variables for richer demo behavior:

```bash
OTEL_ENABLED=true
OTEL_EXPORTER_OTLP_ENDPOINT=<collector-endpoint>
```

## Suggested flow

```bash
railway login
railway init --name flowbridge-automation-platform
railway add --database postgres
railway up
railway domain
```

## Five-minute verification

After deploy:

```bash
railway status
railway logs
curl -fsS "$RAILWAY_PUBLIC_DOMAIN/up"
curl -fsS "$RAILWAY_PUBLIC_DOMAIN/ready"
```

Then sign in to `/session/new` and inspect one workflow plus one execution or
dead-letter path in the operator console.

## Limits

- The Railway path is a demo topology, not the final production topology.
- Queue, cache, and cable reuse the primary PostgreSQL URL for demo simplicity.
- The web process also supervises background work in this deployment mode.
- Public hosting still depends on real secrets management and operational alerting.
