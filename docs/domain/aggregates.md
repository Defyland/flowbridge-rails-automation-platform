# Aggregates

## Organization aggregate

Root: `Organization`

Owns:

- API keys
- workflows
- workflow versions through workflows
- credentials
- webhook events
- workflow executions
- dead letters
- audit logs
- operator memberships

Invariant:

- tenant-owned data must be queried through the organization boundary.

## Workflow aggregate

Root: `Workflow`

Owns:

- published workflow versions

Invariant:

- workflow slug is unique per organization.
- workflow version numbers are unique per workflow.
- published workflow versions are immutable execution artifacts.

## Execution aggregate

Root: `WorkflowExecution`

Owns:

- node executions
- dead-letter link when terminal failure occurs

Invariant:

- execution references exactly one organization, workflow, and workflow version.
- duplicate webhook delivery must not create a duplicate execution.
- terminal failure must leave inspectable node evidence.

## Credential aggregate

Root: `Credential`

Invariant:

- raw secret material is encrypted at rest and masked before rendering, event publication, audit metadata, or dead-letter evidence.

## Dead-letter aggregate

Root: `DeadLetter`

Invariant:

- dead letters are operator-visible failure evidence.
- retry and resolve are explicit status transitions.
- dead letters must not be silently deleted as part of normal operation.
