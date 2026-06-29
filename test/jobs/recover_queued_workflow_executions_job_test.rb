require "test_helper"

class RecoverQueuedWorkflowExecutionsJobTest < ActiveJob::TestCase
  test "re-enqueues only stale queued executions" do
    organization, = create_organization_with_key
    version = publish_workflow_version(organization: organization)

    stale_execution = create_execution(version:, idempotency_key: "evt-stale")
    recent_execution = create_execution(version:, idempotency_key: "evt-recent")
    running_execution = create_execution(version:, idempotency_key: "evt-running", status: "running")
    succeeded_execution = create_execution(version:, idempotency_key: "evt-succeeded", status: "succeeded")

    stale_execution.update_columns(updated_at: 5.minutes.ago)
    recent_execution.update_columns(updated_at: 30.seconds.ago)
    running_execution.update_columns(updated_at: 5.minutes.ago)
    succeeded_execution.update_columns(updated_at: 5.minutes.ago, completed_at: 1.minute.ago)

    assert_enqueued_jobs 1, only: WorkflowExecutionJob do
      RecoverQueuedWorkflowExecutionsJob.perform_now
    end

    assert_enqueued_with(job: WorkflowExecutionJob, args: [ stale_execution.id ])
  end

  private

  def create_execution(version:, idempotency_key:, status: "queued")
    version.workflow_executions.create!(
      organization: version.organization,
      workflow: version.workflow,
      idempotency_key: idempotency_key,
      correlation_id: "corr-#{idempotency_key}",
      input_json: { "email" => "#{idempotency_key}@example.com" },
      status: status,
      completed_at: status == "succeeded" ? Time.current : nil
    )
  end
end
