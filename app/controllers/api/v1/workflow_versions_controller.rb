module Api
  module V1
    class WorkflowVersionsController < Api::BaseController
      before_action -> { require_permission!("workflows.read") }, only: %i[index show]
      before_action -> { require_permission!("workflows.write") }, only: %i[create]

      def index
        workflow = Current.organization.workflows.find(params[:workflow_id])
        render json: { workflow_versions: workflow.workflow_versions.order(version_number: :desc).map(&:to_public_hash) }
      end

      def show
        workflow = Current.organization.workflows.find(params[:workflow_id])
        version = workflow.workflow_versions.find(params[:id])
        render json: { workflow_version: version.to_public_hash(include_graph: true) }
      end

      def create
        workflow = Current.organization.workflows.find(params[:workflow_id])
        version_params = params.require(:workflow_version)
        result = FlowBridge::WorkflowPublisher.publish!(
          workflow: workflow,
          graph: version_params.require(:graph).to_unsafe_h,
          retry_policy: version_params[:retry_policy].present? ? version_params.require(:retry_policy).to_unsafe_h : {}
        )

        render status: :created, json: {
          workflow_version: result.workflow_version.to_public_hash(include_graph: true),
          webhook_secret: result.webhook_secret
        }
      end
    end
  end
end
