require "base64"
require "cgi"
require "json"
require "net/http"
require "openssl"
require "securerandom"
require "time"
require "uri"

module FlowBridgeServerlessIngress
  ConfigurationError = Class.new(StandardError)
  ValidationError = Class.new(StandardError)
  RelayError = Class.new(StandardError)

  MAX_BODY_BYTES = 256 * 1024
  DEFAULT_EVENT_ID_HEADER = "x-flowbridge-event-id"
  DEFAULT_OPEN_TIMEOUT_SECONDS = 2.0
  DEFAULT_READ_TIMEOUT_SECONDS = 5.0
  FORWARDED_HEADER = /\A(content-type|user-agent|stripe-signature|x-github-delivery|x-hub-signature-256|x-request-id|x-correlation-id|x-flowbridge-event-id)\z/i

  class << self
    def handle(event:, context: nil, env: ENV, http_client: HttpClient.new, clock: Time, secret_provider: SecretsManagerSecretProvider.new)
      Handler.new(env: env, http_client: http_client, clock: clock, secret_provider: secret_provider).call(event: event, context: context)
    end

    def signature(secret:, payload:)
      "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, payload)}"
    end
  end

  class Handler
    def initialize(env:, http_client:, clock:, secret_provider:)
      @env = env
      @http_client = http_client
      @clock = clock
      @secret_provider = secret_provider
    end

    def call(event:, context: nil)
      raw_body = decoded_body(event)
      payload = parsed_payload(raw_body)
      envelope = envelope_for(event: event, payload: payload, raw_body: raw_body, context: context)
      relay_envelope(event: event, envelope: envelope)
    rescue ValidationError => error
      response(400, accepted: false, error: { code: "invalid_webhook", message: error.message })
    rescue ConfigurationError => error
      response(500, accepted: false, error: { code: "misconfigured_ingress", message: error.message })
    rescue RelayError => error
      response(502, accepted: false, error: { code: "rails_ingress_unavailable", message: error.message })
    end

    private

    attr_reader :env, :http_client, :clock, :secret_provider

    def decoded_body(event)
      raise ValidationError, "event body must be present" unless event.is_a?(Hash) && event.key?("body")

      body = event.fetch("body").to_s
      body = Base64.decode64(body) if event.fetch("isBase64Encoded", false)
      raise ValidationError, "event body exceeds #{MAX_BODY_BYTES} bytes" if body.bytesize > MAX_BODY_BYTES

      body
    end

    def parsed_payload(raw_body)
      payload = JSON.parse(raw_body)
      raise ValidationError, "event body must be a JSON object" unless payload.is_a?(Hash)

      payload
    rescue JSON::ParserError
      raise ValidationError, "event body must be valid JSON"
    end

    def envelope_for(event:, payload:, raw_body:, context:)
      headers = normalized_headers(event.fetch("headers", {}))

      {
        schema_version: 1,
        source: required_env("FLOWBRIDGE_SOURCE"),
        external_event_id: external_event_id(headers: headers, payload: payload),
        received_at: clock.now.utc.iso8601,
        raw_body_sha256: OpenSSL::Digest::SHA256.hexdigest(raw_body),
        correlation_id: correlation_id(event: event, headers: headers, context: context),
        headers: forwarded_headers(headers),
        payload: payload
      }
    end

    def normalized_headers(headers)
      raise ValidationError, "event headers must be an object" unless headers.is_a?(Hash)

      headers.each_with_object({}) do |(key, value), normalized|
        normalized[key.to_s.downcase] = value.to_s
      end
    end

    def external_event_id(headers:, payload:)
      header_name = env.fetch("FLOWBRIDGE_EVENT_ID_HEADER", DEFAULT_EVENT_ID_HEADER).downcase
      event_id = headers[header_name] || payload["id"] || payload.dig("event", "id")
      raise ValidationError, "external event id is required" if event_id.to_s.strip.empty?

      event_id.to_s.strip
    end

    def correlation_id(event:, headers:, context:)
      headers["x-correlation-id"] ||
        event.dig("requestContext", "requestId") ||
        context_request_id(context) ||
        SecureRandom.uuid
    end

    def context_request_id(context)
      return unless context.respond_to?(:aws_request_id)

      context.aws_request_id
    end

    def forwarded_headers(headers)
      headers.each_with_object({}) do |(key, value), forwarded|
        forwarded[key] = value if key.match?(FORWARDED_HEADER)
      end
    end

    def relay_envelope(event:, envelope:)
      raw_envelope = JSON.generate(envelope)
      uri = rails_ingress_uri(trigger_key_for(event))
      relay_response = http_client.post(
        uri: uri,
        body: raw_envelope,
        headers: relay_headers(raw_envelope, envelope.fetch(:correlation_id)),
        open_timeout: timeout_env("FLOWBRIDGE_RELAY_OPEN_TIMEOUT_SECONDS", DEFAULT_OPEN_TIMEOUT_SECONDS),
        read_timeout: timeout_env("FLOWBRIDGE_RELAY_READ_TIMEOUT_SECONDS", DEFAULT_READ_TIMEOUT_SECONDS)
      )

      status = relay_response.code.to_i
      raise RelayError, "Rails returned #{status}" unless status.between?(200, 299)

      response(202, accepted: true, correlation_id: envelope.fetch(:correlation_id))
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => error
      raise RelayError, error.message
    end

    def relay_headers(raw_envelope, correlation_id)
      {
        "Content-Type" => "application/json",
        "X-Correlation-Id" => correlation_id,
        "X-FlowBridge-Serverless-Signature" => FlowBridgeServerlessIngress.signature(
          secret: serverless_ingress_secret,
          payload: raw_envelope
        )
      }
    end

    def serverless_ingress_secret
      direct_secret = env["FLOWBRIDGE_SERVERLESS_INGRESS_SECRET"].to_s.strip
      return direct_secret unless direct_secret.empty?

      secret_arn = env["FLOWBRIDGE_SERVERLESS_INGRESS_SECRET_ARN"].to_s.strip
      raise ConfigurationError, "FLOWBRIDGE_SERVERLESS_INGRESS_SECRET or FLOWBRIDGE_SERVERLESS_INGRESS_SECRET_ARN must be configured" if secret_arn.empty?

      secret_provider.fetch(secret_arn).to_s
    end

    def rails_ingress_uri(trigger_key)
      base_uri = URI.parse(required_env("FLOWBRIDGE_RAILS_INGRESS_URL"))
      base_path = base_uri.path.to_s.sub(%r{/\z}, "")
      base_uri.path = "#{base_path}/api/v1/serverless/webhooks/#{CGI.escape(trigger_key)}"
      base_uri.query = nil
      base_uri
    rescue URI::InvalidURIError
      raise ConfigurationError, "FLOWBRIDGE_RAILS_INGRESS_URL must be a valid URI"
    end

    def trigger_key_for(event)
      trigger_key = event.dig("pathParameters", "trigger_key") ||
        env["FLOWBRIDGE_TRIGGER_KEY"] ||
        event.fetch("rawPath", "").split("/").last
      raise ValidationError, "trigger key is required" if trigger_key.to_s.strip.empty?

      trigger_key.to_s
    end

    def timeout_env(key, default)
      value = env.fetch(key, default).to_f
      return default unless value.positive?

      value
    end

    def required_env(key)
      value = env[key].to_s.strip
      raise ConfigurationError, "#{key} must be configured" if value.empty?

      value
    end

    def response(status, body)
      {
        "statusCode" => status,
        "headers" => { "Content-Type" => "application/json" },
        "body" => JSON.generate(body)
      }
    end
  end

  class HttpClient
    def post(uri:, body:, headers:, open_timeout:, read_timeout:)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = open_timeout
      http.read_timeout = read_timeout

      request = Net::HTTP::Post.new(uri)
      headers.each { |key, value| request[key] = value }
      request.body = body

      http.request(request)
    end
  end

  class SecretsManagerSecretProvider
    def fetch(secret_arn)
      require "aws-sdk-secretsmanager"

      Aws::SecretsManager::Client.new.get_secret_value(secret_id: secret_arn).secret_string
    rescue LoadError
      raise ConfigurationError, "aws-sdk-secretsmanager must be available when FLOWBRIDGE_SERVERLESS_INGRESS_SECRET_ARN is used"
    end
  end
end
