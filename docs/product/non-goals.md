# Non-goals

FlowBridge intentionally keeps the MVP focused on the backend reliability slice.

## Out of scope for the MVP

- Visual drag-and-drop workflow editor.
- Arbitrary custom code execution inside workflow nodes.
- OAuth connector marketplace.
- Real external provider adapters beyond deterministic mock nodes.
- Multi-region deployment.
- Kubernetes or service mesh.
- RabbitMQ or Kafka as mandatory infrastructure.
- Full Event Sourcing as the initial execution history store.
- Billing, subscription management, and customer-facing account portal.

## Rationale

These features are valuable later, but adding them before the workflow execution boundary is reliable would increase surface area without improving the central senior-level evidence: idempotency, immutable execution, retry semantics, dead-letter handling, tenant isolation, and observability.
