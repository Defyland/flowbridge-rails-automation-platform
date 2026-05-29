module FlowBridge
  class TokenHasher
    def self.digest(token)
      OpenSSL::Digest::SHA256.hexdigest(token.to_s)
    end
  end
end
