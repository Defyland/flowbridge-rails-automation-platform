module Operator
  class WorkflowsController < ApplicationController
    def index
      @workflows = current_organization.workflows.includes(:workflow_versions).order(updated_at: :desc)
    end

    def show
      @workflow = current_organization.workflows.includes(:workflow_versions).find(params[:id])
      @executions = @workflow.workflow_executions.order(created_at: :desc).limit(20)
    end
  end
end
