class WorkflowExecutionJob < ApplicationJob
  queue_as :workflow_execution

  def perform(workflow_execution_id)
    FlowBridge::ExecutionRunner.new(WorkflowExecution.find(workflow_execution_id)).call
  end
end
