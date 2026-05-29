# ADR 001: PostgreSQL-backed hybrid Rails monolith

## Status

Accepted

## Context

FlowBridge needs to demonstrate a serious Rails production posture while keeping the webhook and automation engine easy to reason about. The initial API-only slice proved the backend domain. The next phase needs an operator console, durable framework services, and a database setup closer to a SaaS deployment.

## Decision

Use Rails as a hybrid monolith:

- JSON APIs and signed webhooks stay under `/api/v1`.
- Human operators use ERB, Turbo, Stimulus, Importmap, and Propshaft.
- PostgreSQL is the primary database for development, test, and production.
- Solid Queue, Solid Cache, and Solid Cable use PostgreSQL-backed database configurations.
- Rails authentication handles human operator sessions.

## Consequences

- The app is no longer `api_only`.
- Local development requires PostgreSQL.
- The operator console can use the same domain models and service objects as the API.
- CI validates request tests and Capybara system tests against PostgreSQL.
- Deployments can use Docker, Thruster, and Kamal without introducing Redis or Sidekiq.
