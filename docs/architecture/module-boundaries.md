# Module Boundaries

## API boundary

Path: `app/controllers/api`

Responsibilities:

- API key authentication
- permission checks
- JSON rendering
- standardized error responses
- request/correlation ID handling

Must not:

- execute workflow nodes inline
- use browser session state
- leak tenant records outside `Current.organization`

## Operator boundary

Path: `app/controllers/operator`, `app/views/operator`

Responsibilities:

- session authentication
- human inspection of workflows, executions, and dead letters
- explicit retry and resolve actions

Must not:

- bypass role checks
- expose raw credentials
- rewrite execution evidence

## Domain service boundary

Path: `app/services/flow_bridge`

Responsibilities:

- workflow publication
- signature verification
- webhook ingestion
- execution state transitions
- node execution
- metrics and masking helpers

Must not:

- depend on view helpers
- depend on controller params directly
- store secrets unmasked in public evidence

## Model boundary

Path: `app/models`

Responsibilities:

- associations
- validations
- lifecycle constraints
- public serialization helpers where small and stable

Must not:

- hide cross-aggregate workflows in callbacks
- make external network calls

## Infrastructure boundary

Path: `config`, `.github`, `Dockerfile`, `bin`

Responsibilities:

- Rails runtime setup
- Solid services
- CI/CD
- deployment
- security tooling

Must not:

- contain production secrets
- require cloud-specific state for local tests
