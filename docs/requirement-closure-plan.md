# Requirement Closure Plan

| Requirement | Evidence |
| --- | --- |
| Product narrative | `README.md` |
| Architecture overview | `docs/architecture/overview.md` |
| Domain model | `README.md`, `db/schema.rb`, model files |
| API contract | `openapi.yaml`, `docs/api/http-examples.md` |
| Error format | `docs/api/error-format.md` |
| ADRs | `docs/adr/*.md` |
| Unit tests | `test/models`, `test/services` |
| Request tests | `test/integration` |
| System tests | `test/system` with Capybara |
| Authorization tests | `test/integration/authorization_and_isolation_test.rb` |
| Messaging tests | `test/jobs/workflow_execution_job_test.rb` |
| Failure scenarios | `test/integration/webhook_failure_scenarios_test.rb`, `test/services/execution_runner_test.rb` |
| Observability | `/up`, `/ready`, `/metrics`, `config/initializers/logging.rb`, `config/initializers/open_telemetry.rb` |
| Security controls | `docs/security/*.md`, `ApiKey`, `Credential`, signature verifier |
| Performance baseline | `benchmarks/*.js`, `docs/benchmarks/methodology.md`, `benchmarks/baseline.md` |
| CI automation | `.github/workflows/ci.yml` with PostgreSQL service |
| Docker build | `Dockerfile`, CI docker job |

## Senior review checklist

- A reviewer can run the app locally without external dependencies.
- A reviewer can understand the product and architecture from the README.
- Critical behavior is covered by automated tests.
- Failure modes are explicit and operator actions are documented.
- Security and tenant isolation are implemented, documented, and tested.
- Performance scripts and budgets are present.
