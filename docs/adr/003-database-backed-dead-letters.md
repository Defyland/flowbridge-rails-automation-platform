# ADR 003: Database-backed dead letters before external broker adoption

## Status

Accepted

## Context

The product needs retry and dead-letter semantics, but the repository must be runnable without RabbitMQ or Redis. The first implementation slice should prove the behavior and transaction model before adding broker infrastructure.

## Decision

Use Active Job for asynchronous execution and persist retry/dead-letter state in the application database. `WorkflowExecutionJob` is the consumer boundary. `WorkflowExecution`, `NodeExecution`, and `DeadLetter` hold durable execution state and operator actions.

## Consequences

- The app demonstrates queue-like behavior with no external runtime dependency.
- Dead letters can be queried, retried, and resolved through HTTP APIs.
- Correlation IDs and audit logs stay in the same transactional system.
- RabbitMQ can be added later by mapping `WorkflowExecutionJob` enqueue/perform boundaries to exchanges, retry queues, and DLQs.
