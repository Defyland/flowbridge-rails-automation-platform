# State Machines

## Workflow

```mermaid
stateDiagram-v2
  [*] --> draft
  draft --> active: publish version
  active --> archived: future archival
```

Implemented states:

- `draft`
- `active`

## Workflow execution

```mermaid
stateDiagram-v2
  [*] --> queued
  queued --> running
  running --> succeeded
  running --> retrying
  retrying --> queued
  retrying --> failed
  running --> failed
```

Failure behavior:

- retryable node failures move execution to `retrying` until retry policy is exhausted.
- exhausted or non-retryable failures move execution to `failed` and create a dead letter.

## Node execution

```mermaid
stateDiagram-v2
  [*] --> running
  running --> succeeded
  running --> failed
  running --> skipped
```

Node evidence records attempt number, timing, input, output, and error details.

## Dead letter

```mermaid
stateDiagram-v2
  [*] --> open
  open --> retrying: operator retry
  retrying --> resolved: retry succeeds
  retrying --> open: retry fails
  open --> resolved: operator resolve
```

Dead letters remain operational evidence after resolution.
