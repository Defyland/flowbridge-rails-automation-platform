# Operational Cost

## Infrastructure cost

The MVP intentionally uses a small infrastructure footprint:

- Rails web process
- Rails/Solid Queue worker process
- PostgreSQL primary database
- PostgreSQL-backed Solid Queue, Cache, and Cable databases
- Docker image
- Kamal deployment host

This keeps a portfolio or small SaaS deployment understandable and cheap. The trade-off is that PostgreSQL carries more responsibility than it would in a Redis/Sidekiq/RabbitMQ architecture.

## Debugging cost

FlowBridge pays storage cost to reduce debugging cost:

- webhook events keep ingress evidence
- workflow executions keep lifecycle state
- node executions keep per-node evidence
- dead letters keep terminal failure records
- audit logs keep operator action history

This makes incidents easier to reconstruct but requires retention decisions as volume grows.

## Deploy cost

Kamal and Thruster provide a concrete production path without requiring Heroku/Fly/Render or Kubernetes. The deploy workflow is manual and protected because real production requires secrets, SSH access, and host state.

Accepted cost:

- maintain server access and registry credentials
- configure protected GitHub environment
- manage database backups separately

Deferred cost:

- Kubernetes cluster operations
- service mesh
- managed queue/broker operations

## Backup and retention cost

Tables with likely retention pressure:

- `webhook_events`
- `workflow_executions`
- `node_executions`
- `dead_letters`
- `audit_logs`
- Solid Queue completed/failed jobs

The MVP documents the need for retention but does not implement automated purging because retention depends on tenant/compliance requirements.

## Monitoring cost

Current monitoring evidence:

- `/up`
- `/ready`
- `/metrics`
- structured logs
- correlation IDs
- OpenTelemetry hooks
- Grafana dashboard JSON

Remaining operational work:

- alert thresholds
- notification routing
- dashboard screenshots from a real environment
- synthetic webhook canary

## Vendor lock-in

The current design avoids heavy managed-service lock-in. PostgreSQL and Rails are portable. Kamal assumes control over server/Docker deployment. Future provider adapters should isolate third-party APIs behind explicit services.

## Simpler alternatives accepted

- Solid Queue instead of Sidekiq/RabbitMQ for MVP.
- ERB/Hotwire instead of React SPA.
- Relational history instead of Event Sourcing.
- Manual deploy instead of automatic production deploy.

These choices reduce operational cost while preserving a clear future upgrade path.
