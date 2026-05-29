# Workflow Event Contract Drift

Use this runbook when execution timelines, dead letters, or downstream consumers fail after an event shape change.

## Triage

- Confirm the event references the immutable `workflow_version_id`.
- Verify secret values are masked before entering payloads or dead-letter records.
- Check webhook source, external event ID, execution ID, and correlation ID.
- Determine whether failures are retryable or should remain dead-lettered.

## Recovery

- Restore the previous payload shape or create a new schema version.
- Replay one dead letter first and inspect node outputs.
- Resume batch replay only when duplicate execution is prevented by idempotency keys.
- Update the workflow versioning ADR if semantics changed.
