# Product Problem

FlowBridge addresses a common integration failure mode: teams receive important SaaS or fintech webhooks, but production automation becomes unreliable when events are duplicated, workflow definitions change mid-flight, third-party calls fail transiently, and operators cannot see the exact node that failed.

The product is a workflow automation backend with stronger operational guarantees than a simple webhook receiver. It accepts signed webhook events, enforces idempotency, executes immutable workflow versions asynchronously, records node-level evidence, and exposes an operator console for retry and dead-letter handling.

## Business value

- Reduce duplicate downstream actions caused by webhook retries.
- Preserve execution evidence for support and incident review.
- Let operators resolve failures without direct database access.
- Make workflow changes safer by separating mutable workflow metadata from immutable executable versions.

## Core workflow

1. A tenant creates an organization and owner API key.
2. The tenant creates a workflow container.
3. The tenant publishes an immutable workflow version.
4. A source system sends a signed webhook event.
5. FlowBridge validates signature and idempotency.
6. A durable job executes the workflow version node by node.
7. Operators inspect execution evidence and handle dead letters.
