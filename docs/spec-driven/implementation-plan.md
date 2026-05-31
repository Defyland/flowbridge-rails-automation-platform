# Implementation Plan

## Scope

Apply the shared senior engineering and spec-driven standards to FlowBridge and close the production-near gaps found in the senior review. The work is spec-first and evidence-driven: runtime behavior changes must have tests and documentation.

## Files to Create or Update

| File or directory | Purpose |
| --- | --- |
| `docs/spec-driven/senior-readiness-spec.md` | Acceptance criteria and evidence matrix for senior readiness. |
| `docs/spec-driven/implementation-plan.md` | Maps changes to the requested quality gates. |
| `docs/spec-driven/verification-report.md` | Records commands, results, partial criteria, and remaining risk. |
| `docs/engineering-case-study.md` | Central senior-level case study. |
| `docs/product/*.md` | Product problem, personas, use cases, non-goals, roadmap, and plans. |
| `docs/domain/*.md` | Glossary, contexts, aggregates, invariants, and state machines. |
| `docs/architecture/*.md` | C4, module boundaries, sequence diagrams, deployment, workflow engine. |
| `docs/security/*.md` | Threat model, authorization, secrets, data classification, abuse cases. |
| `docs/observability.md` | Health, readiness, metrics, logs, traces, dashboards, and alert candidates. |
| `docs/testing-strategy.md` | Test layers, fixture strategy, CI gates, and known test gaps. |
| `docs/scalability.md` | Hot paths, bottlenecks, consistency and growth strategy. |
| `docs/operational-cost.md` | Operational cost and simpler alternatives. |
| `README.md` | Link to case study, spec-driven evidence, and new docs. |
| `test/repository_spec_compliance_test.rb` | Guard required docs and event schemas. |
| `app/services/flow_bridge/http_client.rb` | Real outbound HTTP connector with timeouts and safe response capture. |
| `app/services/flow_bridge/workflow_graph_validator.rb` | Fail-fast graph and retry-policy validation. |
| `app/services/flow_bridge/rate_limiter.rb` | Atomic cache-backed rate limit primitive with fallback. |
| `test/services/node_executor_test.rb` | Loopback HTTP proof for connector behavior and masking. |

## Acceptance Criteria Mapping

| Acceptance criterion | Planned change |
| --- | --- |
| Product docs name user, problem, workflow, non-goals, and roadmap | Create `docs/product/*` and link from README. |
| Domain docs define language and invariants | Create `docs/domain/*` from current models/services. |
| Architecture docs justify monolith and engine boundaries | Add C4, module boundaries, sequence diagrams, deployment view, and workflow engine references. |
| Security docs cover abuse cases and secrets | Add `data-classification.md`, `secrets.md`, and `abuse-cases.md`; keep threat model aligned. |
| Observability is explicit | Add `docs/observability.md` and link to health, readiness, metrics, logs, traces, Grafana, and runbooks. |
| Test strategy is explicit | Add `docs/testing-strategy.md` and keep repository compliance enforced in Minitest. |
| Scalability and cost are explicit | Add `docs/scalability.md` and `docs/operational-cost.md`. |
| Spec-driven workflow is auditable | Add the three required files under `docs/spec-driven/`. |
| Docs match system behavior | Update `test/repository_spec_compliance_test.rb` to assert mandatory docs and parse event schemas. |
| Verification is reproducible | Run local docs checks, JSON/YAML parsing, Redocly, and `bin/ci`; record results. |
| HTTP connector is production-near | Replace mock-only behavior with `Net::HTTP`, timeouts, status classification, credential headers, and loopback tests. |
| Graph config fails fast | Validate node shape, trigger position, HTTP URL/method/headers/timeout, filter config, and retry policy. |
| Abuse controls are explicit | Add atomic API key rate limiting and IP/hour bootstrap limiting; remove public plan/rate-limit assignment. |

## Verification Commands

```bash
git status --short --branch
ruby -rjson -e 'Dir["docs/events/*.json"].sort.each { |file| JSON.parse(File.read(file)); puts "#{file}: OK" }'
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci.yml"); YAML.load_file(".github/workflows/deploy.yml"); puts "workflow yaml: OK"'
ruby -e 'require "yaml"; YAML.load_file("openapi.yaml"); puts "openapi yaml: OK"'
npx --yes @redocly/cli lint openapi.yaml
bin/rails test test/repository_spec_compliance_test.rb
bin/ci
docker build -t flowbridge:test .
```

## Risks

- Documentation can overclaim maturity. The spec marks measured benchmark output as `Partial` until a long-lived server run is captured.
- Event contracts are currently documented and parsed, but not yet emitted to an external broker.
- Deploy workflow is configured and validated structurally, but real production deploy depends on external secrets and VPS/cloud state.

## Deferred Work

- Capture k6 results from a stable local or staging environment and store summaries in `benchmarks/results/`.
- Add connector-specific auth adapters, outbound idempotency-key propagation, and vendor contract tests.
- Add alert thresholds for queue depth, dead-letter growth, and signature failures.
- Add production backup/restore drill evidence.
