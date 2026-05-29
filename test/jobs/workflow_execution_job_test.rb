require "test_helper"

class WorkflowExecutionJobTest < ActiveJob::TestCase
  test "performs a queued execution" do
    organization, = create_organization_with_key
    version = publish_workflow_version(organization: organization)
    execution = version.workflow_executions.create!(
      organization: organization,
      workflow: version.workflow,
      idempotency_key: "evt-job",
      correlation_id: "corr-job",
      input_json: { "email" => "job@example.com" }
    )

    WorkflowExecutionJob.perform_now(execution.id)

    assert_equal "succeeded", execution.reload.status
  end
end
