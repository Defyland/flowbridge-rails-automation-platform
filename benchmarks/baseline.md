# FlowBridge Benchmark Baseline

## Environment

- Date: 2026-07-01
- Command: `PATH=/Users/allanflavio/.asdf/shims:$PATH bin/benchmark all`
- Runtime target: Ruby 3.4.9, Rails 8.1.3, single local Puma process
- Database: local PostgreSQL
- Queue adapter: Solid Queue
- Benchmark harness:
  - isolated app port via `bin/benchmark`
  - loopback connector target allowlisted only inside the benchmark process
  - public organization bootstrap limit disabled only inside the benchmark process
- Raw artifacts:
  - `benchmarks/results/2026-07-01T03-18-36Z-smoke.json`
  - `benchmarks/results/2026-07-01T03-18-36Z-load.json`
  - `benchmarks/results/2026-07-01T03-18-36Z-stress.json`
  - `benchmarks/results/2026-07-01T03-18-36Z-spike.json`

## Current measured baseline

These numbers measure the tagged `stage:ingress` webhook path after setup and
warm-up, not the organization/workflow bootstrap requests used to prepare the
scenario.

| Scenario | Budget | Measured local baseline | Status |
| --- | --- | --- | --- |
| Smoke | p95 < 500 ms, error rate < 1% | 5 webhook iterations, 9.27 req/s, p50 35.20 ms, p95 45.32 ms, p99 46.97 ms, max 47.38 ms, error rate 0.00% | Pass |
| Load | p95 < 500 ms, p99 < 900 ms, error rate < 1% | 3,172 webhook iterations, 30.17 req/s, p50 230.41 ms, p95 627.33 ms, p99 1186.78 ms, max 3796.77 ms, error rate 0.00% | Fail: latency budget exceeded |
| Stress | p95 < 1000 ms, p99 < 1500 ms, error rate < 5% | 3,832 webhook iterations, 31.79 req/s, p50 648.35 ms, p95 1360.65 ms, p99 1466.82 ms, max 1569.23 ms, error rate 0.00% | Fail: p95 budget exceeded |
| Spike | p95 < 1200 ms, p99 < 1800 ms, error rate < 5% | 1,736 webhook iterations, 34.25 req/s, p50 1389.22 ms, p95 1700.72 ms, p99 1757.79 ms, max 1801.40 ms, error rate 0.00% | Fail: p95 budget exceeded |

## Interpretation

- The benchmark path is now executable and self-contained for local review.
- The ingress contract stays functionally stable under all recorded scenarios:
  error rate remained `0.00%`.
- The local single-process baseline is comfortably inside budget for smoke.
- Under sustained load and heavier concurrency, the local setup degrades on
  latency before it degrades on correctness.
- These failures are intentionally kept as measured evidence, not rewritten
  into a fake green story.

## Next measurement step

The next performance loop should target measured improvement, not more benchmark
scaffolding:

1. rerun the same harness with a production-like web process shape;
2. isolate the top latency contributors in webhook ingress;
3. record the before/after delta against these exact local artifacts.
