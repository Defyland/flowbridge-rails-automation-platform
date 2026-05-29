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
      method = config.fetch("method", "POST").upcase
      headers = config.fetch("headers", {})
      credential = find_credential

      raise_http_error(url) if url.start_with?("mock://fail")

      {
        "request" => {
          "method" => method,
          "url" => url,
          "headers" => SecretMasker.mask_hash(headers),
          "credential" => credential&.then { |item| { "id" => item.id, "name" => item.name, "secret" => item.masked_secret } }
        }.compact,
        "response" => {
          "status" => url.start_with?("mock://") ? 202 : 200,
          "body" => { "accepted" => true, "id" => SecureRandom.uuid }
        }
      }
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

    def raise_http_error(url)
      retriable = url.include?("transient") || url.include?("timeout")
      raise ExecutionError.new(
        retriable ? "http_transient_failure" : "http_permanent_failure",
        "simulated HTTP failure for #{url}",
        retriable: retriable,
        details: { url: url }
      )
    end

    def dig_value(payload, path)
      path.to_s.split(".").reduce(payload) do |value, key|
        value.respond_to?(:[]) ? value[key] : nil
      end
    end
  end
end
