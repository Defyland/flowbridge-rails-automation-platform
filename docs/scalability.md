# Scalability

## Hot path

The hottest write path is signed webhook ingress:

```text
POST /api/v1/webhooks/:trigger_key
verify signature
check idempotency
persist WebhookEvent
persist WorkflowExecution
enqueue WorkflowExecutionJob
return 202
```

The design keeps this path short and moves workflow node work to Solid Queue.

For provider traffic that benefits from edge isolation, the serverless path moves normalization and throttling in front of Rails:

```text
POST /webhooks/{trigger_key} on API Gateway
Lambda normalizes provider payload
Lambda signs a serverless envelope
POST /api/v1/serverless/webhooks/:trigger_key
Rails applies the same idempotency and execution transaction
```

This reduces provider-specific branching in Rails and gives API Gateway a first throttle point. It does not remove Rails from the acknowledgement path yet; moving the edge to SQS is the next step if measured traffic proves synchronous relay too fragile.

## Read-heavy paths

- `GET /api/v1/executions`
- `GET /api/v1/dead_letters`
- operator execution list
- operator dead-letter list
- metrics endpoint

Indexes on organization, workflow, status, and timestamps become important as execution history grows.

## Write-heavy paths

- webhook events
- workflow executions
- node executions
- dead letters
- audit logs
- Solid Queue job tables

`node_executions` can grow fastest because each workflow execution can create multiple node attempts.

## First bottlenecks

| Bottleneck | Why it appears | Strategy |
| --- | --- | --- |
| Webhook idempotency index | every webhook checks uniqueness | keep key narrow, monitor conflicts, partition later by organization/time |
| Solid Queue tables | job throughput shares PostgreSQL | tune worker concurrency, separate queue database, consider broker adapter |
| Node execution writes | each node records evidence | batch read paths, retention, partition by created_at |
| Dead-letter growth | poison events accumulate | alert thresholds, retention policy, source-specific suppression |
| Rate-limit cache | cache backed by database in MVP | move to Redis only when latency/volume requires it |
| Serverless relay | Rails availability still controls provider acknowledgement | API Gateway throttling now; SQS relay later if benchmarked volume requires it |

## Hot partitions

- one organization receiving most webhook traffic
- one workflow version with high source retry volume
- one source system retrying poison events
- one dead-letter queue repeatedly retried by operators

## Horizontal scaling

Safe to scale horizontally:

- Rails web processes
- worker processes
- read-only operator/API requests
- Docker hosts behind a proxy

Needs care:

- queue concurrency against the same PostgreSQL queue tables
- duplicate webhook races
- rate limiting if cache backend changes
- dead-letter retry storms

## What must not become eventual

- API key authentication and revocation.
- Tenant boundary checks.
- Webhook signature validation.
- Idempotency before execution creation.
- Workflow version immutability.
- Credential masking before operator-visible evidence.

## Future scale path

1. Tune PostgreSQL indexes and connection pool.
2. Split web and worker process counts.
3. Separate primary, queue, cache, and cable databases operationally.
4. Add retention and partitioning for execution-history tables.
5. Introduce a broker adapter if Solid Queue becomes the limiting factor.
6. Add source-specific ingestion throttles for high-volume tenants.
7. Switch the serverless edge from synchronous Rails relay to SQS when provider retry volume or Rails deploy windows justify the extra queue contract.
