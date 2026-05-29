# Benchmark Methodology

FlowBridge benchmark scripts use k6 and exercise the product path that matters most: authenticated workflow setup followed by signed webhook ingestion.

## Scenarios

- `smoke.js`: short validation run with one virtual user.
- `load.js`: steady traffic that should remain below p95 latency budget.
- `stress.js`: increasing traffic to observe degradation behavior.
- `spike.js`: sudden traffic jump to test queue and rate-limit behavior.

## Metrics to report

- p50, p95, and p99 request latency
- throughput
- error rate
- open dead-letter count
- local CPU and memory notes

## Local process

1. Start the app with `RAILS_ENV=development bin/rails server`.
2. Run `k6 run benchmarks/smoke.js`.
3. Run load, stress, and spike scripts.
4. Store summaries in `benchmarks/results/`.
5. Update `benchmarks/baseline.md` with measured results and machine notes.
