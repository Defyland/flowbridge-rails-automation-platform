# Abuse Cases

## Cross-tenant object access

Attempt: API key from one organization requests another organization's workflow, execution, credential, or dead letter.

Controls:

- tenant-scoped queries through `Current.organization`
- request tests for tenant isolation
- generic not-found behavior for out-of-scope resources

## Webhook spoofing

Attempt: attacker posts fake payloads to a known trigger key.

Controls:

- per-version HMAC signature validation
- trigger key lookup before execution
- no execution creation before signature acceptance

## Webhook replay

Attempt: attacker or source retries the same event to duplicate downstream actions.

Controls:

- idempotency by source event ID and workflow version
- unique database constraints
- duplicate response path without new execution

## Token leakage

Attempt: raw API key or reset token leaks through logs, browser UI, CI, or audit metadata.

Controls:

- API key digest storage
- secret filtering
- one-time raw token return
- secrets kept in env/GitHub secrets

## Credential exfiltration through node evidence

Attempt: credential value appears in node input, output, error, dead-letter payload, or event payload.

Controls:

- encrypted credential storage
- recursive masking
- operator-facing records treated as masked evidence

## Dead-letter replay abuse

Attempt: operator repeatedly retries a non-idempotent failure and duplicates downstream writes.

Controls:

- retry permission gate
- audit log action
- append-only attempt evidence
- future connector-level outbound idempotency keys

## Queue exhaustion

Attempt: high-volume poison webhook traffic fills queue and dead-letter tables.

Controls:

- rate limiting
- retry caps
- dead-letter visibility
- planned retention and alert thresholds
