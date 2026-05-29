class DashboardController < ApplicationController
  def index
    @workflow_count = current_organization.workflows.count
    @open_dead_letter_count = current_organization.dead_letters.where(status: "open").count
    @recent_executions = current_organization.workflow_executions.includes(:workflow, :workflow_version).order(created_at: :desc).limit(8)
    @execution_counts = current_organization.workflow_executions.group(:status).count
    @recent_dead_letters = current_organization.dead_letters.includes(workflow_execution: :workflow).order(created_at: :desc).limit(6)
  end
end
