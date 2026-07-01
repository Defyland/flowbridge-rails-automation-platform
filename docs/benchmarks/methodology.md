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

1. Run `bin/benchmark smoke`, `bin/benchmark load`, `bin/benchmark stress`, `bin/benchmark spike`, or `bin/benchmark all`.
2. The runner prepares the database, starts the app on an isolated port, waits for `/ready`, and writes k6 summaries under `benchmarks/results/`.
3. The runner injects `FLOWBRIDGE_CONNECTOR_PRIVATE_HOST_ALLOWLIST=127.0.0.1,localhost` and disables the public bootstrap limit only for that local benchmark process so the benchmark graph can validate a loopback connector target and create isolated benchmark tenants without changing the repository's default SSRF or abuse-control posture.
4. Update `benchmarks/baseline.md` with measured results and machine notes.
