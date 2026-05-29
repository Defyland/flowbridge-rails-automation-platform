module FlowBridge
  class SignatureVerifier
    def self.signature(secret:, payload:)
      "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, payload)}"
    end

    def self.valid?(secret:, payload:, header:)
      return false if secret.blank? || header.blank?

      expected = signature(secret: secret, payload: payload)
      header.to_s.split(",").any? do |candidate|
        secure_compare(expected, candidate.strip)
      end
    end

    def self.secure_compare(left, right)
      return false unless left.bytesize == right.bytesize

      ActiveSupport::SecurityUtils.secure_compare(left, right)
    end
  end
end
