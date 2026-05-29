module Operator
  class DeadLettersController < ApplicationController
    before_action -> { require_operator_permission!("dead_letters.manage") }, only: %i[retry resolve]

    def index
      @dead_letters = current_organization.dead_letters.includes(workflow_execution: :workflow).order(created_at: :desc).limit(100)
    end

    def show
      @dead_letter = current_organization.dead_letters.includes(workflow_execution: [ :workflow, :node_executions ]).find(params[:id])
    end

    def retry
      dead_letter = current_organization.dead_letters.find(params[:id])
      execution = dead_letter.workflow_execution
      execution.update!(status: "queued", completed_at: nil, error_json: {})
      dead_letter.mark_retried!
      WorkflowExecutionJob.perform_later(execution.id)
      AuditLog.record!(
        organization: current_organization,
        action: "dead_letter.operator_retry",
        subject: dead_letter,
        metadata: { user_id: Current.user.id, workflow_execution_id: execution.id },
        ip_address: request.remote_ip
      )

      redirect_to operator_dead_letter_path(dead_letter), notice: "Dead-letter retry queued."
    end

    def resolve
      dead_letter = current_organization.dead_letters.find(params[:id])
      dead_letter.resolve!
      AuditLog.record!(
        organization: current_organization,
        action: "dead_letter.operator_resolved",
        subject: dead_letter,
        metadata: { user_id: Current.user.id },
        ip_address: request.remote_ip
      )

      redirect_to operator_dead_letter_path(dead_letter), notice: "Dead letter resolved."
    end
  end
end
