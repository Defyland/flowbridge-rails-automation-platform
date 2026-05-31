require "uri"

module FlowBridge
  class WorkflowGraphValidator
    Issue = Data.define(:attribute, :message)
    Result = Data.define(:issues) do
      def valid?
        issues.empty?
      end
    end

    SUPPORTED_NODE_TYPES = %w[webhook_trigger transform filter http_request emit_event].freeze
    HTTP_METHODS = %w[GET POST PUT PATCH DELETE].freeze
    NODE_KEY_FORMAT = /\A[a-z][a-z0-9_:-]*\z/

    def self.call(graph:, retry_policy: {})
      new(graph: graph, retry_policy: retry_policy).call
    end

    def initialize(graph:, retry_policy: {})
      @graph = stringify(graph)
      @retry_policy = stringify(retry_policy || {})
      @issues = []
    end

    def call
      validate_graph
      validate_retry_policy
      Result.new(issues: issues)
    end

    private

    attr_reader :graph, :retry_policy, :issues

    def stringify(value)
      value.respond_to?(:deep_stringify_keys) ? value.deep_stringify_keys : value
    end

    def validate_graph
      unless graph.is_a?(Hash) && graph["nodes"].is_a?(Array)
        add(:graph_json, "must contain a nodes array")
        return
      end

      nodes = graph.fetch("nodes")
      add(:graph_json, "must include at least one node") if nodes.empty?
      validate_node_keys(nodes)
      validate_trigger(nodes)
      nodes.each_with_index { |node, index| validate_node(node, index) }
    end

    def validate_node_keys(nodes)
      keys = nodes.filter_map { |node| node["key"] if node.is_a?(Hash) }
      add(:graph_json, "nodes must have unique keys") if keys.uniq.size != keys.size
    end

    def validate_trigger(nodes)
      trigger_indexes = nodes.each_index.select { |index| nodes[index].is_a?(Hash) && nodes[index]["type"] == "webhook_trigger" }

      add(:graph_json, "must include exactly one webhook_trigger node") unless trigger_indexes.one?
      add(:graph_json, "webhook_trigger must be the first node") if trigger_indexes.any? && trigger_indexes.first != 0
    end

    def validate_node(node, index)
      unless node.is_a?(Hash)
        add(:graph_json, "node #{index} must be an object")
        return
      end

      validate_node_identity(node, index)
      validate_node_config(node, index)
    end

    def validate_node_identity(node, index)
      key = node["key"]
      type = node["type"]

      add(:graph_json, "node #{index} key is required") if key.blank?
      add(:graph_json, "node #{index} key has invalid format") if key.present? && !key.to_s.match?(NODE_KEY_FORMAT)
      add(:graph_json, "node #{index} type is required") if type.blank?
      add(:graph_json, "node #{index} type #{type.inspect} is unsupported") if type.present? && !SUPPORTED_NODE_TYPES.include?(type.to_s)
    end

    def validate_node_config(node, index)
      config = node.fetch("config", {})
      unless config.is_a?(Hash)
        add(:graph_json, "node #{index} config must be an object")
        return
      end

      case node["type"].to_s
      when "filter"
        validate_filter_config(config, index)
      when "http_request"
        validate_http_config(config, index)
      when "transform"
        validate_transform_config(config, index)
      when "emit_event"
        validate_emit_event_config(config, index)
      end
    end

    def validate_filter_config(config, index)
      add(:graph_json, "filter node #{index} requires config.field") if config["field"].blank?
      add(:graph_json, "filter node #{index} requires config.equals") unless config.key?("equals")
    end

    def validate_http_config(config, index)
      validate_http_url(config["url"], index)

      method = config.fetch("method", "POST").to_s.upcase
      add(:graph_json, "http_request node #{index} method is unsupported") unless HTTP_METHODS.include?(method)

      timeout = config.fetch("timeout_seconds", 5).to_i
      add(:graph_json, "http_request node #{index} timeout_seconds must be between 1 and 30") unless timeout.between?(1, 30)

      headers = config.fetch("headers", {})
      unless headers.is_a?(Hash) && headers.all? { |key, value| key.present? && value.is_a?(String) }
        add(:graph_json, "http_request node #{index} headers must be a string map")
      end

      idempotency_header = config.fetch("idempotency_header", "Idempotency-Key")
      add(:graph_json, "http_request node #{index} idempotency_header must be a string") unless idempotency_header.is_a?(String)

      credential_id = config["credential_id"]
      return if credential_id.blank?

      valid_credential_id = credential_id.to_s.match?(/\A\d+\z/) && credential_id.to_i.positive?
      add(:graph_json, "http_request node #{index} credential_id must be a positive integer") unless valid_credential_id
    end

    def validate_http_url(url, index)
      parsed = URI.parse(url.to_s)
      unless (parsed.is_a?(URI::HTTP) || parsed.is_a?(URI::HTTPS)) && parsed.host.present?
        add(:graph_json, "http_request node #{index} url must use http or https")
        return
      end

      if FlowBridge::HttpEgressPolicy.blocked_ip_literal?(parsed.host)
        add(:graph_json, "http_request node #{index} url targets a blocked network")
      end
    rescue URI::InvalidURIError
      add(:graph_json, "http_request node #{index} url is invalid")
    end

    def validate_transform_config(config, index)
      mapping = config.fetch("mapping", {})
      add(:graph_json, "transform node #{index} mapping must be an object") unless mapping.is_a?(Hash)
    end

    def validate_emit_event_config(config, index)
      topic = config.fetch("topic", "workflow.completed")
      add(:graph_json, "emit_event node #{index} topic must be present") if topic.blank?
    end

    def validate_retry_policy
      max_attempts = retry_policy.fetch("max_attempts", 3).to_i
      base_delay = retry_policy.fetch("base_delay_seconds", 30).to_i
      jitter = retry_policy.fetch("jitter_seconds", 10).to_i

      add(:retry_policy_json, "max_attempts must be between 1 and 10") unless max_attempts.between?(1, 10)
      add(:retry_policy_json, "base_delay_seconds must be between 0 and 3600") unless base_delay.between?(0, 3600)
      add(:retry_policy_json, "jitter_seconds must be between 0 and 300") unless jitter.between?(0, 300)
    end

    def add(attribute, message)
      issues << Issue.new(attribute: attribute, message: message)
    end
  end
end
