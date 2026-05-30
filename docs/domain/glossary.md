# Domain Glossary

| Term | Meaning |
| --- | --- |
| Organization | Tenant boundary for API keys, workflows, credentials, executions, and dead letters. |
| API key | Machine credential scoped to one organization and role. The raw token is returned once and stored as a digest. |
| Operator | Human user with an organization membership and browser session. |
| Workflow | Mutable product container for workflow metadata. |
| Workflow version | Immutable executable workflow graph with trigger key, webhook secret, retry policy, and graph checksum. |
| Graph checksum | Stable digest of the canonical workflow graph. Used for review and execution evidence. |
| Webhook event | Signed inbound event from a source system. |
| Source event ID | External event identifier supplied by the webhook source. |
| Idempotency key | Key used to prevent duplicate webhook and execution creation. |
| Workflow execution | State machine instance for one workflow version and payload. |
| Node execution | Evidence for one node attempt, including input, output, duration, error, and attempt number. |
| Credential | Encrypted third-party secret material scoped to an organization. |
| Dead letter | Terminal failure record requiring operator retry or resolution. |
| Audit log | Tenant-scoped record of sensitive operational actions. |
| Correlation ID | Cross-cutting identifier propagated through request, webhook, execution, logs, and responses. |
