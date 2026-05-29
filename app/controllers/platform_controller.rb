class PlatformController < ActionController::API
  def health
    render json: { status: "ok", service: "flowbridge", time: Time.current.iso8601 }
  end

  def readiness
    ActiveRecord::Base.connection.select_value("SELECT 1")
    render json: {
      status: "ready",
      checks: {
        database: "ok",
        queue_adapter: Rails.application.config.active_job.queue_adapter.to_s
      }
    }
  rescue StandardError => error
    render status: :service_unavailable, json: {
      status: "not_ready",
      error: error.message
    }
  end

  def metrics
    render plain: FlowBridge::Metrics.prometheus, content_type: "text/plain; version=0.0.4"
  end
end
