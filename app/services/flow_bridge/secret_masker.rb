require "uri"

module FlowBridge
  class SecretMasker
    SENSITIVE_KEY = /(authorization|api[_-]?key|password|secret|signature|token|credential|cookie)/i

    def self.mask(value)
      text = value.to_s
      return "[FILTERED]" if text.length <= 8

      "#{text.first(4)}...#{text.last(4)}"
    end

    def self.mask_url(value)
      uri = URI.parse(value.to_s)
      return uri.to_s if uri.query.blank?

      uri.query = URI.encode_www_form(mask_query_params(uri.query))
      uri.to_s
    rescue ArgumentError, URI::InvalidURIError
      mask(value)
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

    def self.mask_query_params(query)
      URI.decode_www_form(query).map do |key, value|
        [ key, key.to_s.match?(SENSITIVE_KEY) ? mask(value) : value ]
      end
    end
  end
end
