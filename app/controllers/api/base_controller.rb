module Api
  class BaseController < ActionController::API
    class Unauthorized < StandardError; end
    class Forbidden < StandardError; end
    class TooManyRequests < StandardError; end
    class Conflict < StandardError; end

    before_action :assign_request_context
    before_action :authenticate_api_key!
    before_action :enforce_rate_limit!

    after_action :reset_current

    rescue_from ActionController::ParameterMissing do |error|
      render_error(:unprocessable_entity, "validation_failed", error.message)
    end
    rescue_from ActiveRecord::RecordInvalid do |error|
      render_error(:unprocessable_entity, "validation_failed", error.record.errors.full_messages.join(", "))
    end
    rescue_from ActiveRecord::RecordNotFound do
      render_error(:not_found, "not_found", "resource was not found")
    end
    rescue_from Unauthorized do |error|
      render_error(:unauthorized, "unauthorized", error.message.presence || "authentication is required")
    end
    rescue_from Forbidden do |error|
      render_error(:forbidden, "forbidden", error.message.presence || "permission denied")
    end
    rescue_from TooManyRequests do |error|
      render_error(:too_many_requests, "rate_limited", error.message)
    end
    rescue_from Conflict do |error|
      render_error(:conflict, "conflict", error.message)
    end

    private

    def assign_request_context
      Current.request_id = request.request_id
      Current.correlation_id = request.headers["X-Correlation-Id"].presence || request.request_id
      response.set_header("X-Request-Id", Current.request_id)
      response.set_header("X-Correlation-Id", Current.correlation_id)
    end

    def authenticate_api_key!
      token = request.authorization.to_s[/\ABearer\s+(.+)\z/, 1]
      raise Unauthorized, "missing bearer token" if token.blank?

      api_key = ApiKey.authenticate(token)
      raise Unauthorized, "invalid or revoked API key" unless api_key

      api_key.mark_used!
      Current.api_key = api_key
      Current.organization = api_key.organization
    end

    def enforce_rate_limit!
      return unless Current.api_key

      limit = Current.organization.rate_limit_per_minute
      bucket = "rate-limit:#{Current.api_key.id}:#{Time.current.utc.strftime("%Y%m%d%H%M")}"
      result = FlowBridge::RateLimiter.increment(bucket: bucket, limit: limit, expires_in: 70.seconds)
      raise TooManyRequests, "API key exceeded #{limit} requests per minute" if result.exceeded?
    end

    def require_permission!(permission)
      return if Current.api_key&.allows?(permission)

      raise Forbidden, "API key role cannot #{permission.to_s.tr("_", " ")}"
    end

    def render_error(status, code, message, details = {})
      render status: status, json: {
        error: {
          code: code,
          message: message,
          details: details,
          request_id: Current.request_id,
          correlation_id: Current.correlation_id
        }
      }
    end

    def reset_current
      Current.reset
    end
  end
end
