class RecoverQueuedWorkflowExecutionsJob < ApplicationJob
  queue_as :background

  STALE_AFTER = 2.minutes

  def perform(stale_before: STALE_AFTER.ago)
    WorkflowExecution
      .where(status: "queued")
      .where("updated_at < ?", stale_before)
      .find_each do |execution|
        WorkflowExecutionJob.perform_later(execution.id)
      end
  end
end
