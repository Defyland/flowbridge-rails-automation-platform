# Personas

## Platform engineer

Owns webhook integrations for a SaaS or fintech platform. Cares about idempotency, traceability, retry behavior, and the ability to prove what happened during an incident.

Needs:

- stable API contracts
- signed webhook ingress
- execution evidence
- clear operational runbooks

## Operations analyst

Investigates failed automations and decides whether to retry or resolve dead letters. Does not need direct database access or code-level knowledge.

Needs:

- authenticated operator console
- workflow and execution lookup
- node-level failure reasons
- safe retry and resolve actions

## Security reviewer

Evaluates whether credentials, tokens, tenant data, and webhook sources are protected.

Needs:

- threat model
- authorization matrix
- token and secret handling documentation
- audit and masking behavior

## Technical interviewer

Reviews the repository as evidence of senior Rails/backend judgment.

Needs:

- product context
- architecture rationale
- trade-offs and rejected alternatives
- tests and CI evidence
- honest deferred work
