module FlowBridge
  class SecretMasker
    SENSITIVE_KEY = /(authorization|api[_-]?key|password|secret|token|credential)/i

    def self.mask(value)
      text = value.to_s
      return "[FILTERED]" if text.length <= 8

      "#{text.first(4)}...#{text.last(4)}"
    end

    def self.mask_hash(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, nested), masked|
          masked[key] = key.to_s.match?(SENSITIVE_KEY) ? mask(nested) : mask_hash(nested)
        end
      when Array
        value.map { |nested| mask_hash(nested) }
      else
        value
      end
    end
  end
end
