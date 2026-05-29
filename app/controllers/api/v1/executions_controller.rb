module Api
  module V1
    class ExecutionsController < Api::BaseController
      before_action -> { require_permission!("executions.read") }, only: %i[index show]
      before_action -> { require_permission!("executions.retry") }, only: :retry

      def index
        executions = Current.organization.workflow_executions.order(created_at: :desc).limit(100)
        render json: { workflow_executions: executions.map(&:to_public_hash) }
      end

      def show
        execution = Current.organization.workflow_executions.find(params[:id])
        render json: { workflow_execution: execution.to_public_hash(include_nodes: true) }
      end

      def retry
        execution = Current.organization.workflow_executions.find(params[:id])
        unless %w[failed retrying].include?(execution.status)
          raise Conflict, "only failed or retrying executions can be manually retried"
        end

        execution.update!(status: "queued", completed_at: nil, error_json: {})
        WorkflowExecutionJob.perform_later(execution.id)
        AuditLog.record!(
          organization: Current.organization,
          action: "workflow_execution.manual_retry",
          subject: execution,
          ip_address: request.remote_ip
        )

        render status: :accepted, json: { workflow_execution: execution.to_public_hash }
      end
    end
  end
end
