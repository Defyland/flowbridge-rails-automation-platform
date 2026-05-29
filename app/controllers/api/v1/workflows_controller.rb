module Api
  module V1
    class WorkflowsController < Api::BaseController
      before_action -> { require_permission!("workflows.read") }, only: %i[index show]
      before_action -> { require_permission!("workflows.write") }, only: %i[create]

      def index
        workflows = Current.organization.workflows.order(created_at: :desc)
        render json: { workflows: workflows.map(&:to_public_hash) }
      end

      def show
        workflow = Current.organization.workflows.find(params[:id])
        render json: { workflow: workflow.to_public_hash(include_versions: true) }
      end

      def create
        workflow = Current.organization.workflows.create!(workflow_params)
        AuditLog.record!(
          organization: Current.organization,
          action: "workflow.created",
          subject: workflow,
          ip_address: request.remote_ip
        )
        render status: :created, json: { workflow: workflow.to_public_hash }
      end

      private

      def workflow_params
        params.require(:workflow).permit(:name, :slug, :description)
      end
    end
  end
end
