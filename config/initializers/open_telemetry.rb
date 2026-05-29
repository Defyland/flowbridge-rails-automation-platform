if ENV.fetch("OTEL_ENABLED", "false") == "true"
  require "opentelemetry/sdk"
  require "opentelemetry/exporter/otlp"
  require "opentelemetry/instrumentation/action_pack"
  require "opentelemetry/instrumentation/active_job"
  require "opentelemetry/instrumentation/active_record"
  require "opentelemetry/instrumentation/rack"

  OpenTelemetry::SDK.configure do |config|
    config.service_name = "flowbridge"
    config.use "OpenTelemetry::Instrumentation::Rack"
    config.use "OpenTelemetry::Instrumentation::ActionPack"
    config.use "OpenTelemetry::Instrumentation::ActiveJob"
    config.use "OpenTelemetry::Instrumentation::ActiveRecord"
  end
end
