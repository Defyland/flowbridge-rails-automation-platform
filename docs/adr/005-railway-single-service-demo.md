# ADR 005: Railway Single-Service Demo Deployment

## Status

Accepted.

## Context

FlowBridge already had a production-oriented Dockerfile, explicit `/up` and
`/ready` endpoints, and a Kamal deploy workflow. What it lacked was a small,
public, config-as-code deployment surface for evaluator use.

The repository also tracked `.kamal/secrets`, which is acceptable for local
operator convenience only if the real file never becomes publishable. That is
the wrong default for a GitHub-public asset.

## Options considered

- Keep Kamal as the only documented deploy path.
  Rejected because it leaves reviewers without a lightweight public demo route.
- Add a second Docker layout just for Railway.
  Rejected because it would add deploy-specific complexity without changing the
  application contract.
- Add a Railway single-service path on top of the existing production image.
  Chosen because it reuses the current container contract and keeps the public
  deploy story small.

## Decision

Add `railway.json` and `RAILWAY_DEPLOY.md`, document Railway as a single-service
demo topology that runs with `SOLID_QUEUE_IN_PUMA=true`, and replace the tracked
Kamal secrets file with a checked-in `.kamal/secrets.sample` plus a gitignored
real `.kamal/secrets`.

## Consequences

Positive:

- the repository gains a public demo path without a second Docker layout;
- activation and readiness checks become explicit for Railway review;
- the publishable tree no longer includes a real Kamal secrets file.

Negative:

- the Railway path is not the final multi-process production shape;
- queue, cache, and cable reuse one PostgreSQL URL in the demo path;
- real deployment still requires environment-specific secret and alert wiring.

## Verification evidence

- `ruby -rjson -e 'JSON.parse(File.read("railway.json"))'`
- `PATH=/Users/allanflavio/.asdf/shims:$PATH bin/ci`
- `PATH=/Users/allanflavio/.asdf/shims:$PATH /Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/eval-harness/bin/eval-harness . --output /tmp/flowbridge-ai-ready.md`
