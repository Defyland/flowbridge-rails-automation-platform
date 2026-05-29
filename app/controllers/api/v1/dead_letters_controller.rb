module Api
  module V1
    class DeadLettersController < Api::BaseController
      before_action -> { require_permission!("dead_letters.read") }, only: %i[index show]
      before_action -> { require_permission!("dead_letters.manage") }, only: %i[retry resolve]

      def index
        dead_letters = Current.organization.dead_letters.order(created_at: :desc).limit(100)
        render json: { dead_letters: dead_letters.map(&:to_public_hash) }
      end

      def show
        dead_letter = Current.organization.dead_letters.find(params[:id])
        render json: { dead_letter: dead_letter.to_public_hash }
      end

      def retry
        dead_letter = Current.organization.dead_letters.find(params[:id])
        execution = dead_letter.workflow_execution
        execution.update!(status: "queued", completed_at: nil, error_json: {})
        dead_letter.mark_retried!
        WorkflowExecutionJob.perform_later(execution.id)
        AuditLog.record!(
          organization: Current.organization,
          action: "dead_letter.retry",
          subject: dead_letter,
          metadata: { workflow_execution_id: execution.id },
          ip_address: request.remote_ip
        )

        render status: :accepted, json: {
          dead_letter: dead_letter.to_public_hash,
          workflow_execution: execution.to_public_hash
        }
      end

      def resolve
        dead_letter = Current.organization.dead_letters.find(params[:id])
        dead_letter.resolve!
        AuditLog.record!(
          organization: Current.organization,
          action: "dead_letter.resolved",
          subject: dead_letter,
          ip_address: request.remote_ip
        )

        render json: { dead_letter: dead_letter.to_public_hash }
      end
    end
  end
end
