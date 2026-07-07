module FlowBridge
  class ServerlessWebhookEnvelope
    InvalidEnvelope = Class.new(StandardError)

    SCHEMA_VERSION = 1
    MAX_ENVELOPE_BYTES = 256.kilobytes
    SOURCE_FORMAT = /\A[a-z0-9][a-z0-9_.:-]{0,63}\z/i
    EXTERNAL_EVENT_ID_FORMAT = /\A[a-z0-9][a-z0-9_.:\/-]{0,127}\z/i
    SHA256_FORMAT = /\A\h{64}\z/

    attr_reader :source, :external_event_id, :payload, :headers, :received_at,
      :raw_body_sha256, :correlation_id

    def self.parse_json!(raw_body)
      raise InvalidEnvelope, "envelope must be present" if raw_body.blank?
      raise InvalidEnvelope, "envelope exceeds #{MAX_ENVELOPE_BYTES} bytes" if raw_body.bytesize > MAX_ENVELOPE_BYTES

      new(JSON.parse(raw_body))
    rescue JSON::ParserError
      raise InvalidEnvelope, "envelope body must be valid JSON"
    end

    def initialize(attributes)
      raise InvalidEnvelope, "envelope must be a JSON object" unless attributes.is_a?(Hash)

      assert_schema_version!(attributes.fetch("schema_version", nil))
      @source = normalized_string(attributes, "source", SOURCE_FORMAT)
      @external_event_id = normalized_string(attributes, "external_event_id", EXTERNAL_EVENT_ID_FORMAT)
      @raw_body_sha256 = normalized_string(attributes, "raw_body_sha256", SHA256_FORMAT)
      @correlation_id = optional_string(attributes, "correlation_id")
      @received_at = parse_received_at(attributes.fetch("received_at", nil))
      @payload = normalized_payload(attributes.fetch("payload", nil))
      @headers = normalized_headers(attributes.fetch("headers", {}))
    end

    def idempotency_key
      "serverless/#{source}/#{external_event_id}"
    end

    def source_event_id
      "#{source}:#{external_event_id}"
    end

    def flowbridge_headers
      headers.merge(
        "x-flowbridge-event-id" => source_event_id,
        "x-flowbridge-source" => source,
        "x-flowbridge-ingress" => "serverless",
        "x-flowbridge-raw-body-sha256" => raw_body_sha256,
        "x-flowbridge-received-at" => received_at.iso8601
      )
    end

    private

    def assert_schema_version!(value)
      return if value == SCHEMA_VERSION

      raise InvalidEnvelope, "schema_version must be #{SCHEMA_VERSION}"
    end

    def normalized_string(attributes, key, format)
      value = optional_string(attributes, key)
      raise InvalidEnvelope, "#{key} must be present" if value.blank?
      raise InvalidEnvelope, "#{key} has invalid format" unless value.match?(format)

      value
    end

    def optional_string(attributes, key)
      value = attributes.fetch(key, nil)
      return nil if value.nil?
      raise InvalidEnvelope, "#{key} must be a string" unless value.is_a?(String)

      value.strip.presence
    end

    def parse_received_at(value)
      raise InvalidEnvelope, "received_at must be present" if value.blank?
      raise InvalidEnvelope, "received_at must be a string" unless value.is_a?(String)

      Time.iso8601(value)
    rescue ArgumentError
      raise InvalidEnvelope, "received_at must be ISO 8601"
    end

    def normalized_payload(value)
      raise InvalidEnvelope, "payload must be a JSON object" unless value.is_a?(Hash)

      value
    end

    def normalized_headers(value)
      raise InvalidEnvelope, "headers must be a JSON object" unless value.is_a?(Hash)

      value.each_with_object({}) do |(key, header_value), headers|
        raise InvalidEnvelope, "headers keys must be strings" unless key.is_a?(String)
        next if header_value.nil?
        raise InvalidEnvelope, "headers values must be strings" unless header_value.is_a?(String)

        headers[key.downcase] = header_value
      end
    end
  end
end
