# DHH Stack Implementation Plan

FlowBridge started as an API-only Rails service to prove webhook ingestion, immutable workflow execution, retries, dead letters, observability, and security controls. The next implementation phase keeps that backend core intact and moves the repository closer to the modern Rails production stack: PostgreSQL, Hotwire, Solid Queue, Solid Cache, Solid Cable, Rails authentication, Kamal, and Thruster.

## Goal

Turn FlowBridge into a hybrid Rails monolith:

- machine-to-machine traffic remains JSON API and signed webhooks
- human operators use server-rendered ERB screens
- asynchronous execution uses durable database-backed Solid Queue
- production deployment is documented around Docker, Thruster, and Kamal
- tests cover API behavior and the operator console

## Non-goals

- Do not replace the JSON API with HTML endpoints.
- Do not add React, Vite, Sidekiq, Redis, or FactoryBot.
- Do not build a visual workflow graph editor in this phase.
- Do not add Action Text unless workflow notes or rich templates become real product requirements.

## Phase 1: Runtime foundation

- Upgrade local Ruby target to 3.4+.
- Convert Rails from API-only to a hybrid app.
- Use PostgreSQL for development, test, and production.
- Add Propshaft, Importmap, Turbo, Stimulus, bcrypt, Solid Queue, Solid Cache, Solid Cable, Kamal, and Thruster.
- Enable Action Mailer, Active Storage, and Action Cable.
- Keep Action Text disabled until rich text is needed.

## Phase 2: Durable async and database-backed Rails services

- Replace the default `async` Active Job adapter with `solid_queue`.
- Add queue, cache, and cable database configurations.
- Install Solid Queue, Solid Cache, and Solid Cable schemas/configuration.
- Keep existing workflow execution state tables as product evidence; use Solid Queue only as the durable job transport.

## Phase 3: Operator authentication and tenant context

- Use the Rails authentication generator for human users and sessions.
- Add organization membership for users.
- Keep API keys for integrations and webhook sources.
- Use `Current.user` and `Current.organization` carefully at web request boundaries only.

## Phase 4: Operator console

- Add ERB/Hotwire screens for:
  - dashboard overview
  - workflow list and detail
  - execution list and detail
  - dead-letter list with retry and resolve actions
- Keep the UI operational and dense. The product is an automation operations console, not a marketing site.

## Phase 5: Test and deployment hardening

- Add fixtures for organizations, users, workflows, workflow versions, executions, and dead letters.
- Keep existing Minitest request/model/service/job coverage.
- Add Capybara system tests for login, execution inspection, and dead-letter actions.
- Update CI to run PostgreSQL-backed tests and system tests.
- Add Kamal/Thruster deployment configuration and production runbook notes.

## Acceptance criteria

- `bin/rails test:all` passes against PostgreSQL.
- `bin/rubocop` passes.
- `bin/brakeman --no-pager` passes.
- `bin/bundler-audit` passes.
- `npx --yes @redocly/cli lint openapi.yaml` passes.
- `docker build -t flowbridge:test .` passes.
- Operator console can log in, inspect executions, and act on dead letters.
