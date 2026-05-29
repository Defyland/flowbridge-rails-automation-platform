class ApplicationController < ActionController::Base
  include Authentication

  before_action :assign_request_context
  before_action :assign_current_organization
  after_action :reset_current

  private

  def assign_request_context
    Current.request_id = request.request_id
    Current.correlation_id = request.headers["X-Correlation-Id"].presence || request.request_id
    response.set_header("X-Request-Id", Current.request_id)
    response.set_header("X-Correlation-Id", Current.correlation_id)
  end

  def assign_current_organization
    return unless Current.user

    Current.organization = Current.user.organizations.order(:name).first
  end

  def current_organization
    Current.organization
  end
  helper_method :current_organization

  def require_operator_permission!(permission)
    membership = Current.user&.membership_for(Current.organization)
    return if membership&.allows?(permission)

    redirect_to root_path, alert: "Your operator role cannot perform that action."
  end

  def reset_current
    Current.reset
  end
end
