class FlowBridgeJsonFormatter < Logger::Formatter
  include ActiveSupport::TaggedLogging::Formatter

  def call(severity, time, _program_name, message)
    payload = {
      severity: severity,
      timestamp: time.utc.iso8601(3),
      service: "flowbridge",
      tags: current_tags.presence,
      request_id: Current.request_id,
      correlation_id: Current.correlation_id,
      organization_id: Current.organization&.id,
      message: message.is_a?(String) ? message : message.inspect
    }.compact

    "#{payload.to_json}\n"
  end
end

Rails.application.configure do
  config.log_tags = [ :request_id ]
  config.after_initialize do
    Rails.logger.formatter = FlowBridgeJsonFormatter.new if Rails.logger
  end
end
