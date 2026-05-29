# FlowBridge Benchmark Baseline

## Environment

- Date: 2026-05-29
- Runtime target: Ruby 3.4+, Rails 8.1 hybrid monolith
- Database: PostgreSQL local baseline
- Queue adapter: Active Job with Solid Queue
- Machine: local developer workstation

## Current measured baseline

The implementation includes k6 scripts and the benchmark methodology, but this repository run did not start a long-lived server for measured k6 output. The validation target for a portfolio review is that the scripts are present, runnable, and document the metrics that must be captured.

| Scenario | Target | Status |
| --- | --- | --- |
| Smoke | p95 < 300 ms, error rate 0% | Scripted |
| Load | p95 < 500 ms, error rate < 1% | Scripted |
| Stress | graceful retry/dead-letter behavior | Scripted |
| Spike | no duplicate executions for replayed events | Scripted |

## Budgets

- Authenticated API p95: 300 ms local
- Signed webhook ingress p95: 500 ms local
- Error rate: less than 1% excluding intentional failure scenarios
- Dead-letter creation: deterministic after retry exhaustion

## Next measurement step

Run:

```bash
bin/rails server
k6 run benchmarks/smoke.js
k6 run benchmarks/load.js
k6 run benchmarks/stress.js
k6 run benchmarks/spike.js
```
