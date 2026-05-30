# Bounded Contexts

FlowBridge is a modular Rails monolith. Boundaries are enforced by naming, controllers, services, models, tests, and documentation rather than separate services.

## Tenant and identity

Models:

- `Organization`
- `ApiKey`
- `User`
- `Session`
- `OperatorMembership`

Responsibilities:

- tenant boundary
- API role permissions
- operator session authentication
- current request organization

## Workflow authoring

Models and services:

- `Workflow`
- `WorkflowVersion`
- `FlowBridge::WorkflowPublisher`
- `FlowBridge::GraphChecksum`

Responsibilities:

- mutable workflow metadata
- immutable executable graph publication
- retry policy and webhook secret ownership

## Ingress

Models and services:

- `WebhookEvent`
- `FlowBridge::SignatureVerifier`
- `FlowBridge::WebhookIngestor`

Responsibilities:

- signature verification
- idempotency
- event persistence
- execution creation

## Execution engine

Models and services:

- `WorkflowExecution`
- `NodeExecution`
- `WorkflowExecutionJob`
- `FlowBridge::ExecutionRunner`
- `FlowBridge::NodeExecutor`
- `FlowBridge::RetryPolicy`

Responsibilities:

- durable async execution
- node-level evidence
- retry state
- terminal failure classification

## Operations

Models and controllers:

- `DeadLetter`
- `AuditLog`
- `Operator::*Controller`
- `PlatformController`

Responsibilities:

- operator review
- retry and resolve actions
- health, readiness, metrics
- audit trail
