require "base64"

module FlowBridge
  class NodeExecutor
    class ExecutionError < StandardError
      attr_reader :code, :details, :retriable

      def initialize(code, message, retriable:, details: {})
        super(message)
        @code = code
        @retriable = retriable
        @details = details
      end

      def retriable?
        retriable
      end

      def to_h
        {
          "code" => code,
          "message" => message,
          "retriable" => retriable,
          "details" => SecretMasker.mask_hash(details)
        }
      end
    end

    def initialize(organization:, node:, input:)
      @organization = organization
      @node = node
      @input = input
    end

    def call
      case node.fetch("type")
      when "webhook_trigger"
        { "payload" => input.fetch("event"), "received" => true }
      when "transform"
        transform
      when "filter"
        filter
      when "http_request"
        http_request
      when "emit_event"
        emit_event
      else
        raise ExecutionError.new("unsupported_node_type", "unsupported node type #{node["type"]}", retriable: false)
      end
    end

    private

    attr_reader :organization, :node, :input

    def config
      node.fetch("config", {})
    end

    def transform
      {
        "payload" => input.fetch("event"),
        "mapping" => config.fetch("mapping", {}),
        "previous_outputs" => input.fetch("previous_outputs", {}).deep_dup
      }
    end

    def filter
      field = config.fetch("field")
      expected = config.fetch("equals")
      actual = dig_value(input.fetch("event"), field)

      unless actual == expected
        raise ExecutionError.new(
          "filter_condition_failed",
          "filter #{field} expected #{expected.inspect} and received #{actual.inspect}",
          retriable: false,
          details: { field: field, expected: expected, actual: actual }
        )
      end

      { "matched" => true, "field" => field, "value" => actual }
    end

    def http_request
      url = config.fetch("url")
      method = config.fetch("method", "POST").to_s.upcase
      timeout_seconds = config.fetch("timeout_seconds", 5)
      credential = find_credential

      headers = credential_headers(config.fetch("headers", {}).dup, credential)
      response = FlowBridge::HttpClient.request(
        url: url,
        method: method,
        headers: headers,
        body: config.fetch("body", input),
        timeout_seconds: timeout_seconds
      )

      raise_http_error(url, response) unless response.success?

      {
        "request" => {
          "method" => method,
          "url" => url,
          "headers" => SecretMasker.mask_hash(headers),
          "credential" => credential&.then { |item| { "id" => item.id, "name" => item.name, "secret" => item.masked_secret } }
        }.compact,
        "response" => {
          "status" => response.status,
          "headers" => SecretMasker.mask_hash(response.headers),
          "body" => SecretMasker.mask_hash(response.body),
          "duration_ms" => response.duration_ms
        }
      }
    rescue FlowBridge::HttpClient::TimeoutError, FlowBridge::HttpClient::ConnectionError => error
      raise ExecutionError.new(
        "http_transient_failure",
        error.message,
        retriable: true,
        details: error.details
      )
    rescue FlowBridge::HttpClient::InvalidRequestError => error
      raise ExecutionError.new(
        "http_invalid_request",
        error.message,
        retriable: false,
        details: error.details
      )
    end

    def emit_event
      {
        "topic" => config.fetch("topic", "workflow.completed"),
        "event" => input.fetch("event"),
        "previous_outputs" => input.fetch("previous_outputs", {}).deep_dup
      }
    end

    def find_credential
      credential_id = config["credential_id"]
      return if credential_id.blank?

      organization.credentials.find(credential_id)
    rescue ActiveRecord::RecordNotFound
      raise ExecutionError.new(
        "credential_not_found",
        "credential #{credential_id} is not available for this organization",
        retriable: false
      )
    end

    def credential_headers(headers, credential = nil)
      return headers unless credential

      case credential.kind
      when "bearer_token"
        headers["Authorization"] ||= "Bearer #{credential.secret}"
      when "api_key"
        header_name = credential.metadata_json["header_name"].presence || "X-API-Key"
        headers[header_name] ||= credential.secret
      when "basic_auth"
        headers["Authorization"] ||= "Basic #{Base64.strict_encode64(credential.secret)}"
      when "webhook_secret"
        headers["X-Webhook-Secret"] ||= credential.secret
      end

      headers
    end

    def raise_http_error(url, response)
      retriable = FlowBridge::HttpClient.retriable_status?(response.status)
      raise ExecutionError.new(
        retriable ? "http_transient_failure" : "http_permanent_failure",
        "HTTP request to #{url} failed with status #{response.status}",
        retriable: retriable,
        details: { url: url, status: response.status, response: response.body }
      )
    end

    def dig_value(payload, path)
      path.to_s.split(".").reduce(payload) do |value, key|
        value.respond_to?(:[]) ? value[key] : nil
      end
    end
  end
end
