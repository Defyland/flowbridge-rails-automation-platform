module FlowBridge
  class GraphChecksum
    def self.call(graph)
      OpenSSL::Digest::SHA256.hexdigest(JSON.generate(canonical(graph)))
    end

    def self.canonical(value)
      case value
      when Hash
        value.keys.sort.each_with_object({}) { |key, memo| memo[key.to_s] = canonical(value[key]) }
      when Array
        value.map { |entry| canonical(entry) }
      else
        value
      end
    end
  end
end
