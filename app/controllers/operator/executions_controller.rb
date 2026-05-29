module Operator
  class ExecutionsController < ApplicationController
    before_action -> { require_operator_permission!("executions.retry") }, only: :retry

    def index
      @executions = current_organization.workflow_executions.includes(:workflow, :workflow_version).order(created_at: :desc).limit(100)
    end

    def show
      @execution = current_organization.workflow_executions.includes(:workflow, :workflow_version, :node_executions, :dead_letters).find(params[:id])
    end

    def retry
      execution = current_organization.workflow_executions.find(params[:id])
      unless %w[failed retrying].include?(execution.status)
        redirect_to operator_execution_path(execution), alert: "Only failed or retrying executions can be retried."
        return
      end

      execution.update!(status: "queued", completed_at: nil, error_json: {})
      WorkflowExecutionJob.perform_later(execution.id)
      AuditLog.record!(
        organization: current_organization,
        action: "workflow_execution.operator_retry",
        subject: execution,
        metadata: { user_id: Current.user.id },
        ip_address: request.remote_ip
      )

      redirect_to operator_execution_path(execution), notice: "Execution retry queued."
    end
  end
end
