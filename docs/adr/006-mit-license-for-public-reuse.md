# ADR 006: Publish The Repo Under MIT

## Status

Accepted

## Context

`flowbridge-rails-automation-platform` is already public and intentionally used
as a specialist-grade study asset. The repo already exposes architecture,
domain, runbook, and deployment material, but without an explicit license the
reuse story is still incomplete.

## Decision

Add an explicit MIT license and reference it from the README.

## Consequences

Positive:

- public reuse and adaptation become explicit;
- the repo aligns its legal surface with its didactic purpose;
- downstream tooling and study flows can cite a clear reuse contract.

Negative:

- broad reuse is allowed with limited reciprocity;
- derivative work is not required to stay open.

## Verification evidence

- `PATH=/Users/allanflavio/.asdf/shims:$PATH /Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/eval-harness/bin/eval-harness . --output /tmp/flowbridge-ai-ready.md`
