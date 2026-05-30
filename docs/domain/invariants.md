# Domain Invariants

## Tenant isolation

Every tenant-owned record is scoped to one `Organization`. API controllers query through `Current.organization`; operator controllers derive organization access through membership.

Evidence:

- `test/integration/authorization_and_isolation_test.rb`
- `app/controllers/api/base_controller.rb`
- `app/controllers/application_controller.rb`

## API key storage

Raw API keys are returned once. Persistent storage uses token digests and token hints.

Evidence:

- `app/models/api_key.rb`
- `app/services/flow_bridge/api_key_issuer.rb`
- `test/models/organization_test.rb`

## Workflow version immutability

An executable graph is a `WorkflowVersion`. Publishing a new graph creates a new version. Existing versions cannot be updated as execution artifacts.

Evidence:

- `app/models/workflow_version.rb`
- `docs/adr/002-immutable-workflow-versions.md`
- `test/models/workflow_version_test.rb`

## Webhook idempotency

Webhook delivery is idempotent per workflow version and source event ID/idempotency key.

Evidence:

- `db/schema.rb`
- `app/services/flow_bridge/webhook_ingestor.rb`
- `test/integration/webhook_failure_scenarios_test.rb`

## Node evidence

Each node attempt records attempt number, status, timing, input, output, and error information.

Evidence:

- `app/models/node_execution.rb`
- `app/services/flow_bridge/execution_runner.rb`
- `test/services/execution_runner_test.rb`

## Dead-letter visibility

Terminal failures create dead-letter records that operators can retry or resolve.

Evidence:

- `app/models/dead_letter.rb`
- `app/controllers/operator/dead_letters_controller.rb`
- `test/system/operator_console_test.rb`

## Secret masking

Secret-bearing values must not appear in public responses, node evidence, audit metadata, event payloads, or dead letters without masking.

Evidence:

- `app/services/flow_bridge/secret_masker.rb`
- `app/models/credential.rb`
- `test/models/credential_test.rb`
